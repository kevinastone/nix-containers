{
  lib,
  dockerTools,
  bash,
  coreutils,
  ffmpeg-headless,
  gawk,
  jq,
  writeShellApplication,
}:
let
  argo-ffmpeg-progress = writeShellApplication {
    name = "argo-ffmpeg-progress";
    runtimeInputs = [ gawk ];
    text = builtins.readFile ./argo-ffmpeg-progress.sh;
  };
in
dockerTools.buildImage rec {
  name = "ffmpeg";
  tag = ffmpeg-headless.version;
  copyToRoot = with dockerTools; [
    usrBinEnv
    binSh
    fakeNss
    bash
    coreutils
    ffmpeg-headless
    jq
    argo-ffmpeg-progress
  ];
  config.Entrypoint = [ (lib.getExe ffmpeg-headless) ];
  config.Labels = {
    "org.opencontainers.image.title" = name;
  };
}
