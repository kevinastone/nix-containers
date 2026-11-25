{ pkgs }:
let
  inherit (pkgs) lib dockerTools;
  defaultSource = "https://github.com/kevinastone/nix-containers";

  wrapBuilder =
    {
      builder,
      contentsAttr,
    }:
    {
      package ? null,
      name ?
        if package != null then
          package.pname
        else
          throw "containerTools: `name` or `package` must be provided",
      tag ?
        if package != null then
          package.version
        else
          throw "containerTools: `tag` or `package` must be provided",
      description ? if package != null then package.meta.description or null else null,
      source ? defaultSource,
      licenses ? "MIT",
      config ? { },
      meta ? { },
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

      defaultConfig = lib.optionalAttrs (package != null && !(config ? Entrypoint)) {
        Entrypoint = [ (lib.getExe package) ];
      };

      mergedConfig =
        defaultConfig
        // config
        // {
          Labels = defaultLabels // (config.Labels or { });
        };

      defaultMeta = {
        platforms =
          if package != null && (package.meta ? platforms) then
            lib.intersectLists lib.platforms.linux package.meta.platforms
          else
            lib.platforms.linux;
      }
      // lib.optionalAttrs (description != null) {
        inherit description;
      };

      existingContents = lib.toList (args.${contentsAttr} or [ ]);
      mergedContents =
        if package != null && !(builtins.elem package existingContents) then
          existingContents ++ [ package ]
        else
          existingContents;

      builderArgs =
        (removeAttrs args [
          "package"
          "description"
          "source"
          "licenses"
          "config"
          "meta"
          contentsAttr
        ])
        // {
          inherit name tag;
          config = mergedConfig;
        }
        // lib.optionalAttrs (mergedContents != [ ]) {
          ${contentsAttr} = mergedContents;
        };
    in
    (builder builderArgs).overrideAttrs (old: {
      meta = (old.meta or { }) // defaultMeta // meta;
    });
in
dockerTools
// {
  buildImage = wrapBuilder {
    builder = dockerTools.buildImage;
    contentsAttr = "copyToRoot";
  };
  buildLayeredImage = wrapBuilder {
    builder = dockerTools.buildLayeredImage;
    contentsAttr = "contents";
  };
}
