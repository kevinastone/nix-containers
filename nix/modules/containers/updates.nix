{ lib, repoRoot }:
let
  isLocalPackage = pkg: lib.hasPrefix repoRoot (pkg.meta.position or "");

  isGitHubPackage =
    pkg:
    lib.hasInfix "github.com" (pkg.src.url or (lib.head (pkg.src.urls or [ "" ])))
    || lib.hasInfix "github.com" (pkg.meta.homepage or "");

  mkSpec = name: pkg: {
    inherit name;
    args = pkg.nixUpdateArgs or (lib.optionals (isGitHubPackage pkg) [ "--use-github-releases" ]);
  };

  mkUpdatePackageSpecs =
    { activeContainers, firstDrv }:
    let
      collectSpecs =
        container:
        let
          drv = firstDrv container;
          pkg = drv.package or null;
          primary = lib.optional (pkg != null && isLocalPackage pkg) (mkSpec pkg.pname pkg);
          extra = lib.mapAttrsToList mkSpec (drv.updatePackages or { });
        in
        primary ++ extra;
    in
    lib.unique (lib.concatMap collectSpecs activeContainers);

  collectSystemUpdatePackages =
    allContainers:
    lib.foldl' (
      acc: drv:
      let
        pkg = drv.package or null;
        primary = lib.optionalAttrs (pkg != null && isLocalPackage pkg) {
          ${pkg.pname} = pkg;
        };
      in
      acc // primary // (drv.updatePackages or { })
    ) { } (builtins.attrValues allContainers);
in
{
  inherit collectSystemUpdatePackages mkUpdatePackageSpecs;
}
