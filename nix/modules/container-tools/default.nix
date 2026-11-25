{ inputs, ... }:
let
  defaultSource = "https://github.com/kevinastone/nix-containers";

  mkContainerTools =
    {
      lib,
      dockerTools,
      writers,
      writeText,
      runCommand,
      makeWrapper,
      bash,
      coreutils,
      tzdata,
      container-structure-test,
    }:
    let
      nonRootNss = dockerTools.fakeNss.override {
        extraPasswdLines = [ "nonroot:x:65532:65532:Non-root user:/home/nonroot:/sbin/nologin" ];
        extraGroupLines = [ "nonroot:x:65532:" ];
      };

      mkNuTest =
        name: runtimeInputs: extraArgs: file:
        writers.writeNuBin name (lib.optionalAttrs (runtimeInputs != [ ] || extraArgs != [ ]) {
          makeWrapperArgs =
            (lib.optionals (runtimeInputs != [ ]) [
              "--prefix"
              "PATH"
              ":"
              (lib.makeBinPath runtimeInputs)
            ])
            ++ extraArgs;
        }) (builtins.readFile file);

      testRunner = mkNuTest "run-container-tests" [ ] [ ] ./run-tests.nu;
      ociTest = mkNuTest "oci-test" [ ] [ ] ./test-oci.nu;

      mkStructureTest =
        config:
        mkNuTest "structure-test"
          [ container-structure-test ]
          [
            "--add-flags"
            "--config"
            "--add-flags"
            "${config}"
          ]
          ./test-structure.nu;

      mkRestrictedTest =
        config:
        mkNuTest "restricted-test" [ ] (lib.optionals (config != null) [
          "--add-flags"
          "--config"
          "--add-flags"
          "${config}"
        ]) ./test-restricted.nu;

      packageLicense =
        pkg:
        let
          raw = lib.toList (pkg.meta.license or [ ]);
          ids = lib.filter (x: x != null) (map (l: l.spdxId or l.shortName or null) raw);
        in
        if ids != [ ] then lib.concatStringsSep " AND " ids else null;

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
          licenses ? if package != null then packageLicense package else null,
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
          defaultLabels = {
            "org.opencontainers.image.title" = name;
            "org.opencontainers.image.version" = tag;
            "org.opencontainers.image.source" = source;
          }
          // lib.optionalAttrs (licenses != null) {
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
              "structureTest"
              "config"
              "meta"
              "passthru"
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

          defaultTests = {
            oci = ociTest;
          }
          // lib.optionalAttrs (structureTest != null) {
            structure = mkStructureTest structureTest;
          }
          // lib.optionalAttrs runAsNonRoot {
            restricted = mkRestrictedTest structureTest;
          };
          tests = lib.filterAttrs (_: v: v != null) (defaultTests // (passthru.tests or { }));

          builtinOrder = [
            "oci"
            "structure"
            "restricted"
          ];
          orderedTestNames =
            (builtins.filter (k: tests ? ${k}) builtinOrder)
            ++ (builtins.filter (k: !(builtins.elem k builtinOrder)) (builtins.attrNames tests));

          testsFile = writeText "${name}-tests.json" (
            builtins.toJSON (
              map (testName: {
                name = testName;
                bin = lib.getExe tests.${testName};
              }) orderedTestNames
            )
          );

          runTests =
            runCommand "${name}-tests"
              {
                nativeBuildInputs = [ makeWrapper ];
                meta.mainProgram = "${name}-tests";
              }
              ''
                mkdir -p "$out/bin"
                makeWrapper ${lib.getExe testRunner} "$out/bin/${name}-tests" \
                  --add-flags --tests-json \
                  --add-flags ${testsFile}
              '';
        in
        (builder builderArgs).overrideAttrs (old: {
          meta = (old.meta or { }) // defaultMeta // meta;
          passthru =
            (old.passthru or { })
            // passthru
            // {
              inherit tests;
              test = runTests;
            };
        });
    in
    dockerTools
    // {
      inherit nonRootNss ociTest;
      restrictedTest = mkRestrictedTest;
      structureTest = mkStructureTest;
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
