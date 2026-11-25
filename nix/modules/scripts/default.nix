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

        push-multiarch = writeNuApplication {
          name = "push-multiarch";
          file = ./push-multiarch.nu;
          runtimeInputs = [ pkgs.regctl ];
        };

        dive-archive = pkgs.writeShellApplication {
          name = "dive-archive";
          runtimeInputs = with pkgs; [
            dive
            gzip
          ];
          text = ''
            dive --source docker-archive <(gunzip -c "''${1:-result}")
          '';
        };
      };

      checks.readme-catalog = pkgs.runCommand "check-readme-catalog" { } ''
        ${pkgs.lib.getExe update-readme} --check ${../../../README.md}
        touch "$out"
      '';
    };
}
