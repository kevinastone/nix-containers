{
  config = {
    config.Env = [
      "DOTNET_EnableDiagnostics=0"
    ];
    structureTest = [
      {
        _name = "dotnet";
        metadataTest.envVars = [
          {
            key = "DOTNET_EnableDiagnostics";
            value = "0";
          }
        ];
      }
    ];
  };
}
