{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem =
    { pkgs, ... }:
    {
      treefmt = {
        projectRootFile = "flake.nix";
        programs.just.enable = true;
        programs.keep-sorted.enable = true;
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
        programs.typos.enable = true;
        settings.global.excludes = [ ".envrc" ];
        settings.formatter = {
          deadnix.priority = 1;
          statix.priority = 2;
          nixfmt.priority = 3;
          shellcheck.priority = 1;
          shfmt.priority = 2;
          actionlint.priority = 1;
          zizmor = {
            command = pkgs.lib.getExe pkgs.zizmor;
            options = [
              "--offline"
              "--config"
              "${pkgs.writers.writeYAML "zizmor.yml" {
                rules.self-repository.disable = true;
              }}"
            ];
            includes = [
              ".github/dependabot.yml"
              ".github/workflows/*.yml"
              ".github/workflows/*.yaml"
              ".github/actions/**/*.yml"
              ".github/actions/**/*.yaml"
            ];
            priority = 1;
          };
          yamlfmt.priority = 2;
          nufmt = {
            command = pkgs.lib.getExe pkgs.nufmt;
            includes = [ "*.nu" ];
          };
        };
      };
    };
}
