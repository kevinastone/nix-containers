{
  containerTools,
  sabnzbd,
  unrar,
}:
containerTools.buildLayeredImage {
  imports = [
    containerTools.mixins.configDir
    containerTools.mixins.python
  ];
  package = sabnzbd;
  category = "media";
  licenses = [
    sabnzbd.meta.license
    unrar.meta.license
  ];
  config = {
    Cmd = [
      "--browser"
      "0"
      "--server"
      "[::]:8080"
      "--config-file"
      "/config/sabnzbd.ini"
      "--console"
    ];
    ExposedPorts = {
      "8080/tcp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
