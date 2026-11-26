{
  containerTools,
  radarr,
}:
containerTools.buildLayeredImage {
  package = radarr;
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
      "RADARR__UPDATE__MECHANISM=External"
      "RADARR__UPDATE__AUTOMATICALLY=false"
    ];
    ExposedPorts = {
      "7878/tcp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
