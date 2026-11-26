{ config, ... }:
let
  inherit (config.flake.lib) catalog;
  sharedLib = [ ./lib.nu ];
in
{
  perSystem =
    { pkgs, writeNuApplication, ... }:
    let
      catalogFile = pkgs.writeText "catalog.json" (builtins.toJSON catalog);

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
        inherit dive-archive update-readme;

        ci-matrix = writeNuApplication {
          name = "ci-matrix";
          file = ./ci-matrix.nu;
          includes = sharedLib;
          runtimeInputs = [ pkgs.regctl ];
        };

        flake-update-report = writeNuApplication {
          name = "flake-update-report";
          file = ./flake-update-report.nu;
          includes = sharedLib;
          runtimeInputs = with pkgs; [
            gh
            git
            nvd
          ];
        };

        inspect-image = writeNuApplication {
          name = "inspect-image";
          file = ./inspect-image.nu;
          includes = sharedLib;
          runtimeInputs = [
            dive-archive
            pkgs.git
            pkgs.nvd
          ];
        };

        new-container = writeNuApplication {
          name = "new-container";
          file = ./new-container.nu;
        };

        push-multiarch = writeNuApplication {
          name = "push-multiarch";
          file = ./push-multiarch.nu;
          includes = sharedLib;
          runtimeInputs = [ pkgs.regctl ];
        };

        scan-image = writeNuApplication {
          name = "scan-image";
          file = ./scan-image.nu;
          includes = sharedLib;
          runtimeInputs = with pkgs; [
            grype
            gzip
            syft
          ];
        };

        update-packages = writeNuApplication {
          name = "update-packages";
          file = ./update-packages.nu;
          includes = sharedLib;
          runtimeInputs = with pkgs; [
            git
            nix-update
          ];
        };
      };

      checks.readme-catalog = pkgs.runCommand "check-readme-catalog" { } ''
        ${pkgs.lib.getExe update-readme} --check ${../../../README.md}
        touch "$out"
      '';
    };
}
