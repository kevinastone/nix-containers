{ lib, ... }:
let
  defaultSource = "https://github.com/kevinastone/nix-containers";

  formatLicenses =
    input:
    let
      raw = lib.flatten (lib.toList input);
      ids = lib.unique (
        lib.filter (x: x != null && x != "") (
          map (l: if builtins.isString l then l else (l.spdxId or l.shortName or null)) raw
        )
      );
    in
    if ids != [ ] then lib.concatStringsSep " AND " ids else null;

  packageLicense = pkg: formatLicenses (pkg.meta.license or [ ]);

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
  perSystem._module.args.oci = {
    inherit
      defaultSource
      formatLicenses
      packageLicense
      mkLabels
      mkMeta
      ;
  };
}
