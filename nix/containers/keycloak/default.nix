{
  containerTools,
  keycloak,
  gnugrep,
  gnused,
  findutils,
  writeText,
}:
let
  keycloakRoot = "/opt/keycloak";
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
    "${keycloakRoot}/conf" = { };
    "${keycloakRoot}/data" = { };
    "${keycloakRoot}/providers" = { };
    "${keycloakRoot}/themes" = { };
  };
  extraCommands = ''
    ln -s ${keycloakWithMetrics}/bin .${keycloakRoot}/bin
    ln -s ${keycloakWithMetrics}/lib .${keycloakRoot}/lib
  '';
  config = {
    Entrypoint = [ "${keycloakRoot}/bin/kc.sh" ];
    Cmd = [
      "start"
      "--optimized"
    ];
    WorkingDir = keycloakRoot;
    Env = [
      "HOME=${keycloakRoot}"
      "KC_HOME_DIR=${keycloakRoot}"
      "KC_CONF_DIR=${keycloakRoot}/conf"
    ];
    ExposedPorts = {
      "8080/tcp" = { };
      "8443/tcp" = { };
      "9000/tcp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
