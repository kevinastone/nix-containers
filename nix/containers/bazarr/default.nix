{
  lib,
  stdenv,
  bazarr,
  containerTools,
  ffmpeg-headless,
  tini,
}:
let
  bazarrHeadless = bazarr.override {
    ffmpeg = ffmpeg-headless;
  };
in
containerTools.buildLayeredImage {
  package = bazarrHeadless;
  category = "media";
  # Bazarr's wrapper (bazarr.py) spawns a child worker (bazarr/main.py) that
  # only handles SIGINT across the process group and exits with non-zero status
  # 156. Use tini (rather than catatonit) so we can both forward SIGINT to the
  # process group (-g) and remap exit status 156 to 0 (-e 156).
  contents = lib.optionals stdenv.hostPlatform.isLinux [ tini ];
  dirs = {
    "/config" = { };
  };
  config = {
    Entrypoint = [
      "/bin/tini"
      "-g"
      # Upstream defines EXIT_INTERRUPT = -100; os._exit(-100) wraps to 156
      # (-100 & 0xff) on graceful SIGINT shutdown (see NixOS's SuccessExitStatus = "0 156").
      "-e"
      "156"
      "--"
      (lib.getExe bazarrHeadless)
    ];
    Cmd = [
      "--no-update"
      "--config"
      "/config"
    ];
    WorkingDir = "/config";
    StopSignal = "SIGINT";
    Volumes = {
      "/config" = { };
    };
    Env = [
      "PYTHONDONTWRITEBYTECODE=1"
      "PYTHONUNBUFFERED=1"
    ];
    ExposedPorts = {
      "6767/tcp" = { };
    };
  };
  structureTest = ./structure-test.yaml;
}
