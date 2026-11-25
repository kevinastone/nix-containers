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
        programs.actionlint.enable = true;
        programs.yamlfmt = {
          enable = true;
          settings.formatter.retain_line_breaks_single = true;
        };
        programs.shfmt = {
          enable = true;
          indent_size = 2;
          simplify = true;
        };
        programs.shellcheck.enable = true;
        settings.global.excludes = [ ".envrc" ];
        settings.formatter = {
          deadnix.priority = 1;
          statix.priority = 2;
          nixfmt.priority = 3;
          shellcheck.priority = 1;
          shfmt.priority = 2;
          actionlint.priority = 1;
          yamlfmt.priority = 2;
          nufmt = {
            command = pkgs.lib.getExe pkgs.nufmt;
            includes = [ "*.nu" ];
          };
        };
      };
    };
}
