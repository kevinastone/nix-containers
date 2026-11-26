{
  perSystem =
    {
      lib,
      pkgs,
      oci,
      evalImageConfig,
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

      mkUsersNss =
        users:
        dockerTools.fakeNss.override {
          extraPasswdLines = map (
            u:
            "${u.name}:x:${toString u.uid}:${toString u.gid}:Non-root user:${
              if u.home != null then u.home else "/var/empty"
            }:/sbin/nologin"
          ) users;
          extraGroupLines = lib.unique (map (u: "${u.name}:x:${toString u.gid}:") users);
        };

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
            extraUsers
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

          allUsers = lib.optional runAsNonRoot user ++ builtins.attrValues extraUsers;

          userHomeDirs = builtins.listToAttrs (
            map (u: {
              name = u.home;
              value = {
                mode = "0755";
                inherit (u) uid gid;
              };
            }) (builtins.filter (u: u.home != null) allUsers)
          );

          defaultDirs = {
            "/tmp" = {
              mode = "1777";
              uid = 0;
              gid = 0;
            };
          }
          // userHomeDirs;

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
            lib.optional (allUsers != [ ]) (mkUsersNss allUsers)
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

          testSuiteArgs = {
            inherit name runAsNonRoot;
            structureTestConfig = structureTest;
          };

          testSuite = mkTestSuite (
            testSuiteArgs
            // {
              extraTests = passthru.tests or { };
            }
          );
        in
        (dockerTools.buildLayeredImage builderArgs).overrideAttrs (old: {
          meta = (old.meta or { }) // oci.mkMeta { inherit package description; } // meta;
          passthru =
            (old.passthru or { })
            // passthru
            // {
              inherit closure extraTags testSuiteArgs;
            }
            // lib.optionalAttrs (package != null) {
              inherit package;
            }
            // testSuite;
        });
    in
    {
      containerTools = {
        inherit buildLayeredImage;
      };
    };
}
