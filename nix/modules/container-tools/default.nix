{ inputs, ... }:
let
  writeNuApplication =
    { lib, writers }:
    {
      name,
      text ? builtins.readFile file,
      file ? null,
      runtimeInputs ? [ ],
      extraArgs ? [ ],
    }:
    writers.writeNuBin name (lib.optionalAttrs (runtimeInputs != [ ] || extraArgs != [ ]) {
      makeWrapperArgs =
        (lib.optionals (runtimeInputs != [ ]) [
          "--prefix"
          "PATH"
          ":"
          (lib.makeBinPath runtimeInputs)
        ])
        ++ extraArgs;
    }) text;

  overlay = final: _: {
    writeNuApplication = final.callPackage writeNuApplication { };

    containerTools =
      let
        oci = final.callPackage ./oci.nix { };
        tests = final.callPackage ./tests { };
        builders = final.callPackage ./build-image.nix { inherit oci tests; };
      in
      final.dockerTools
      // {
        inherit (builders) nonRootNss buildImage buildLayeredImage;
        inherit (tests) ociTest restrictedTest structureTest;
      };
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
