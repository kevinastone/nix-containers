{
  lib,
  containerTools,
  nut,
  writeShellApplication,
}:
let
  confDir = "/etc/nut";
  stateDir = "/var/run/nut";

  nutmon = {
    uid = 100;
    gid = 100;
    home = stateDir;
  };

  nutStateDir = {
    inherit (nutmon) uid gid;
    mode = "0750";
  };

  nut-entrypoint = writeShellApplication {
    name = "nut-entrypoint";
    runtimeInputs = [ nut ];
    text = builtins.readFile ./nut-entrypoint.sh;
  };
in
containerTools.buildLayeredImage {
  package = nut;
  category = "monitoring";
  runAsNonRoot = false;
  enableShell = true;
  extraUsers.nutmon = nutmon;
  contents = [ nut-entrypoint ];
  dirs = {
    ${confDir} = {
      inherit (nutmon) gid;
      mode = "0750";
    };
    ${stateDir} = nutStateDir;
    "/var/state/ups" = nutStateDir;
  };
  config = {
    Entrypoint = [ (lib.getExe nut-entrypoint) ];
    Env = [
      "NUT_CONFPATH=${confDir}"
      "NUT_STATEPATH=${stateDir}"
      "NUT_ALTPIDPATH=${stateDir}"
    ];
    ExposedPorts = {
      "3493/tcp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
