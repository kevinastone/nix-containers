{
  lib,
  pkgs,
  containersDir,
  containerDirs,
  containerTools,
}:
let
  withOrigin =
    {
      sourceDir,
      variantKey ? null,
    }:
    drv:
    drv.overrideAttrs (old: {
      passthru = (old.passthru or { }) // {
        inherit sourceDir variantKey;
      };
    });

  expandedEntries = lib.concatMap (
    dir:
    let
      baseDrv = pkgs.callPackage (containersDir + "/${dir}") { inherit containerTools; };
      baseName = baseDrv.imageName;
      variantEntries = lib.mapAttrsToList (variantKey: vDrv: {
        name = vDrv.imageName;
        value = withOrigin {
          sourceDir = dir;
          inherit variantKey;
        } vDrv;
      }) (baseDrv.variants or { });
    in
    assert lib.assertMsg (baseName == dir)
      "containers: base image name '${baseName}' in nix/containers/${dir}/default.nix must match directory '${dir}'";
    [
      {
        name = baseName;
        value = withOrigin { sourceDir = dir; } baseDrv;
      }
    ]
    ++ variantEntries
  ) containerDirs;

  entryNames = map (e: e.name) expandedEntries;

  allContainers =
    assert lib.assertMsg (
      builtins.length entryNames == builtins.length (lib.unique entryNames)
    ) "containers: duplicate container/variant names detected across nix/containers/*";
    builtins.listToAttrs expandedEntries;

  availableContainers = lib.filterAttrs (
    _: drv: lib.meta.availableOn pkgs.stdenv.hostPlatform drv
  ) allContainers;
in
{
  inherit allContainers availableContainers;
}
