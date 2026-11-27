{
  containerTools,
  exportarr,
}:
containerTools.buildLayeredImage {
  package = exportarr;
  category = "monitoring";
  config = {
    Env = [
      "PORT=9707"
    ];
    ExposedPorts = {
      "9707/tcp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
