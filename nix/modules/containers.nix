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
  isGitHubPackage =
    pkg:
    lib.hasInfix "github.com" (pkg.src.url or (lib.head (pkg.src.urls or [ "" ])))
    || lib.hasInfix "github.com" (pkg.meta.homepage or "");

  semverTags =
    version:
    let
      m = builtins.match "^v?([0-9]+)\\.([0-9]+)\\.([0-9]+)$" version;
      major = builtins.elemAt m 0;
      minor = builtins.elemAt m 1;
      patch = builtins.elemAt m 2;
    in
    if m == null then
      [ version ]
    else
      lib.unique (
        [
          version
          "${major}.${minor}.${patch}"
          "${major}.${minor}"
        ]
        ++ lib.optional (major != "0") major
      );

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
    updatePackages = map (s: s.name) config.flake.lib.updatePackageSpecs;
    updatePackageSpecs =
      let
        collectSpecs =
          container:
          let
            arches = containerArches container;
            firstSystem = (builtins.head arches).system;
            drv = config.flake.packages.${firstSystem}.${container};
            pkg = drv.package or null;
            mkSpec = name: p: {
              inherit name;
              args = p.nixUpdateArgs or (lib.optionals (isGitHubPackage p) [ "--use-github-releases" ]);
            };
            primary = lib.optional (pkg != null && isLocalPackage pkg) (mkSpec pkg.pname pkg);
            extra = lib.mapAttrsToList mkSpec (drv.updatePackages or { });
          in
          primary ++ extra;
      in
      lib.unique (lib.concatMap collectSpecs activeContainers);
    inherit catalog;
    ci = map (
      container:
      let
        arches = containerArches container;
        firstSystem = (builtins.head arches).system;
        drv = config.flake.packages.${firstSystem}.${container};
        extraTags = drv.extraTags or [ ];
      in
      {
        inherit container extraTags;
        version = drv.imageTag;
        tags = lib.unique (semverTags drv.imageTag ++ extraTags);
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
    {
      pkgs,
      containerTools,
      mkTestSuite,
      ...
    }:
    let
      inherit (pkgs.stdenv.hostPlatform) isLinux;
      linuxSystem = "${pkgs.stdenv.hostPlatform.parsed.cpu.name}-linux";

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
      packages = lib.optionalAttrs isLinux (
        lib.filterAttrs (_: drv: lib.meta.availableOn pkgs.stdenv.hostPlatform drv) containers
      );

      legacyPackages = {
        containerTests =
          if isLinux then
            lib.mapAttrs (_: drv: drv.test) containers
          else
            lib.listToAttrs (
              map (
                name:
                let
                  arches = containerArches name;
                  targetSystem =
                    if (config.flake.packages.${linuxSystem} or { }) ? ${name} then
                      linuxSystem
                    else
                      (builtins.head arches).system;
                  drv = config.flake.packages.${targetSystem}.${name};
                in
                {
                  inherit name;
                  value = (mkTestSuite drv.testSuiteArgs).test;
                }
              ) activeContainers
            );

        updatePackages = lib.optionalAttrs isLinux updatePackages;
      };
    };
}
