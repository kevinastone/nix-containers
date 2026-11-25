{ pkgs, ... }:
let
  mkNuScript =
    name: file: runtimeInputs:
    pkgs.writers.writeNuBin name (pkgs.lib.optionalAttrs (runtimeInputs != [ ]) {
      makeWrapperArgs = [
        "--prefix"
        "PATH"
        ":"
        (pkgs.lib.makeBinPath runtimeInputs)
      ];
    }) (builtins.readFile file);
in
{
  ci-matrix = mkNuScript "ci-matrix" ./ci-matrix.nu [ pkgs.regctl ];
  push-multiarch = mkNuScript "push-multiarch" ./push-multiarch.nu [ pkgs.regctl ];

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
