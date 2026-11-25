{
  lib,
  containerTools,
  nut,
  writeShellApplication,
}:
let
  nutNss = containerTools.fakeNss.override {
    extraPasswdLines = [ "nutmon:x:100:100:NUT:/var/run/nut:/sbin/nologin" ];
    extraGroupLines = [ "nutmon:x:100:" ];
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
  extraCommands = ''
    mkdir -p ./etc/nut ./var/run/nut ./var/state/ups
    chmod 0750 ./var/run/nut ./var/state/ups
  '';
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
  structureTest = ./test.yaml;
}
