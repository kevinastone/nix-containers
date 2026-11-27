{
  containerTools,
  iperf3,
}:
containerTools.buildLayeredImage {
  name = "iperf3";
  package = iperf3;
  category = "networking";
  config = {
    Cmd = [ "--server" ];
    ExposedPorts = {
      "5201/tcp" = { };
      "5201/udp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
