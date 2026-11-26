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
        file = ./dev/update-readme.nu;
        extraArgs = [
          "--add-flags"
          "--catalog-json"
          "--add-flags"
          "${catalogFile}"
        ];
      };

      ciPackages = {
        ci-matrix = writeNuApplication {
          name = "ci-matrix";
          file = ./ci/ci-matrix.nu;
          includes = sharedLib;
          runtimeInputs = [ pkgs.regctl ];
        };

        flake-update-report = writeNuApplication {
          name = "flake-update-report";
          file = ./ci/flake-update-report.nu;
          includes = sharedLib;
          runtimeInputs = with pkgs; [
            gh
            git
            nvd
          ];
        };

        push-multiarch = writeNuApplication {
          name = "push-multiarch";
          file = ./ci/push-multiarch.nu;
          includes = sharedLib;
          runtimeInputs = [ pkgs.regctl ];
        };

        update-packages = writeNuApplication {
          name = "update-packages";
          file = ./ci/update-packages.nu;
          includes = sharedLib;
          runtimeInputs = with pkgs; [
            git
            nix-update
          ];
        };
      };

      devPackages = {
        inherit dive-archive update-readme;

        inspect-image = writeNuApplication {
          name = "inspect-image";
          file = ./dev/inspect-image.nu;
          includes = sharedLib;
          runtimeInputs = [
            dive-archive
            pkgs.git
            pkgs.nvd
          ];
        };

        new-container = writeNuApplication {
          name = "new-container";
          file = ./dev/new-container.nu;
        };

        scan-image = writeNuApplication {
          name = "scan-image";
          file = ./dev/scan-image.nu;
          includes = sharedLib;
          runtimeInputs = with pkgs; [
            grype
            gzip
            syft
          ];
        };
      };
    in
    {
      packages = ciPackages // devPackages;

      checks.readme-catalog = pkgs.runCommand "check-readme-catalog" { } ''
        ${pkgs.lib.getExe update-readme} --check ${../../../README.md}
        touch "$out"
      '';
    };
}
