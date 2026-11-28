{
  lib,
  containerTools,
  nut,
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
in
containerTools.buildLayeredImage {
  imports = [ containerTools.mixins.dinit ];
  package = nut;
  category = "monitoring";
  runAsNonRoot = false;
  enableShell = true;
  extraUsers.nutmon = nutmon;
  dirs = {
    ${confDir} = {
      inherit (nutmon) gid;
      mode = "0750";
    };
    ${stateDir} = nutStateDir;
    "/var/state/ups" = nutStateDir;
  };
  dinit.services = {
    upsdrv = {
      type = "scripted";
      command = "${lib.getExe' nut "upsdrvctl"} -u \${NUT_USER:-root} start";
      stopCommand = "${lib.getExe' nut "upsdrvctl"} stop";
    };
    upsd = {
      command = "${lib.getExe' nut "upsd"} -u \${NUT_USER:-root} -F";
      dependsOn = [ "upsdrv" ];
    };
  };
  config = {
    Env = [
      "NUT_CONFPATH=${confDir}"
      "NUT_STATEPATH=${stateDir}"
      "NUT_ALTPIDPATH=${stateDir}"
      "NUT_USER=root"
    ];
    ExposedPorts = {
      "3493/tcp" = { };
    };
    Volumes = {
      ${stateDir} = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
