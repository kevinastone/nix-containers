{
  config,
  lib,
  withSystem,
  ...
}:
let
  repoRoot = toString ../../..;
  containersDir = ../../containers;

  containerDirs = builtins.attrNames (
    lib.filterAttrs (
      name: type: type == "directory" && builtins.pathExists (containersDir + "/${name}/default.nix")
    ) (builtins.readDir containersDir)
  );

  systemContainers = system: config.flake.legacyPackages.${system}.containers or { };

  ciMeta = import ./ci.nix {
    inherit lib withSystem systemContainers;
  };

  inherit (ciMeta)
    activeContainers
    ci
    containerArches
    containerNames
    firstDrv
    ;

  catalog = import ./catalog.nix {
    inherit
      containersDir
      activeContainers
      containerArches
      firstDrv
      ;
  };

  updates = import ./updates.nix {
    inherit lib repoRoot;
  };

  updatePackageSpecs = updates.mkUpdatePackageSpecs {
    inherit activeContainers firstDrv;
  };
in
{
  flake.lib = {
    containers = containerNames;
    updatePackages = map (s: s.name) updatePackageSpecs;
    inherit catalog ci updatePackageSpecs;
  };

  perSystem =
    {
      pkgs,
      containerTools,
      ...
    }:
    let
      inherit (pkgs.stdenv.hostPlatform) isLinux;
      linuxSystem = "${pkgs.stdenv.hostPlatform.parsed.cpu.name}-linux";

      discovered = import ./discovery.nix {
        inherit
          lib
          pkgs
          containersDir
          containerDirs
          containerTools
          ;
      };

      inherit (discovered) allContainers availableContainers;
    in
    {
      packages = lib.optionalAttrs isLinux availableContainers;

      legacyPackages = {
        containers = lib.optionalAttrs isLinux availableContainers;

        containerTests =
          if isLinux then
            lib.mapAttrs (_: drv: drv.test) availableContainers
          else
            lib.listToAttrs (
              map (
                name:
                let
                  arches = containerArches name;
                  targetSystem =
                    if (systemContainers linuxSystem) ? ${name} then linuxSystem else (builtins.head arches).system;
                  drv = (systemContainers targetSystem).${name};
                in
                {
                  inherit name;
                  value = (containerTools.mkTestSuite drv.testSuiteArgs).test;
                }
              ) activeContainers
            );

        updatePackages = lib.optionalAttrs isLinux (updates.collectSystemUpdatePackages allContainers);
      };
    };
}
