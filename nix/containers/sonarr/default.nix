{
  containerTools,
  sonarr,
}:
containerTools.buildLayeredImage {
  package = sonarr;
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
      "SONARR__UPDATE__MECHANISM=External"
      "SONARR__UPDATE__AUTOMATICALLY=false"
      "SONARR__UPDATE__BRANCH=develop"
    ];
    ExposedPorts = {
      "8989/tcp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
