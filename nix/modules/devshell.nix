{
  perSystem =
    {
      config,
      pkgs,
      self',
      ...
    }:
    {
      devShells.default = pkgs.mkShell {
        nativeBuildInputs = [ config.treefmt.build.wrapper ];
        packages =
          with pkgs;
          with self'.packages;
          [
            # keep-sorted start
            container-structure-test
            cosign
            dive
            dive-archive
            grype
            just
            new-container
            nix-tree
            nushell
            nvd
            pinact
            regctl
            scan-image
            skopeo
            syft
            update-readme
            zizmor
            # keep-sorted end
          ];
      };
    };
}
