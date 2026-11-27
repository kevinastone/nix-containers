{
  containerTools,
  radarr,
}:
containerTools.buildLayeredImage {
  imports = [ containerTools.mixins.servarr ];
  package = radarr;
  category = "media";
  config = {
    Cmd = [
      "--nobrowser"
      "--data=/config"
    ];
    ExposedPorts = {
      "7878/tcp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
