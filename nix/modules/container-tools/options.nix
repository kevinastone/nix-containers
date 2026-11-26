{ lib, ... }:
let
  inherit (lib) mkOption types;

  containerNameType = types.strMatching "^[a-z0-9][a-z0-9._-]*$";

  mkUserSubmodule =
    {
      defaultName ? null,
      defaultUid ? null,
    }:
    types.submodule (
      { name, config, ... }:
      {
        options = {
          name = mkOption {
            type = types.nonEmptyStr;
            default = if defaultName != null then defaultName else name;
            description = "Username recorded in /etc/passwd and /etc/group.";
          };
          uid = mkOption (
            {
              type = types.ints.positive;
              description = "Numeric UID (> 0).";
            }
            // lib.optionalAttrs (defaultUid != null) {
              default = defaultUid;
            }
          );
          gid = mkOption {
            type = types.ints.positive;
            default = config.uid;
            description = "Numeric GID (> 0).";
          };
          home = mkOption {
            type = types.nullOr (types.strMatching "^/.+");
            default = "/home/${config.name}";
            description = "Absolute home directory path (created automatically), or null to omit.";
          };
        };
      }
    );

  userSubmodule = mkUserSubmodule {
    defaultName = "nonroot";
    defaultUid = 65532;
  };

  extraUserSubmodule = mkUserSubmodule { };

  dirSubmodule =
    defaultUid: defaultGid:
    types.submodule {
      options = {
        mode = mkOption {
          type = types.strMatching "^[0-7]{3,4}$";
          default = "0755";
          description = "Octal file mode string (e.g. \"0755\" or \"1777\").";
        };
        uid = mkOption {
          type = types.ints.unsigned;
          default = defaultUid;
          description = "Numeric owner UID.";
        };
        gid = mkOption {
          type = types.ints.unsigned;
          default = defaultGid;
          description = "Numeric owner GID.";
        };
      };
    };

  ociConfigSubmodule = types.submodule {
    freeformType = types.attrsOf types.raw;
    options = {
      Entrypoint = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Container entrypoint argv.";
      };
      Cmd = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Default arguments passed to Entrypoint.";
      };
      User = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Container runtime User[:Group] override.";
      };
      WorkingDir = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Working directory for Entrypoint/Cmd.";
      };
      StopSignal = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Signal used to stop the container.";
      };
      Env = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Environment variables (KEY=VALUE).";
      };
      ExposedPorts = mkOption {
        type = types.attrsOf (types.attrsOf types.raw);
        default = { };
        description = "Exposed ports (e.g. { \"8080/tcp\" = { }; }).";
      };
      Volumes = mkOption {
        type = types.attrsOf (types.attrsOf types.raw);
        default = { };
        description = "Mount point volumes (e.g. { \"/config\" = { }; }).";
      };
      Labels = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Additional OCI image labels.";
      };
    };
  };

  passthruSubmodule = types.submodule {
    freeformType = types.attrsOf types.raw;
    options = {
      tests = mkOption {
        type = types.attrsOf (types.nullOr types.package);
        default = { };
        description = "Additional or overridden container test derivations.";
      };
    };
  };

  licenseType = types.oneOf [
    types.str
    (types.attrsOf types.anything)
    (types.listOf licenseType)
  ];

  mkImageModule =
    {
      defaultSource,
      formatLicenses,
      packageLicense,
    }:
    { config, ... }:
    let
      defaultUid = if config.runAsNonRoot then config.user.uid else 0;
      defaultGid = if config.runAsNonRoot then config.user.gid else 0;
    in
    {
      freeformType = types.attrsOf types.raw;

      options = {
        package = mkOption {
          type = types.nullOr types.package;
          default = null;
          description = "Primary package used to derive name, tag, description, licenses, Entrypoint, and contents.";
        };
        name = mkOption {
          type = containerNameType;
          default =
            if config.package != null then
              config.package.pname
            else
              throw "containerTools: `name` or `package` must be provided";
          description = "OCI image name.";
        };
        tag = mkOption {
          type = types.nonEmptyStr;
          default =
            if config.package != null then
              config.package.version
            else
              throw "containerTools: `tag` or `package` must be provided";
          description = "OCI image version tag.";
        };
        description = mkOption {
          type = types.nullOr types.str;
          default = if config.package != null then config.package.meta.description or null else null;
          description = "OCI org.opencontainers.image.description label.";
        };
        source = mkOption {
          type = types.nonEmptyStr;
          default = defaultSource;
          description = "OCI org.opencontainers.image.source label.";
        };
        licenses = mkOption {
          type = types.nullOr licenseType;
          default = if config.package != null then packageLicense config.package else null;
          apply = v: if v == null then null else formatLicenses v;
          description = "SPDX license expression or nixpkgs meta.license value(s) for org.opencontainers.image.licenses.";
        };
        extraTags = mkOption {
          type = types.listOf (types.strMatching "^[A-Za-z0-9_][A-Za-z0-9._-]{0,127}$");
          default = [ ];
          description = "Additional OCI image tags published alongside version and semver tags.";
        };
        runAsNonRoot = mkOption {
          type = types.bool;
          default = true;
          description = "Run container as a numeric non-root user and enable restricted PSS tests.";
        };
        user = mkOption {
          type = userSubmodule;
          default = { };
          description = "Primary non-root user identity when runAsNonRoot = true.";
        };
        extraUsers = mkOption {
          type = types.attrsOf extraUserSubmodule;
          default = { };
          description = "Additional /etc/passwd and /etc/group entries (e.g. privilege-dropping daemon users).";
        };
        includeCaCerts = mkOption {
          type = types.bool;
          default = true;
          description = "Include CA certificates in the image.";
        };
        includeTzdata = mkOption {
          type = types.bool;
          default = true;
          description = "Include tzdata and set TZDIR.";
        };
        enableShell = mkOption {
          type = types.bool;
          default = false;
          description = "Include bash, coreutils, /bin/sh, and /usr/bin/env.";
        };
        dirs = mkOption {
          type = types.attrsOf (dirSubmodule defaultUid defaultGid);
          default = { };
          description = "Declarative directories created in the image with mode, uid, and gid.";
        };
        structureTest = mkOption {
          type = types.coercedTo types.path lib.singleton (types.listOf types.path);
          default = [ ];
          description = "Path(s) to container-structure-test YAML configuration(s).";
        };
        contents = mkOption {
          type = types.coercedTo types.package lib.singleton (types.listOf types.package);
          default = [ ];
          description = "Additional packages to include in the image.";
        };
        config = mkOption {
          type = ociConfigSubmodule;
          default = { };
          description = "OCI image runtime configuration (Entrypoint, Cmd, Env, ExposedPorts, Volumes, Labels, User, WorkingDir).";
        };
        meta = mkOption {
          type = types.attrsOf types.raw;
          default = { };
          description = "Additional derivation meta attributes.";
        };
        passthru = mkOption {
          type = passthruSubmodule;
          default = { };
          description = "Additional derivation passthru attributes (including custom passthru.tests).";
        };
        extraCommands = mkOption {
          type = types.lines;
          default = "";
          description = "Extra shell commands executed while assembling the customization layer.";
        };
        fakeRootCommands = mkOption {
          type = types.lines;
          default = "";
          description = "Extra shell commands executed under fakeroot.";
        };
        variants = mkOption {
          type = types.attrsOf (types.attrsOf types.raw);
          default = { };
          description = "Named container variants (<name>-<variant>) inheriting from this base image.";
        };
      };
    };

  additiveTopKeys = [
    "contents"
    "structureTest"
    "extraTags"
    "extraCommands"
    "fakeRootCommands"
  ];

  mapLeavesDefault = lib.mapAttrs (_: lib.mkDefault);

  toVariantBaseArgs =
    variantDefaultName: baseArgs:
    let
      stripped = removeAttrs baseArgs [
        "name"
        "variants"
      ];
      wrapTopKey =
        k: v:
        if builtins.elem k additiveTopKeys then
          v
        else if k == "user" && builtins.isAttrs v then
          mapLeavesDefault v
        else if (k == "dirs" || k == "extraUsers") && builtins.isAttrs v then
          lib.mapAttrs (_: spec: if builtins.isAttrs spec then mapLeavesDefault spec else spec) v
        else if k == "config" && builtins.isAttrs v then
          lib.mapAttrs (
            ck: cv:
            if ck == "Env" || ck == "ExposedPorts" || ck == "Volumes" then
              cv
            else if ck == "Labels" && builtins.isAttrs cv then
              mapLeavesDefault cv
            else
              lib.mkDefault cv
          ) v
        else if k == "meta" && builtins.isAttrs v then
          mapLeavesDefault v
        else if k == "passthru" && builtins.isAttrs v then
          lib.mapAttrs (
            pk: pv: if pk == "tests" && builtins.isAttrs pv then mapLeavesDefault pv else lib.mkDefault pv
          ) v
        else
          lib.mkDefault v;
    in
    (lib.mapAttrs wrapTopKey stripped)
    // {
      name = lib.mkDefault variantDefaultName;
    };

  evalSingleConfig =
    {
      oci,
      modules,
      hasExplicitUser,
    }:
    let
      evaluated = lib.evalModules {
        modules = [
          (mkImageModule {
            inherit (oci) defaultSource formatLicenses packageLicense;
          })
        ]
        ++ modules;
      };
      cfg = evaluated.config;
      opts = evaluated.options;
      passthroughArgs = removeAttrs cfg ([ "_module" ] ++ builtins.attrNames opts);
      extraUserNames = map (u: u.name) (builtins.attrValues cfg.extraUsers);
      allUserNames = lib.optional cfg.runAsNonRoot cfg.user.name ++ extraUserNames;
    in
    assert lib.assertMsg (
      !(lib.hasInfix "--" cfg.name)
    ) "containerTools: `name` ('${cfg.name}') cannot contain '--'";
    assert lib.assertMsg (
      cfg.runAsNonRoot || !hasExplicitUser
    ) "containerTools: `user` cannot be set when `runAsNonRoot = false` (use `extraUsers` instead)";
    assert lib.assertMsg (
      builtins.length allUserNames == builtins.length (lib.unique allUserNames)
    ) "containerTools: duplicate usernames across `user` and `extraUsers`";
    {
      inherit cfg passthroughArgs;
    };

  cleanCallPackageAttrs =
    attrs:
    removeAttrs attrs [
      "override"
      "overrideDerivation"
    ];

  evalImageConfig =
    { oci, args }:
    let
      cleanArgs = cleanCallPackageAttrs args;

      base = evalSingleConfig {
        inherit oci;
        modules = [ { config = cleanArgs; } ];
        hasExplicitUser = cleanArgs ? user;
      };

      variants = lib.mapAttrs (
        variantName: rawVariantArgs:
        let
          variantArgs = cleanCallPackageAttrs rawVariantArgs;
        in
        assert lib.assertMsg (
          builtins.match "^[a-z0-9][a-z0-9._-]*$" variantName != null && !(lib.hasInfix "--" variantName)
        ) "containerTools: invalid variant name '${variantName}'";
        assert lib.assertMsg (
          !(variantArgs ? variants)
        ) "containerTools: nested `variants` inside variant '${variantName}' are not supported";
        evalSingleConfig {
          inherit oci;
          modules = [
            { config = toVariantBaseArgs "${base.cfg.name}-${variantName}" cleanArgs; }
            { config = variantArgs; }
          ];
          hasExplicitUser = variantArgs ? user;
        }
      ) base.cfg.variants;
    in
    base // { inherit variants; };
in
{
  perSystem._module.args.evalImageConfig = evalImageConfig;
}
