{
  config = {
    config.Env = [
      "PYTHONDONTWRITEBYTECODE=1"
      "PYTHONUNBUFFERED=1"
    ];
    structureTest = [
      {
        _name = "python";
        metadataTest.envVars = [
          {
            key = "PYTHONDONTWRITEBYTECODE";
            value = "1";
          }
          {
            key = "PYTHONUNBUFFERED";
            value = "1";
          }
        ];
      }
    ];
  };
}
