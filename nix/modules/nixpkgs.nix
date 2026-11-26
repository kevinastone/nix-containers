{ inputs, lib, ... }:
let
  allowedUnfreeRedistributable = [
    "unrar"
  ];
in
{
  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfreePredicate =
          pkg:
          let
            licenses = lib.flatten (lib.toList (pkg.meta.license or [ ]));
            isRedistributable = licenses != [ ] && builtins.all (l: l.redistributable or false) licenses;
          in
          isRedistributable && builtins.elem (lib.getName pkg) allowedUnfreeRedistributable;
      };
    };
}
