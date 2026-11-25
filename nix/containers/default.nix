{ pkgs }:
let
  inherit (pkgs) lib;
  entries = builtins.readDir ./.;
  containerDirs = lib.filterAttrs (
    name: type: type == "directory" && builtins.pathExists (./. + "/${name}/default.nix")
  ) entries;
in
lib.mapAttrs (name: _: pkgs.callPackage (./. + "/${name}") { }) containerDirs
