{ lib, ... }:
let
  inherit (lib) mkOption types;

  defaultNonRootUser = {
    name = "nonroot";
    uid = 65532;
    gid = 65532;
    home = "/home/nonroot";
  };

  userSubmodule = types.submodule (
    { config, ... }:
    {
      options = {
        name = mkOption {
          type = types.nonEmptyStr;
          default = defaultNonRootUser.name;
          description = "Username recorded in /etc/passwd and /etc/group.";
        };
        uid = mkOption {
          type = types.ints.positive;
          default = defaultNonRootUser.uid;
          description = "Numeric UID (> 0) for Config.User and default directory ownership.";
        };
        gid = mkOption {
          type = types.ints.positive;
          default = config.uid;
          description = "Numeric GID (> 0) for Config.User and default directory ownership.";
        };
        home = mkOption {
          type = types.nullOr (types.strMatching "^/.+");
          default = "/home/${config.name}";
          description = "Absolute home directory path (created automatically), or null to omit.";
        };
      };
    }
  );

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

  mkImageModule =
    {
      contentsAttr,
      supportsFakeRoot,
      defaultSource,
      packageLicense,
    }:
    { config, ... }:
    let
      defaultUid = if config.runAsNonRoot && supportsFakeRoot then config.user.uid else 0;
      defaultGid = if config.runAsNonRoot && supportsFakeRoot then config.user.gid else 0;
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
          type = types.nonEmptyStr;
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
          type = types.nullOr types.str;
          default = if config.package != null then packageLicense config.package else null;
          description = "SPDX license expression for org.opencontainers.image.licenses.";
        };
        runAsNonRoot = mkOption {
          type = types.bool;
          default = true;
          description = "Run container as a numeric non-root user and enable restricted PSS tests.";
        };
        user = mkOption {
          type = userSubmodule;
          default = { };
          description = "Non-root user identity when runAsNonRoot = true.";
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
          type = types.nullOr types.path;
          default = null;
          description = "Path to a container-structure-test YAML configuration.";
        };
        ${contentsAttr} = mkOption {
          type = types.either types.package (types.listOf types.package);
          default = [ ];
          apply = lib.toList;
          description = "Additional packages to include in the image.";
        };
        config = mkOption {
          type = types.attrsOf types.raw;
          default = { };
          description = "OCI image runtime configuration (Entrypoint, Cmd, Env, ExposedPorts, Labels, User, WorkingDir).";
        };
        meta = mkOption {
          type = types.attrsOf types.raw;
          default = { };
          description = "Additional derivation meta attributes.";
        };
        passthru = mkOption {
          type = types.attrsOf types.raw;
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
          description = "Extra shell commands executed under fakeroot (buildLayeredImage only).";
        };
      };
    };

  evalImageConfig =
    {
      contentsAttr,
      supportsFakeRoot,
      oci,
      args,
    }:
    let
      evaluated = lib.evalModules {
        modules = [
          (mkImageModule {
            inherit contentsAttr supportsFakeRoot;
            inherit (oci) defaultSource packageLicense;
          })
          { config = args; }
        ];
      };
      cfg = evaluated.config;
      opts = evaluated.options;
      passthroughArgs = removeAttrs cfg ([ "_module" ] ++ builtins.attrNames opts);
    in
    assert lib.assertMsg (
      cfg.runAsNonRoot || !(args ? user)
    ) "containerTools: `user` cannot be set when `runAsNonRoot = false`";
    {
      inherit cfg passthroughArgs;
    };
in
{
  perSystem._module.args.imageOptions = {
    inherit defaultNonRootUser evalImageConfig;
  };
}
