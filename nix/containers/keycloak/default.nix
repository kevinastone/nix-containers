{
  containerTools,
  keycloak,
  gnugrep,
  gnused,
  findutils,
  writeText,
}:
let
  keycloakWithMetrics = keycloak.override {
    confFile = writeText "keycloak.conf" ''
      db=postgres
      health-enabled=true
      metrics-enabled=true
      http-metrics-histograms-enabled=true
      event-metrics-user-enabled=true
    '';
  };
in
containerTools.buildLayeredImage {
  package = keycloakWithMetrics;
  enableShell = true;
  contents = [
    gnugrep
    gnused
    findutils
  ];
  dirs = {
    "/opt/keycloak/conf" = { };
    "/opt/keycloak/data" = { };
    "/opt/keycloak/providers" = { };
    "/opt/keycloak/themes" = { };
  };
  extraCommands = ''
    ln -s ${keycloakWithMetrics}/bin ./opt/keycloak/bin
    ln -s ${keycloakWithMetrics}/lib ./opt/keycloak/lib
  '';
  config = {
    Entrypoint = [ "/opt/keycloak/bin/kc.sh" ];
    Cmd = [
      "start"
      "--optimized"
    ];
    WorkingDir = "/opt/keycloak";
    Env = [
      "HOME=/opt/keycloak"
      "KC_HOME_DIR=/opt/keycloak"
      "KC_CONF_DIR=/opt/keycloak/conf"
    ];
    ExposedPorts = {
      "8080/tcp" = { };
      "8443/tcp" = { };
      "9000/tcp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
