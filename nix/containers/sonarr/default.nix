{
  containerTools,
  sonarr,
}:
containerTools.buildLayeredImage {
  imports = [ containerTools.mixins.servarr ];
  package = sonarr;
  category = "media";
  config = {
    Cmd = [
      "--nobrowser"
      "--data=/config"
    ];
    Env = [
      "SONARR__UPDATE__BRANCH=develop"
    ];
    ExposedPorts = {
      "8989/tcp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
