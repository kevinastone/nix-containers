{
  containerTools,
  qbittorrent-nox,
}:
containerTools.buildLayeredImage {
  name = "qbittorrent";
  package = qbittorrent-nox;
  category = "media";
  dirs = {
    "/config" = { };
  };
  config = {
    WorkingDir = "/config";
    Volumes = {
      "/config" = { };
    };
    Env = [
      "QBT_CONFIRM_LEGAL_NOTICE=1"
      "HOME=/config"
      "XDG_CONFIG_HOME=/config"
      "XDG_DATA_HOME=/config"
    ];
    ExposedPorts = {
      "8080/tcp" = { };
      "6881/tcp" = { };
      "6881/udp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
