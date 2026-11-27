{ config, lib, ... }:
let
  envPrefix = lib.toUpper config.name;
in
{
  imports = [
    ./config-dir.nix
    ./dotnet.nix
    {
      config = {
        config.Env = [
          "${envPrefix}__UPDATE__MECHANISM=External"
          "${envPrefix}__UPDATE__AUTOMATICALLY=false"
        ];
        structureTest = [
          {
            _name = "${config.name}-servarr";
            metadataTest.envVars = [
              {
                key = "${envPrefix}__UPDATE__MECHANISM";
                value = "External";
              }
              {
                key = "${envPrefix}__UPDATE__AUTOMATICALLY";
                value = "false";
              }
            ];
          }
        ];
      };
    }
  ];
}
