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

      nonRootId = "65532";

      nonRootNss = dockerTools.fakeNss.override {
        extraPasswdLines = [
          "nonroot:x:${nonRootId}:${nonRootId}:Non-root user:/home/nonroot:/sbin/nologin"
        ];
        extraGroupLines = [ "nonroot:x:${nonRootId}:" ];
      };

      wrapBuilder =
        {
          builder,
          contentsAttr,
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
              includeCaCerts ? true,
              includeTzdata ? true,
              enableShell ? false,
              structureTest ? null,
              config ? { },
              meta ? { },
              passthru ? { },
              extraCommands ? "",
              ...
            }@args:
            let
              baseContents =
                lib.optional runAsNonRoot nonRootNss
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
              mergedEnv = (lib.optional includeTzdata "TZDIR=${tzdata}/share/zoneinfo") ++ (config.Env or [ ]);

              defaultConfig =
                lib.optionalAttrs (package != null && !(config ? Entrypoint)) {
                  Entrypoint = [ (lib.getExe package) ];
                }
                // lib.optionalAttrs (runAsNonRoot && !(config ? User)) {
                  User = "${nonRootId}:${nonRootId}";
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
                  extraCommands = ''
                    mkdir -p ./tmp
                    chmod 1777 ./tmp
                  ''
                  + lib.optionalString (extraCommands != "") "\n${extraCommands}";
                }
                // lib.optionalAttrs (mergedContents != [ ]) {
                  ${contentsAttr} = mergedContents;
                };

              testSuite = mkTestSuite {
                inherit name runAsNonRoot;
                structureTestConfig = structureTest;
                extraTests = passthru.tests or { };
              };
            in
            (builder builderArgs).overrideAttrs (old: {
              meta = (old.meta or { }) // oci.mkMeta { inherit package description; } // meta;
              passthru = (old.passthru or { }) // passthru // testSuite;
            });
        in
        buildFn;
    in
    {
      containerTools = {
        inherit nonRootNss;
        buildImage = wrapBuilder {
          builder = dockerTools.buildImage;
          contentsAttr = "copyToRoot";
        };
        buildLayeredImage = wrapBuilder {
          builder = dockerTools.buildLayeredImage;
          contentsAttr = "contents";
        };
      };
    };
}
