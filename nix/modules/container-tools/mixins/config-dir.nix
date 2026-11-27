{ config, lib, ... }:
let
  dirCfg = config.dirs."/config";
in
{
  config = {
    dirs."/config" = { };
    config = {
      WorkingDir = lib.mkDefault "/config";
      Volumes."/config" = { };
    };
    structureTest = [
      {
        _name = "config-dir";
        metadataTest = {
          workdir = "/config";
          volumes = [ "/config" ];
        };
        fileExistenceTests = [
          {
            name = "/config exists";
            path = "/config";
            shouldExist = true;
            inherit (dirCfg) uid gid;
            permissions = "drwxr-xr-x";
          }
        ];
      }
    ];
  };
}
