{
  description = "Minimal, reproducible, multi-architecture OCI container images built with Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      treefmt-nix,
      ...
    }:
    let
      containerNames = builtins.attrNames (
        nixpkgs.lib.filterAttrs (
          name: type: type == "directory" && builtins.pathExists (./nix/containers + "/${name}/default.nix")
        ) (builtins.readDir ./nix/containers)
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
    in
    flake-parts.lib.mkFlake { inherit inputs; } (
      { config, ... }:
      let
        containerArches =
          name: builtins.filter (a: (config.flake.packages.${a.system} or { }) ? ${name}) ciArches;
      in
      {
        imports = [ treefmt-nix.flakeModule ];

        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
          "x86_64-darwin"
        ];

        flake.lib = {
          containers = containerNames;
          mkContainerTools = pkgs: import ./nix/lib/container-tools.nix { inherit pkgs; };
          ci = {
            build = builtins.concatMap (
              container:
              map (a: {
                inherit container;
                inherit (a) arch runs-on;
              }) (containerArches container)
            ) containerNames;

            push = map (container: {
              inherit container;
              arches = map (a: a.arch) (containerArches container);
              inherit (builtins.head (containerArches container)) system;
            }) (builtins.filter (c: containerArches c != [ ]) containerNames);
          };
        };

        perSystem =
          { config, pkgs, ... }:
          let
            nixLib = import ./nix/lib { inherit pkgs; };
            containers = import ./nix/containers {
              inherit pkgs;
              inherit (nixLib) containerTools;
              names = containerNames;
            };
            scripts = pkgs.callPackage ./nix/scripts { };
          in
          {
            treefmt = {
              projectRootFile = "flake.nix";
              programs.nixfmt.enable = true;
              programs.statix.enable = true;
              programs.deadnix.enable = true;
              settings.formatter = {
                deadnix.priority = 1;
                statix.priority = 2;
                nixfmt.priority = 3;
              };
            };

            packages =
              (pkgs.lib.filterAttrs (_: drv: pkgs.lib.meta.availableOn pkgs.stdenv.hostPlatform drv) containers)
              // {
                inherit (scripts) push-multiarch;
              };

            devShells.default = pkgs.mkShell {
              nativeBuildInputs = [ config.treefmt.build.wrapper ];
              packages = with pkgs; [
                dive
                skopeo
                scripts.dive-archive
              ];
            };
          };
      }
    );
}
