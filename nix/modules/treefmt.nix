{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem = {
    treefmt = {
      projectRootFile = "flake.nix";
      programs.nixfmt.enable = true;
      programs.statix.enable = true;
      programs.deadnix.enable = true;
      settings.formatter = {
        deadnix.priority = 1;
        statix.priority = 2;
        nixfmt.priority = 3;
      };
    };
  };
}
