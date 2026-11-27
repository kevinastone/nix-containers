{
  containerTools,
  prowlarr,
}:
containerTools.buildLayeredImage {
  imports = [ containerTools.mixins.servarr ];
  package = prowlarr;
  category = "media";
  config = {
    Cmd = [
      "--nobrowser"
      "--data=/config"
    ];
    ExposedPorts = {
      "9696/tcp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
