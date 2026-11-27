{ lib, ... }:
{
  perSystem =
    {
      config,
      pkgs,
      writeNuApplication,
      ...
    }:
    let
      oci = import ./oci.nix {
        inherit lib;
        inherit (pkgs) tzdata;
      };
      inherit (import ./schema.nix { inherit lib; }) mkImageModule;
      evalImageConfig = import ./eval.nix {
        inherit lib oci mkImageModule;
      };
      rootfs = import ./rootfs.nix {
        inherit lib;
        inherit (pkgs) dockerTools;
      };
      mixins = import ./mixins;
      tests = import ./tests {
        inherit lib pkgs writeNuApplication;
      };
      buildLayeredImage = import ./build-image.nix {
        inherit
          lib
          pkgs
          oci
          rootfs
          evalImageConfig
          ;
        inherit (tests) mkTestSuite;
      };
    in
    {
      options.containerTools = lib.mkOption {
        type = lib.types.attrsOf lib.types.raw;
        default = { };
      };

      config = {
        containerTools = tests // {
          inherit buildLayeredImage mixins;
        };
        _module.args.containerTools = config.containerTools;
      };
    };
}
