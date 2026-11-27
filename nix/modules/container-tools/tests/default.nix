{
  lib,
  pkgs,
  writeNuApplication,
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

  normalizeConfigs =
    configs: if configs == null then [ ] else lib.unique (map (c: "${c}") (lib.toList configs));

  configFlags = lib.concatMap (c: [
    "--append-flags"
    c
  ]);

  structureTest =
    configs: wrapFlags "structure-test" structureTestBase (configFlags (normalizeConfigs configs));

  restrictedTest =
    {
      configs,
      readOnlyRoot ? true,
    }:
    wrapFlags "restricted-test" restrictedTestBase (
      lib.optionals (!readOnlyRoot) [
        "--add-flags"
        "--writable-root"
      ]
      ++ configFlags (normalizeConfigs configs)
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
      readOnlyRoot ? true,
      structureTestConfig ? [ ],
      extraTests ? { },
    }:
    let
      normalizedConfigs = normalizeConfigs structureTestConfig;

      defaultTests = {
        oci = ociTest;
      }
      // lib.optionalAttrs (normalizedConfigs != [ ]) {
        structure = structureTest normalizedConfigs;
      }
      // lib.optionalAttrs runAsNonRoot {
        restricted = restrictedTest {
          configs = normalizedConfigs;
          inherit readOnlyRoot;
        };
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
  inherit
    mkTestSuite
    ociTest
    restrictedTest
    structureTest
    ;
}
