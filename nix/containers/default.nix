{
  pkgs,
  containerTools,
  names ? builtins.attrNames (
    pkgs.lib.filterAttrs (
      name: type: type == "directory" && builtins.pathExists (./. + "/${name}/default.nix")
    ) (builtins.readDir ./.)
  ),
}:
pkgs.lib.genAttrs names (name: pkgs.callPackage (./. + "/${name}") { inherit containerTools; })
