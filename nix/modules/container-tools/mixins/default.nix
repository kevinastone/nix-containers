{ pkgs }:
{
  configDir = ./config-dir.nix;
  dinit = import ./dinit.nix { inherit pkgs; };
  dotnet = ./dotnet.nix;
  python = ./python.nix;
  servarr = ./servarr.nix;
}
