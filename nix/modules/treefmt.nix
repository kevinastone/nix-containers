{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem =
    { pkgs, ... }:
    {
      treefmt = {
        projectRootFile = "flake.nix";
        programs.nixfmt.enable = true;
        programs.statix.enable = true;
        programs.deadnix.enable = true;
        settings.formatter = {
          deadnix.priority = 1;
          statix.priority = 2;
          nixfmt.priority = 3;
          nufmt = {
            command = pkgs.lib.getExe pkgs.nufmt;
            includes = [ "*.nu" ];
          };
        };
      };
    };
}
