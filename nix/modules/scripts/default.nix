{ config, ... }:
let
  inherit (config.flake.lib) catalog;
in
{
  perSystem =
    { pkgs, writeNuApplication, ... }:
    let
      catalogFile = pkgs.writeText "catalog.json" (builtins.toJSON catalog);

      update-readme = writeNuApplication {
        name = "update-readme";
        file = ./update-readme.nu;
        extraArgs = [
          "--add-flags"
          "--catalog-json"
          "--add-flags"
          "${catalogFile}"
        ];
      };
    in
    {
      packages = {
        inherit update-readme;

        ci-matrix = writeNuApplication {
          name = "ci-matrix";
          file = ./ci-matrix.nu;
          runtimeInputs = [ pkgs.regctl ];
        };

        dive-archive = pkgs.writeShellApplication {
          name = "dive-archive";
          runtimeInputs = with pkgs; [
            dive
            gzip
          ];
          text = ''
            archive="''${1:-result}"
            if [ "$#" -gt 0 ]; then
              shift
            fi
            dive --source docker-archive <(gzip -cdf "$archive") "$@"
          '';
        };

        flake-update-report = writeNuApplication {
          name = "flake-update-report";
          file = ./flake-update-report.nu;
          runtimeInputs = [ pkgs.nvd ];
        };

        new-container = writeNuApplication {
          name = "new-container";
          file = ./new-container.nu;
        };

        push-multiarch = writeNuApplication {
          name = "push-multiarch";
          file = ./push-multiarch.nu;
          runtimeInputs = [ pkgs.regctl ];
        };

        scan-image = writeNuApplication {
          name = "scan-image";
          file = ./scan-image.nu;
          runtimeInputs = with pkgs; [
            grype
            gzip
            syft
          ];
        };
      };

      checks.readme-catalog = pkgs.runCommand "check-readme-catalog" { } ''
        ${pkgs.lib.getExe update-readme} --check ${../../../README.md}
        touch "$out"
      '';
    };
}
