{
  containersDir,
  activeContainers,
  containerArches,
  firstDrv,
}:
map (
  container:
  let
    arches = containerArches container;
    drv = firstDrv container;
    inherit (drv)
      category
      enableShell
      imageTag
      imageUser
      runAsNonRoot
      sourceDir
      variantKey
      ;
    variantRel =
      if variantKey != null && builtins.pathExists (containersDir + "/${sourceDir}/${variantKey}") then
        "${sourceDir}/${variantKey}"
      else
        null;
    recipePath =
      if variantRel != null && builtins.pathExists (containersDir + "/${variantRel}/default.nix") then
        "nix/containers/${variantRel}/default.nix"
      else
        "nix/containers/${sourceDir}/default.nix";
    docPath =
      if variantRel != null && builtins.pathExists (containersDir + "/${variantRel}/README.md") then
        "nix/containers/${variantRel}/README.md"
      else if builtins.pathExists (containersDir + "/${sourceDir}/README.md") then
        "nix/containers/${sourceDir}/README.md"
      else
        recipePath;
  in
  {
    name = container;
    parent = if variantKey != null then sourceDir else null;
    version = imageTag;
    user = imageUser;
    inherit
      category
      docPath
      enableShell
      recipePath
      runAsNonRoot
      sourceDir
      ;
    description = drv.meta.description or "";
    platforms = map (a: a.platform) arches;
  }
) activeContainers
