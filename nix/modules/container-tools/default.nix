{ lib, ... }:
{
  imports = [
    ./oci.nix
    ./options.nix
    ./tests
    ./build-image.nix
  ];

  perSystem =
    { config, pkgs, ... }:
    {
      options.containerTools = lib.mkOption {
        type = lib.types.attrsOf lib.types.raw;
        default = { };
      };

      config._module.args.containerTools = pkgs.dockerTools // config.containerTools;
    };
}
