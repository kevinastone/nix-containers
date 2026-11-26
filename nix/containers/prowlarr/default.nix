{
  containerTools,
  prowlarr,
}:
containerTools.buildLayeredImage {
  package = prowlarr;
  dirs = {
    "/config" = { };
  };
  config = {
    Cmd = [
      "--nobrowser"
      "--data=/config"
    ];
    WorkingDir = "/config";
    Volumes = {
      "/config" = { };
    };
    Env = [
      "DOTNET_EnableDiagnostics=0"
      "PROWLARR__UPDATE__MECHANISM=External"
      "PROWLARR__UPDATE__AUTOMATICALLY=false"
    ];
    ExposedPorts = {
      "9696/tcp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
