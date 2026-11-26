{
  containerTools,
  sabnzbd,
  unrar,
}:
containerTools.buildLayeredImage {
  package = sabnzbd;
  category = "media";
  licenses = [
    sabnzbd.meta.license
    unrar.meta.license
  ];
  dirs = {
    "/config" = { };
  };
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
    WorkingDir = "/config";
    Volumes = {
      "/config" = { };
    };
    Env = [
      "PYTHONDONTWRITEBYTECODE=1"
      "PYTHONUNBUFFERED=1"
    ];
    ExposedPorts = {
      "8080/tcp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
