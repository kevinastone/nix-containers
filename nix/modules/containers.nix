{
  config,
  lib,
  withSystem,
  ...
}:
let
  repoRoot = toString ../..;
  containersDir = ../containers;
  isLocalPackage = pkg: lib.hasPrefix repoRoot (pkg.meta.position or "");

  containerNames = builtins.attrNames (
    lib.filterAttrs (
      name: type: type == "directory" && builtins.pathExists (containersDir + "/${name}/default.nix")
    ) (builtins.readDir containersDir)
  );

  ciRunners = {
    x86_64-linux = "ubuntu-24.04";
    aarch64-linux = "ubuntu-24.04-arm";
  };

  ciArches = lib.sortOn (a: a.arch) (
    lib.mapAttrsToList (
      system: runs-on:
      withSystem system (
        { pkgs, ... }:
        let
          inherit (pkgs.stdenv.hostPlatform.go) GOOS GOARCH;
        in
        {
          inherit system runs-on;
          arch = GOARCH;
          platform = "${GOOS}/${GOARCH}";
        }
      )
    ) ciRunners
  );

  containerArches =
    name: builtins.filter (a: (config.flake.packages.${a.system} or { }) ? ${name}) ciArches;

  activeContainers = builtins.filter (c: containerArches c != [ ]) containerNames;

  catalog = map (
    container:
    let
      arches = containerArches container;
      firstSystem = (builtins.head arches).system;
      drv = config.flake.packages.${firstSystem}.${container};
    in
    {
      name = container;
      description = drv.meta.description or "";
      platforms = map (a: a.platform) arches;
      hasReadme = builtins.pathExists (containersDir + "/${container}/README.md");
    }
  ) activeContainers;
in
{
  flake.lib = {
    containers = containerNames;
    updatePackages = lib.unique (
      lib.concatMap (
        container:
        let
          arches = containerArches container;
          firstSystem = (builtins.head arches).system;
          drv = config.flake.packages.${firstSystem}.${container};
          pkg = drv.package or null;
          extra = builtins.attrNames (drv.updatePackages or { });
        in
        lib.optional (pkg != null && isLocalPackage pkg) pkg.pname ++ extra
      ) activeContainers
    );
    inherit catalog;
    ci = map (
      container:
      let
        arches = containerArches container;
        firstSystem = (builtins.head arches).system;
        drv = config.flake.packages.${firstSystem}.${container};
      in
      {
        inherit container;
        version = drv.imageTag;
        extraTags = drv.extraTags or [ ];
        arches = map (a: { inherit (a) arch runs-on; }) arches;
        drvs = builtins.listToAttrs (
          map (a: {
            name = a.arch;
            value = builtins.unsafeDiscardStringContext config.flake.packages.${a.system}.${container}.drvPath;
          }) arches
        );
      }
    ) activeContainers;
  };

  perSystem =
    { pkgs, containerTools, ... }:
    let
      containers = lib.genAttrs containerNames (
        name: pkgs.callPackage (containersDir + "/${name}") { inherit containerTools; }
      );
      updatePackages = lib.foldl' (
        acc: drv:
        let
          pkg = drv.package or null;
          primary = lib.optionalAttrs (pkg != null && isLocalPackage pkg) {
            ${pkg.pname} = pkg;
          };
        in
        acc // primary // (drv.updatePackages or { })
      ) { } (builtins.attrValues containers);
    in
    {
      packages = lib.filterAttrs (_: drv: lib.meta.availableOn pkgs.stdenv.hostPlatform drv) containers;
      legacyPackages = {
        containerTests = lib.mapAttrs (_: drv: drv.test) containers;
        inherit updatePackages;
      };
    };
}
