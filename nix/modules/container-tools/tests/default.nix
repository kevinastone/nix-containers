{
  perSystem =
    {
      lib,
      pkgs,
      writeNuApplication,
      ...
    }:
    let
      wrapFlags =
        name: basePkg: flags:
        if flags == [ ] then
          basePkg
        else
          pkgs.runCommand name
            {
              nativeBuildInputs = [ pkgs.makeWrapper ];
              meta.mainProgram = name;
            }
            ''
              mkdir -p "$out/bin"
              makeWrapper ${lib.getExe basePkg} "$out/bin/${name}" ${lib.escapeShellArgs flags}
            '';

      testRunner = writeNuApplication {
        name = "run-container-tests";
        file = ./run-tests.nu;
      };

      ociTest = writeNuApplication {
        name = "oci-test";
        file = ./test-oci.nu;
      };

      structureTestBase = writeNuApplication {
        name = "structure-test";
        file = ./test-structure.nu;
        runtimeInputs = [ pkgs.container-structure-test ];
      };

      restrictedTestBase = writeNuApplication {
        name = "restricted-test";
        file = ./test-restricted.nu;
      };

      structureTest =
        config:
        wrapFlags "structure-test" structureTestBase [
          "--add-flags"
          "--config"
          "--add-flags"
          "${config}"
        ];

      restrictedTest =
        config:
        wrapFlags "restricted-test" restrictedTestBase (
          lib.optionals (config != null) [
            "--add-flags"
            "--config"
            "--add-flags"
            "${config}"
          ]
        );

      builtinOrder = [
        "oci"
        "structure"
        "restricted"
      ];

      mkTestSuite =
        {
          name,
          runAsNonRoot ? true,
          structureTestConfig ? null,
          extraTests ? { },
        }:
        let
          defaultTests = {
            oci = ociTest;
          }
          // lib.optionalAttrs (structureTestConfig != null) {
            structure = structureTest structureTestConfig;
          }
          // lib.optionalAttrs runAsNonRoot {
            restricted = restrictedTest structureTestConfig;
          };

          tests = lib.filterAttrs (_: v: v != null) (defaultTests // extraTests);

          orderedTestNames =
            (builtins.filter (k: tests ? ${k}) builtinOrder)
            ++ (builtins.filter (k: !(builtins.elem k builtinOrder)) (builtins.attrNames tests));

          testsFile = pkgs.writeText "${name}-tests.json" (
            builtins.toJSON (
              map (testName: {
                name = testName;
                bin = lib.getExe tests.${testName};
              }) orderedTestNames
            )
          );

          test = wrapFlags "${name}-tests" testRunner [
            "--add-flags"
            "--tests-json"
            "--add-flags"
            "${testsFile}"
          ];
        in
        {
          inherit tests test;
        };
    in
    {
      _module.args.mkTestSuite = mkTestSuite;

      containerTools = {
        inherit
          ociTest
          restrictedTest
          structureTest
          ;
      };
    };
}
