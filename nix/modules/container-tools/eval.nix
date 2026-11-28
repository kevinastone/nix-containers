{
  lib,
  oci,
  mkImageModule,
}:
let
  isPlainAttrs = v: builtins.isAttrs v && !(lib.isDerivation v) && (v._type or null) == null;

  isAdditiveType =
    t:
    t.name == "listOf"
    || t.name == "separatedString"
    || (t.name == "coercedTo" && isAdditiveType t.nestedTypes.finalType);

  wrapByType =
    t: val:
    if (val._type or null) != null || isAdditiveType t then
      val
    else if t.name == "submodule" && isPlainAttrs val then
      wrapByOptTree (t.getSubOptions [ ]) val
    else if t.name == "attrsOf" && isPlainAttrs val then
      lib.mapAttrs (_: wrapByType t.nestedTypes.elemType) val
    else
      lib.mkDefault val;

  wrapByOptTree =
    optTree: attrSet:
    lib.mapAttrs (
      k: v:
      if optTree ? ${k} then
        let
          node = optTree.${k};
        in
        if lib.isOption node then
          wrapByType node.type v
        else if builtins.isAttrs node && isPlainAttrs v then
          wrapByOptTree node v
        else
          lib.mkDefault v
      else
        lib.mkDefault v
    ) attrSet;

  toVariantBaseArgs =
    baseOpts: variantDefaultName: baseArgs:
    let
      stripped = removeAttrs baseArgs [
        "imports"
        "name"
        "variants"
      ];
    in
    wrapByOptTree baseOpts stripped
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
      inherit cfg opts passthroughArgs;
    };
in
args:
let
  cleanArgs = cleanCallPackageAttrs args;

  base = evalSingleConfig {
    modules = (cleanArgs.imports or [ ]) ++ [
      {
        config = removeAttrs cleanArgs [ "imports" ];
      }
    ];
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
      modules =
        (cleanArgs.imports or [ ])
        ++ [
          {
            config = toVariantBaseArgs base.opts "${base.cfg.name}-${variantName}" cleanArgs;
          }
        ]
        ++ (variantArgs.imports or [ ])
        ++ [
          {
            config = removeAttrs variantArgs [ "imports" ];
          }
        ];
      hasExplicitUser = variantArgs ? user;
    }
  ) base.cfg.variants;
in
removeAttrs base [ "opts" ] // { inherit variants; }
