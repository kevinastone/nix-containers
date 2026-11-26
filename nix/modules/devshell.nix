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
            action-validator
            container-structure-test
            cosign
            dive
            dive-archive
            ghalint
            grype
            inspect-image
            just
            new-container
            nix-tree
            nix-update
            nushell
            nvd
            pinact
            regctl
            scan-image
            skopeo
            syft
            update-packages
            update-readme
            zizmor
            # keep-sorted end
          ];
      };
    };
}
