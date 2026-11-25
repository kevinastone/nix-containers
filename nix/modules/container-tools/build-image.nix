{
  perSystem =
    {
      lib,
      pkgs,
      oci,
      mkTestSuite,
      ...
    }:
    let
      inherit (pkgs)
        dockerTools
        bash
        coreutils
        tzdata
        ;

      mkUserNss =
        {
          name,
          uid,
          gid,
          home,
        }:
        dockerTools.fakeNss.override {
          extraPasswdLines = [
            "${name}:x:${toString uid}:${toString gid}:Non-root user:${
              if home != null then home else "/var/empty"
            }:/sbin/nologin"
          ];
          extraGroupLines = [ "${name}:x:${toString gid}:" ];
        };

      defaultNonRootUser = {
        name = "nonroot";
        uid = 65532;
        gid = 65532;
        home = "/home/nonroot";
      };

      nonRootNss = mkUserNss defaultNonRootUser;

      wrapBuilder =
        {
          builder,
          contentsAttr,
          supportsFakeRoot ? false,
        }:
        let
          buildFn =
            {
              package ? null,
              name ?
                if package != null then
                  package.pname
                else
                  throw "containerTools: `name` or `package` must be provided",
              tag ?
                if package != null then
                  package.version
                else
                  throw "containerTools: `tag` or `package` must be provided",
              description ? if package != null then package.meta.description or null else null,
              source ? oci.defaultSource,
              licenses ? if package != null then oci.packageLicense package else null,
              runAsNonRoot ? true,
              user ? { },
              includeCaCerts ? true,
              includeTzdata ? true,
              enableShell ? false,
              dirs ? { },
              structureTest ? null,
              config ? { },
              meta ? { },
              passthru ? { },
              extraCommands ? "",
              fakeRootCommands ? "",
              ...
            }@args:
            let
              userName = user.name or defaultNonRootUser.name;
              userUid = user.uid or defaultNonRootUser.uid;
              userGid = user.gid or userUid;
              userHome = user.home or "/home/${userName}";

              resolvedUser = {
                name = userName;
                uid = userUid;
                gid = userGid;
                home = userHome;
              };

              userNss = if resolvedUser == defaultNonRootUser then nonRootNss else mkUserNss resolvedUser;

              defaultUid = if runAsNonRoot && supportsFakeRoot then resolvedUser.uid else 0;
              defaultGid = if runAsNonRoot && supportsFakeRoot then resolvedUser.gid else 0;

              defaultDirs = {
                "/tmp" = {
                  mode = "1777";
                  uid = 0;
                  gid = 0;
                };
              }
              // lib.optionalAttrs (runAsNonRoot && resolvedUser.home != null) {
                ${resolvedUser.home} = {
                  mode = "0755";
                  uid = defaultUid;
                  gid = defaultGid;
                };
              };

              resolvedDirs = lib.mapAttrs (
                path: spec:
                let
                  clean = lib.removeSuffix "/" path;
                in
                assert lib.assertMsg (
                  lib.hasPrefix "/" clean && clean != ""
                ) "containerTools: `dirs` key '${path}' must be a non-root absolute path";
                {
                  relPath = ".${clean}";
                  mode = spec.mode or "0755";
                  uid = spec.uid or defaultUid;
                  gid = spec.gid or defaultGid;
                }
              ) (defaultDirs // dirs);

              dirList = builtins.attrValues resolvedDirs;

              mkdirCommands = lib.optionalString (dirList != [ ]) (
                "mkdir -p " + lib.escapeShellArgs (map (d: d.relPath) dirList)
              );

              chmodCommands = lib.concatMapStringsSep "\n" (
                d: "chmod ${lib.escapeShellArg d.mode} ${lib.escapeShellArg d.relPath}"
              ) dirList;

              chownCommands = lib.concatMapStringsSep "\n" (
                d: "chown ${toString d.uid}:${toString d.gid} ${lib.escapeShellArg d.relPath}"
              ) dirList;

              mergedExtraCommands = lib.concatStringsSep "\n" (
                lib.filter (s: s != "") (
                  [ mkdirCommands ] ++ lib.optional (!supportsFakeRoot) chmodCommands ++ [ extraCommands ]
                )
              );

              mergedFakeRootCommands = lib.concatStringsSep "\n" (
                lib.filter (s: s != "") [
                  mkdirCommands
                  chmodCommands
                  chownCommands
                  fakeRootCommands
                ]
              );

              baseContents =
                lib.optional runAsNonRoot userNss
                ++ lib.optional includeCaCerts dockerTools.caCertificates
                ++ lib.optional includeTzdata tzdata
                ++ lib.optionals enableShell [
                  dockerTools.usrBinEnv
                  dockerTools.binSh
                  bash
                  coreutils
                ]
                ++ lib.optional (package != null) package;

              mergedContents = lib.unique (baseContents ++ lib.toList (args.${contentsAttr} or [ ]));

              userEnv = config.Env or [ ];
              hasEnvKey = key: builtins.any (lib.hasPrefix "${key}=") userEnv;

              mergedEnv =
                lib.optional (
                  runAsNonRoot && resolvedUser.home != null && !(hasEnvKey "HOME")
                ) "HOME=${resolvedUser.home}"
                ++ lib.optional (includeTzdata && !(hasEnvKey "TZDIR")) "TZDIR=${tzdata}/share/zoneinfo"
                ++ userEnv;

              defaultConfig =
                lib.optionalAttrs (package != null && !(config ? Entrypoint)) {
                  Entrypoint = [ (lib.getExe package) ];
                }
                // lib.optionalAttrs (runAsNonRoot && !(config ? User)) {
                  User = "${toString resolvedUser.uid}:${toString resolvedUser.gid}";
                };

              mergedConfig =
                defaultConfig
                // config
                // {
                  Labels =
                    (oci.mkLabels {
                      inherit
                        name
                        tag
                        package
                        description
                        source
                        licenses
                        ;
                    })
                    // (config.Labels or { });
                }
                // lib.optionalAttrs (mergedEnv != [ ]) {
                  Env = mergedEnv;
                };

              passthroughArgs = removeAttrs args (
                [ contentsAttr ] ++ builtins.attrNames (builtins.functionArgs buildFn)
              );

              builderArgs =
                passthroughArgs
                // {
                  inherit name tag;
                  config = mergedConfig;
                  extraCommands = mergedExtraCommands;
                }
                // lib.optionalAttrs supportsFakeRoot {
                  fakeRootCommands = mergedFakeRootCommands;
                }
                // lib.optionalAttrs (mergedContents != [ ]) {
                  ${contentsAttr} = mergedContents;
                };

              closure = pkgs.closureInfo {
                rootPaths = mergedContents ++ [
                  (pkgs.writeText "${name}-config.json" (
                    builtins.toJSON {
                      config = mergedConfig;
                      extraCommands = mergedExtraCommands;
                      fakeRootCommands = mergedFakeRootCommands;
                    }
                  ))
                ];
              };

              testSuite = mkTestSuite {
                inherit name runAsNonRoot;
                structureTestConfig = structureTest;
                extraTests = passthru.tests or { };
              };
            in
            assert lib.assertMsg (
              runAsNonRoot || user == { }
            ) "containerTools: `user` cannot be set when `runAsNonRoot = false`";
            assert lib.assertMsg (
              !runAsNonRoot || (resolvedUser.uid > 0 && resolvedUser.gid > 0)
            ) "containerTools: `user.uid` and `user.gid` must be > 0 when `runAsNonRoot = true`";
            assert lib.assertMsg
              (supportsFakeRoot || (fakeRootCommands == "" && builtins.all (d: d.uid == 0 && d.gid == 0) dirList))
              "containerTools.buildImage does not support non-root `dirs` ownership or `fakeRootCommands` without a VM; use `containerTools.buildLayeredImage` instead";
            (builder builderArgs).overrideAttrs (old: {
              meta = (old.meta or { }) // oci.mkMeta { inherit package description; } // meta;
              passthru = (old.passthru or { }) // passthru // { inherit closure; } // testSuite;
            });
        in
        buildFn;
    in
    {
      containerTools = {
        inherit mkUserNss nonRootNss;
        buildImage = wrapBuilder {
          builder = dockerTools.buildImage;
          contentsAttr = "copyToRoot";
        };
        buildLayeredImage = wrapBuilder {
          builder = dockerTools.buildLayeredImage;
          contentsAttr = "contents";
          supportsFakeRoot = true;
        };
      };
    };
}
