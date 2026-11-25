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
        packages = with pkgs; [
          dive
          skopeo
          self'.packages.dive-archive
        ];
      };
    };
}
