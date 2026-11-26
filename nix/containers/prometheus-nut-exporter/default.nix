{
  containerTools,
  prometheus-nut-exporter,
}:
containerTools.buildLayeredImage {
  name = "prometheus-nut-exporter";
  package = prometheus-nut-exporter;
  config = {
    ExposedPorts = {
      "9199/tcp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
