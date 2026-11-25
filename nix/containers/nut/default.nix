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
    name = "nutmon";
    uid = 100;
    gid = 100;
    home = stateDir;
  };

  nutNss = containerTools.mkUserNss nutmon;

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
  runAsNonRoot = false;
  enableShell = true;
  contents = [
    nutNss
    nut-entrypoint
  ];
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
