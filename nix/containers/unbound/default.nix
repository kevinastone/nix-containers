{
  cacert,
  containerTools,
  dns-root-data,
  unbound,
  writeText,
}:
let
  defaultConfig = writeText "unbound.conf" ''
    server:
      interface: 0.0.0.0
      interface: ::0
      port: 5335
      do-daemonize: no
      username: ""
      chroot: ""
      directory: "/etc/unbound"
      pidfile: ""
      use-syslog: no
      logfile: ""
      trust-anchor-file: "${dns-root-data}/root.key"
      tls-cert-bundle: "${cacert}/etc/ssl/certs/ca-bundle.crt"
      access-control: 127.0.0.0/8 allow
      access-control: ::1/128 allow
      access-control: 10.0.0.0/8 allow
      access-control: 172.16.0.0/12 allow
      access-control: 192.168.0.0/16 allow
      access-control: fc00::/7 allow

    include: "/config/*.conf"
  '';
in
containerTools.buildLayeredImage {
  package = unbound;
  category = "networking";
  dirs = {
    "/config" = { };
  };
  extraCommands = ''
    mkdir -p ./etc/unbound
    ln -sf ${defaultConfig} ./etc/unbound/unbound.conf
  '';
  config = {
    Cmd = [
      "-d"
      "-p"
      "-c"
      "/etc/unbound/unbound.conf"
    ];
    Volumes = {
      "/config" = { };
    };
    ExposedPorts = {
      "5335/tcp" = { };
      "5335/udp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
