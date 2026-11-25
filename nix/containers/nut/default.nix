{
  lib,
  containerTools,
  nut,
  writeShellApplication,
}:
let
  nutNss = containerTools.mkUserNss {
    name = "nutmon";
    uid = 100;
    gid = 100;
    home = "/var/run/nut";
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
    "/etc/nut" = {
      gid = 100;
      mode = "0750";
    };
    "/var/run/nut" = {
      uid = 100;
      gid = 100;
      mode = "0750";
    };
    "/var/state/ups" = {
      uid = 100;
      gid = 100;
      mode = "0750";
    };
  };
  config = {
    Entrypoint = [ (lib.getExe nut-entrypoint) ];
    Env = [
      "NUT_CONFPATH=/etc/nut"
      "NUT_STATEPATH=/var/run/nut"
      "NUT_ALTPIDPATH=/var/run/nut"
    ];
    ExposedPorts = {
      "3493/tcp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
