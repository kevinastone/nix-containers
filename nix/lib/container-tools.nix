{ pkgs }:
let
  inherit (pkgs) lib dockerTools;
  defaultSource = "https://github.com/kevinastone/nix-containers";

  wrapBuilder =
    builder:
    {
      name,
      tag,
      description ? null,
      source ? defaultSource,
      licenses ? "MIT",
      config ? { },
      ...
    }@args:
    let
      defaultLabels = {
        "org.opencontainers.image.title" = name;
        "org.opencontainers.image.version" = tag;
        "org.opencontainers.image.source" = source;
        "org.opencontainers.image.licenses" = licenses;
      }
      // lib.optionalAttrs (description != null) {
        "org.opencontainers.image.description" = description;
      };

      mergedConfig = config // {
        Labels = defaultLabels // (config.Labels or { });
      };

      builderArgs =
        (removeAttrs args [
          "description"
          "source"
          "licenses"
          "config"
        ])
        // {
          config = mergedConfig;
        };
    in
    builder builderArgs;
in
dockerTools
// {
  buildImage = wrapBuilder dockerTools.buildImage;
  buildLayeredImage = wrapBuilder dockerTools.buildLayeredImage;
}
