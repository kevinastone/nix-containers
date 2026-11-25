{
  perSystem =
    {
      lib,
      pkgs,
      oci,
      imageOptions,
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
      inherit (imageOptions) defaultNonRootUser evalImageConfig;

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

      nonRootNss = mkUserNss defaultNonRootUser;

      buildLayeredImage =
        args:
        let
          inherit (evalImageConfig { inherit oci args; }) cfg passthroughArgs;

          inherit (cfg)
            package
            name
            tag
            description
            source
            licenses
            extraTags
            runAsNonRoot
            user
            includeCaCerts
            includeTzdata
            enableShell
            dirs
            structureTest
            contents
            config
            meta
            passthru
            extraCommands
            fakeRootCommands
            ;

          userNss = if user == defaultNonRootUser then nonRootNss else mkUserNss user;

          defaultUid = if runAsNonRoot then user.uid else 0;
          defaultGid = if runAsNonRoot then user.gid else 0;

          defaultDirs = {
            "/tmp" = {
              mode = "1777";
              uid = 0;
              gid = 0;
            };
          }
          // lib.optionalAttrs (runAsNonRoot && user.home != null) {
            ${user.home} = {
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
              inherit (spec) mode uid gid;
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
            lib.filter (s: s != "") [
              mkdirCommands
              extraCommands
            ]
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

          mergedContents = lib.unique (baseContents ++ contents);

          userEnv = config.Env or [ ];
          hasEnvKey = key: builtins.any (lib.hasPrefix "${key}=") userEnv;

          mergedEnv =
            lib.optional (runAsNonRoot && user.home != null && !(hasEnvKey "HOME")) "HOME=${user.home}"
            ++ lib.optional (includeTzdata && !(hasEnvKey "TZDIR")) "TZDIR=${tzdata}/share/zoneinfo"
            ++ userEnv;

          defaultConfig =
            lib.optionalAttrs (package != null && !(config ? Entrypoint)) {
              Entrypoint = [ (lib.getExe package) ];
            }
            // lib.optionalAttrs (runAsNonRoot && !(config ? User)) {
              User = "${toString user.uid}:${toString user.gid}";
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

          builderArgs =
            passthroughArgs
            // {
              inherit name tag;
              config = mergedConfig;
              extraCommands = mergedExtraCommands;
              fakeRootCommands = mergedFakeRootCommands;
            }
            // lib.optionalAttrs (mergedContents != [ ]) {
              contents = mergedContents;
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
        (dockerTools.buildLayeredImage builderArgs).overrideAttrs (old: {
          meta = (old.meta or { }) // oci.mkMeta { inherit package description; } // meta;
          passthru =
            (old.passthru or { })
            // passthru
            // {
              inherit closure extraTags;
            }
            // testSuite;
        });
    in
    {
      containerTools = {
        inherit buildLayeredImage mkUserNss nonRootNss;
      };
    };
}
