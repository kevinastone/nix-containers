{
  containerTools,
  dnsdist,
}:
containerTools.buildLayeredImage {
  package = dnsdist;
  category = "networking";
  dirs = {
    "/etc/dnsdist" = { };
  };
  config = {
    Cmd = [
      "--supervised"
      "--disable-syslog"
      "--config"
      "/etc/dnsdist/dnsdist.conf"
    ];
    ExposedPorts = {
      "53/tcp" = { };
      "53/udp" = { };
      "8083/tcp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
