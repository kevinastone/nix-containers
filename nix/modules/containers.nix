{ config, lib, ... }:
let
  containersDir = ../containers;

  containerNames = builtins.attrNames (
    lib.filterAttrs (
      name: type: type == "directory" && builtins.pathExists (containersDir + "/${name}/default.nix")
    ) (builtins.readDir containersDir)
  );

  ciArches = [
    {
      system = "x86_64-linux";
      arch = "amd64";
      runs-on = "ubuntu-24.04";
    }
    {
      system = "aarch64-linux";
      arch = "arm64";
      runs-on = "ubuntu-24.04-arm";
    }
  ];

  containerArches =
    name: builtins.filter (a: (config.flake.packages.${a.system} or { }) ? ${name}) ciArches;
in
{
  flake.lib = {
    containers = containerNames;
    ci = {
      build = builtins.concatMap (
        container:
        map (a: {
          inherit container;
          inherit (a) arch runs-on;
        }) (containerArches container)
      ) containerNames;

      push = map (
        container:
        let
          arches = containerArches container;
          firstSystem = (builtins.head arches).system;
        in
        {
          inherit container;
          version = config.flake.packages.${firstSystem}.${container}.imageTag;
          drvs = builtins.listToAttrs (
            map (a: {
              name = a.arch;
              value = builtins.unsafeDiscardStringContext config.flake.packages.${a.system}.${container}.drvPath;
            }) arches
          );
        }
      ) (builtins.filter (c: containerArches c != [ ]) containerNames);
    };
  };

  perSystem =
    { pkgs, ... }:
    let
      containers = lib.genAttrs containerNames (name: pkgs.callPackage (containersDir + "/${name}") { });
    in
    {
      packages = lib.filterAttrs (_: drv: lib.meta.availableOn pkgs.stdenv.hostPlatform drv) containers;
    };
}
