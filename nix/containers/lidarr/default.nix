{
  containerTools,
  lidarr,
}:
containerTools.buildLayeredImage {
  imports = [ containerTools.mixins.servarr ];
  package = lidarr;
  category = "media";
  config = {
    Cmd = [
      "--nobrowser"
      "--data=/config"
    ];
    ExposedPorts = {
      "8686/tcp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
