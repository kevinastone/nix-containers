{
  containerTools,
  jackett,
}:
containerTools.buildLayeredImage {
  imports = [
    containerTools.mixins.configDir
    containerTools.mixins.dotnet
  ];
  package = jackett;
  category = "media";
  config = {
    Cmd = [
      "--NoUpdates"
      "--DataFolder"
      "/config"
    ];
    Env = [
      "HOME=/config"
      "XDG_CONFIG_HOME=/config"
      "XDG_DATA_HOME=/config"
    ];
    ExposedPorts = {
      "9117/tcp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
