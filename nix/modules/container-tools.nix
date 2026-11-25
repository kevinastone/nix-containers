{ inputs, ... }:
let
  defaultSource = "https://github.com/kevinastone/nix-containers";

  mkContainerTools =
    {
      lib,
      dockerTools,
      bash,
      coreutils,
      tzdata,
    }:
    let
      nonRootNss = dockerTools.fakeNss.override {
        extraPasswdLines = [ "nonroot:x:65532:65532:Non-root user:/home/nonroot:/sbin/nologin" ];
        extraGroupLines = [ "nonroot:x:65532:" ];
      };

      wrapBuilder =
        {
          builder,
          contentsAttr,
        }:
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
          source ? defaultSource,
          licenses ? "MIT",
          runAsNonRoot ? true,
          includeCaCerts ? true,
          includeTzdata ? true,
          enableShell ? false,
          config ? { },
          meta ? { },
          extraCommands ? "",
          ...
        }@args:
        let
          defaultLabels = {
            "org.opencontainers.image.title" = name;
            "org.opencontainers.image.version" = tag;
            "org.opencontainers.image.source" = source;
            "org.opencontainers.image.licenses" = licenses;
          }
          // lib.optionalAttrs (description != null) {
            "org.opencontainers.image.description" = description;
          };

          defaultEnv = lib.optional includeTzdata "TZDIR=${tzdata}/share/zoneinfo";
          mergedEnv = defaultEnv ++ (config.Env or [ ]);

          defaultConfig =
            lib.optionalAttrs (package != null && !(config ? Entrypoint)) {
              Entrypoint = [ (lib.getExe package) ];
            }
            // lib.optionalAttrs (runAsNonRoot && !(config ? User)) {
              User = "65532:65532";
            };

          mergedConfig =
            defaultConfig
            // config
            // {
              Labels = defaultLabels // (config.Labels or { });
            }
            // lib.optionalAttrs (mergedEnv != [ ]) {
              Env = mergedEnv;
            };

          defaultMeta = {
            platforms =
              if package != null && (package.meta ? platforms) then
                lib.intersectLists lib.platforms.linux package.meta.platforms
              else
                lib.platforms.linux;
          }
          // lib.optionalAttrs (description != null) {
            inherit description;
          };

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

          existingContents = lib.toList (args.${contentsAttr} or [ ]);
          mergedContents = lib.unique (baseContents ++ existingContents);

          mergedExtraCommands = ''
            mkdir -p ./tmp
            chmod 1777 ./tmp
          ''
          + lib.optionalString (extraCommands != "") "\n${extraCommands}";

          builderArgs =
            (removeAttrs args [
              "package"
              "description"
              "source"
              "licenses"
              "runAsNonRoot"
              "includeCaCerts"
              "includeTzdata"
              "enableShell"
              "config"
              "meta"
              "extraCommands"
              contentsAttr
            ])
            // {
              inherit name tag;
              config = mergedConfig;
              extraCommands = mergedExtraCommands;
            }
            // lib.optionalAttrs (mergedContents != [ ]) {
              ${contentsAttr} = mergedContents;
            };
        in
        (builder builderArgs).overrideAttrs (old: {
          meta = (old.meta or { }) // defaultMeta // meta;
        });
    in
    dockerTools
    // {
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

  overlay = final: _: {
    containerTools = final.callPackage mkContainerTools { };
  };
in
{
  flake.overlays.default = overlay;

  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [ overlay ];
      };
    };
}
