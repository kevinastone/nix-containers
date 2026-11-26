{ lib, tzdata }:
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

  envKey = entry: builtins.head (lib.splitString "=" entry);

  dedupEnv =
    entries:
    lib.foldr (
      entry: acc: if builtins.any (x: envKey x == envKey entry) acc then acc else [ entry ] ++ acc
    ) [ ] entries;

  ociScalarKeys = [
    "Entrypoint"
    "Cmd"
    "User"
    "WorkingDir"
    "StopSignal"
  ];

  mkConfig =
    {
      name,
      tag,
      package,
      description,
      source,
      licenses,
      runAsNonRoot,
      user,
      includeTzdata,
      config,
    }:
    let
      userEnv = dedupEnv config.Env;
      hasEnvKey = key: builtins.any (e: envKey e == key) userEnv;

      mergedEnv =
        lib.optional (runAsNonRoot && user.home != null && !(hasEnvKey "HOME")) "HOME=${user.home}"
        ++ lib.optional (includeTzdata && !(hasEnvKey "TZDIR")) "TZDIR=${tzdata}/share/zoneinfo"
        ++ userEnv;

      explicitScalars = lib.filterAttrs (k: v: builtins.elem k ociScalarKeys && v != null) config;

      extraOciFields = removeAttrs config (
        [
          "_module"
          "Env"
          "ExposedPorts"
          "Volumes"
          "Labels"
        ]
        ++ ociScalarKeys
      );

      cleanConfig =
        extraOciFields
        // explicitScalars
        // lib.optionalAttrs (config.ExposedPorts != { }) {
          inherit (config) ExposedPorts;
        }
        // lib.optionalAttrs (config.Volumes != { }) {
          inherit (config) Volumes;
        };

      defaultConfig =
        lib.optionalAttrs (package != null && config.Entrypoint == null) {
          Entrypoint = [ (lib.getExe package) ];
        }
        // lib.optionalAttrs (runAsNonRoot && config.User == null) {
          User = "${toString user.uid}:${toString user.gid}";
        };
    in
    defaultConfig
    // cleanConfig
    // {
      Labels =
        (mkLabels {
          inherit
            name
            tag
            package
            description
            source
            licenses
            ;
        })
        // config.Labels;
    }
    // lib.optionalAttrs (mergedEnv != [ ]) {
      Env = mergedEnv;
    };
in
{
  inherit
    defaultSource
    formatLicenses
    packageLicense
    mkConfig
    mkLabels
    mkMeta
    ;
}
