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
            just
            new-container
            nix-tree
            nushell
            nvd
            pinact
            regctl
            skopeo
            update-readme
            zizmor
            # keep-sorted end
          ];
      };
    };
}
