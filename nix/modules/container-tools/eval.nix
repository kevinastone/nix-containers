{
  lib,
  oci,
  mkImageModule,
}:
let
  additiveTopKeys = [
    "contents"
    "features"
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

  cleanCallPackageAttrs =
    attrs:
    removeAttrs attrs [
      "override"
      "overrideDerivation"
    ];

  evalSingleConfig =
    { modules, hasExplicitUser }:
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
in
args:
let
  cleanArgs = cleanCallPackageAttrs args;

  base = evalSingleConfig {
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
      modules = [
        { config = toVariantBaseArgs "${base.cfg.name}-${variantName}" cleanArgs; }
        { config = variantArgs; }
      ];
      hasExplicitUser = variantArgs ? user;
    }
  ) base.cfg.variants;
in
base // { inherit variants; }
