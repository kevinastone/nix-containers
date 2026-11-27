{
  calibre-web,
  containerTools,
}:
containerTools.buildLayeredImage {
  imports = [
    containerTools.mixins.configDir
    containerTools.mixins.python
  ];
  package = calibre-web;
  category = "media";
  dirs = {
    "/books" = { };
  };
  config = {
    Cmd = [
      "-p"
      "/config/app.db"
      "-g"
      "/config/gdrive.db"
    ];
    Volumes = {
      "/books" = { };
    };
    Env = [
      "CALIBRE_DBPATH=/config"
      "CACHE_DIRECTORY=/tmp"
    ];
    ExposedPorts = {
      "8083/tcp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
