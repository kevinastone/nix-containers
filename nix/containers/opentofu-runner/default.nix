{
  lib,
  stdenv,
  callPackage,
  catatonit,
  containerTools,
  gitMinimal,
  gnupg,
  openssh,
  opentofu,
}:
let
  tf-runner = callPackage ./tf-runner.nix { };
in
containerTools.buildLayeredImage {
  name = "opentofu-runner";
  package = tf-runner;
  category = "infrastructure";
  description = "Flux Tofu Controller runner with OpenTofu";
  enableShell = true;
  user.name = "runner";
  contents = [
    gitMinimal
    gnupg
    openssh
    opentofu
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ catatonit ];
  config = {
    Entrypoint = [
      "/bin/catatonit"
      "--"
      (lib.getExe tf-runner)
    ];
    Env = [
      "GNUPGHOME=/tmp"
    ];
    ExposedPorts = {
      "30000/tcp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
  meta.platforms = lib.platforms.linux;
}
