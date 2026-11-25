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
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      imports = [
        ./nix/modules/container-tools.nix
        ./nix/modules/containers.nix
        ./nix/modules/treefmt.nix
      ];

      perSystem =
        { config, pkgs, ... }:
        let
          scripts = pkgs.callPackage ./nix/scripts { };
        in
        {
          packages = {
            inherit (scripts) ci-matrix push-multiarch;
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
    };
}
