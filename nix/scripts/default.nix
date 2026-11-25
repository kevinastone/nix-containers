{ pkgs, ... }:
{
  push-multiarch = pkgs.writers.writeNuBin "push-multiarch" {
    makeWrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      (pkgs.lib.makeBinPath [ pkgs.regctl ])
    ];
  } (builtins.readFile ./push-multiarch.nu);

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
