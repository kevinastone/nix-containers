{ pkgs, ... }:
let
  mkRegctlNuScript =
    name: file:
    pkgs.writers.writeNuBin name {
      makeWrapperArgs = [
        "--prefix"
        "PATH"
        ":"
        (pkgs.lib.makeBinPath [ pkgs.regctl ])
      ];
    } (builtins.readFile file);
in
{
  ci-matrix = mkRegctlNuScript "ci-matrix" ./ci-matrix.nu;
  push-multiarch = mkRegctlNuScript "push-multiarch" ./push-multiarch.nu;

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
