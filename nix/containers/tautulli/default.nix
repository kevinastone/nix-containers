{
  containerTools,
  tautulli,
}:
containerTools.buildLayeredImage {
  imports = [
    containerTools.mixins.configDir
    containerTools.mixins.python
  ];
  package = tautulli;
  category = "media";
  config = {
    Entrypoint = [ "${tautulli}/bin/tautulli" ];
    Cmd = [
      "--nolaunch"
      "--datadir"
      "/config"
      "--config"
      "/config/config.ini"
    ];
    ExposedPorts = {
      "8181/tcp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
