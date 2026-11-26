{
  lib,
  withSystem,
  systemContainers,
}:
let
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

  containerNames = lib.sort builtins.lessThan (
    lib.unique (lib.concatMap (a: builtins.attrNames (systemContainers a.system)) ciArches)
  );

  containerArches = name: builtins.filter (a: (systemContainers a.system) ? ${name}) ciArches;

  activeContainers = builtins.filter (c: containerArches c != [ ]) containerNames;

  firstDrv =
    container:
    let
      firstSystem = (builtins.head (containerArches container)).system;
    in
    (systemContainers firstSystem).${container};

  ci = map (
    container:
    let
      arches = containerArches container;
      drv = firstDrv container;
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
in
{
  inherit
    activeContainers
    ci
    containerArches
    containerNames
    firstDrv
    ;
}
