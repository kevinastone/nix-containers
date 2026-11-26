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

  containerDirs = builtins.attrNames (
    lib.filterAttrs (
      name: type: type == "directory" && builtins.pathExists (containersDir + "/${name}/default.nix")
    ) (builtins.readDir containersDir)
  );

  # renovate: datasource=github-runners depName=ubuntu
  ubuntuRunnerVersion = "26.04";

  ciRunners = {
    x86_64-linux = "ubuntu-${ubuntuRunnerVersion}";
    aarch64-linux = "ubuntu-${ubuntuRunnerVersion}-arm";
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

  systemContainers = system: config.flake.legacyPackages.${system}.containers or { };

  containerNames = lib.sort builtins.lessThan (
    lib.unique (lib.concatMap (a: builtins.attrNames (systemContainers a.system)) ciArches)
  );

  containerArches = name: builtins.filter (a: (systemContainers a.system) ? ${name}) ciArches;

  activeContainers = builtins.filter (c: containerArches c != [ ]) containerNames;

  catalog = map (
    container:
    let
      arches = containerArches container;
      firstSystem = (builtins.head arches).system;
      drv = (systemContainers firstSystem).${container};
      inherit (drv) sourceDir variantKey;
      variantRel =
        if variantKey != null && builtins.pathExists (containersDir + "/${sourceDir}/${variantKey}") then
          "${sourceDir}/${variantKey}"
        else
          null;
      recipePath =
        if variantRel != null && builtins.pathExists (containersDir + "/${variantRel}/default.nix") then
          "nix/containers/${variantRel}/default.nix"
        else
          "nix/containers/${sourceDir}/default.nix";
      docPath =
        if variantRel != null && builtins.pathExists (containersDir + "/${variantRel}/README.md") then
          "nix/containers/${variantRel}/README.md"
        else if builtins.pathExists (containersDir + "/${sourceDir}/README.md") then
          "nix/containers/${sourceDir}/README.md"
        else
          recipePath;
    in
    {
      name = container;
      inherit docPath recipePath sourceDir;
      description = drv.meta.description or "";
      platforms = map (a: a.platform) arches;
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
            drv = (systemContainers firstSystem).${container};
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
        drv = (systemContainers firstSystem).${container};
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
            value = builtins.unsafeDiscardStringContext (systemContainers a.system).${container}.drvPath;
          }) arches
        );
      }
    ) activeContainers;
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
          "containers.nix: base image name '${baseName}' in nix/containers/${dir}/default.nix must match directory '${dir}'";
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
        ) "containers.nix: duplicate container/variant names detected across nix/containers/*";
        builtins.listToAttrs expandedEntries;

      availableContainers = lib.filterAttrs (
        _: drv: lib.meta.availableOn pkgs.stdenv.hostPlatform drv
      ) allContainers;

      updatePackages = lib.foldl' (
        acc: drv:
        let
          pkg = drv.package or null;
          primary = lib.optionalAttrs (pkg != null && isLocalPackage pkg) {
            ${pkg.pname} = pkg;
          };
        in
        acc // primary // (drv.updatePackages or { })
      ) { } (builtins.attrValues allContainers);
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

        updatePackages = lib.optionalAttrs isLinux updatePackages;
      };
    };
}
