{
  lib,
  pkgs,
  oci,
  rootfs,
  evalImageConfig,
  mkTestSuite,
}:
let
  inherit (pkgs)
    dockerTools
    bash
    coreutils
    pigz
    tzdata
    ;

  mkSingleImage =
    {
      cfg,
      passthroughArgs,
      variants ? { },
    }:
    let
      inherit (cfg)
        package
        name
        tag
        category
        description
        source
        licenses
        extraTags
        features
        runAsNonRoot
        readOnlyRoot
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

      fs = rootfs.mkRootfs {
        inherit
          runAsNonRoot
          user
          extraUsers
          dirs
          extraCommands
          fakeRootCommands
          ;
      };

      baseContents =
        fs.nss
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

      mergedConfig = oci.mkConfig {
        inherit
          name
          tag
          package
          description
          source
          licenses
          runAsNonRoot
          user
          includeTzdata
          config
          ;
      };

      builderArgs =
        passthroughArgs
        // {
          inherit name tag;
          config = mergedConfig;
          inherit (fs) extraCommands fakeRootCommands;
        }
        // lib.optionalAttrs (mergedContents != [ ]) {
          contents = mergedContents;
        };

      closure = pkgs.closureInfo {
        rootPaths = mergedContents ++ [
          (pkgs.writeText "${name}-config.json" (
            builtins.toJSON {
              config = mergedConfig;
              inherit (fs) extraCommands fakeRootCommands;
            }
          ))
        ];
      };

      stream = dockerTools.streamLayeredImage (removeAttrs builderArgs [ "compressor" ]);

      streamArchive = pkgs.writeShellScript "${name}-stream-archive" ''
        set -euo pipefail
        ${stream} | ${lib.getExe pigz} -nT
      '';

      imageUser = mergedConfig.User or "root";

      rootfsTest = rootfs.mkRootfsTest {
        inherit
          runAsNonRoot
          user
          dirs
          imageUser
          ;
      };

      testSuiteArgs = {
        inherit name readOnlyRoot runAsNonRoot;
        structureTestConfig = [ rootfsTest ] ++ structureTest;
      };

      testSuite = mkTestSuite (
        testSuiteArgs
        // {
          extraTests = passthru.tests;
        }
      );

      cleanPassthru = removeAttrs passthru [
        "_module"
        "tests"
      ];
    in
    (dockerTools.buildLayeredImage builderArgs).overrideAttrs (old: {
      meta = (old.meta or { }) // oci.mkMeta { inherit package description; } // meta;
      passthru =
        (old.passthru or { })
        // cleanPassthru
        // {
          inherit
            category
            closure
            enableShell
            extraTags
            features
            readOnlyRoot
            runAsNonRoot
            stream
            streamArchive
            testSuiteArgs
            variants
            ;
          inherit imageUser;
          imageName = name;
          imageTag = tag;
        }
        // lib.optionalAttrs (package != null) {
          inherit package;
        }
        // testSuite;
    });
in
args:
let
  evaluated = evalImageConfig args;
  builtVariants = lib.mapAttrs (
    _: vEval:
    mkSingleImage {
      inherit (vEval) cfg passthroughArgs;
    }
  ) evaluated.variants;
in
mkSingleImage {
  inherit (evaluated) cfg passthroughArgs;
  variants = builtVariants;
}
