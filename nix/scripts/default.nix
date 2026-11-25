{
  pkgs,
  writeNuApplication,
  catalog ? [ ],
}:
let
  catalogFile = pkgs.writeText "catalog.json" (builtins.toJSON catalog);
in
{
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
}
