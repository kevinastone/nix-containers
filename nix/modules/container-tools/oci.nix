{ lib }:
let
  defaultSource = "https://github.com/kevinastone/nix-containers";

  packageLicense =
    pkg:
    let
      raw = lib.flatten (lib.toList (pkg.meta.license or [ ]));
      ids = lib.filter (x: x != null) (
        map (l: if builtins.isString l then l else (l.spdxId or l.shortName or null)) raw
      );
    in
    if ids != [ ] then lib.concatStringsSep " AND " ids else null;

  mkLabels =
    {
      name,
      tag,
      package ? null,
      description ? null,
      source ? defaultSource,
      licenses ? if package != null then packageLicense package else null,
    }:
    {
      "org.opencontainers.image.title" = name;
      "org.opencontainers.image.version" = tag;
      "org.opencontainers.image.source" = source;
    }
    // lib.optionalAttrs (licenses != null) {
      "org.opencontainers.image.licenses" = licenses;
    }
    // lib.optionalAttrs (description != null) {
      "org.opencontainers.image.description" = description;
    };

  mkMeta =
    {
      package ? null,
      description ? null,
    }:
    {
      platforms =
        if package != null && (package.meta ? platforms) then
          lib.intersectLists lib.platforms.linux package.meta.platforms
        else
          lib.platforms.linux;
    }
    // lib.optionalAttrs (description != null) {
      inherit description;
    };
in
{
  inherit
    defaultSource
    packageLicense
    mkLabels
    mkMeta
    ;
}
