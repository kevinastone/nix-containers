{
  lib,
  containerTools,
  transmission_4,
}:
containerTools.buildLayeredImage {
  imports = [ containerTools.mixins.configDir ];
  name = "transmission";
  package = transmission_4;
  category = "media";
  config = {
    Entrypoint = [ (lib.getExe' transmission_4 "transmission-daemon") ];
    Cmd = [
      "--foreground"
      "--config-dir"
      "/config"
    ];
    Env = [
      "HOME=/config"
    ];
    ExposedPorts = {
      "9091/tcp" = { };
      "51413/tcp" = { };
      "51413/udp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
