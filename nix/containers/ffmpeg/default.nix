{
  lib,
  containerTools,
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
containerTools.buildImage {
  name = "ffmpeg";
  tag = ffmpeg-headless.version;
  description = "Minimal ffmpeg container with Argo Workflows progress reporting";
  copyToRoot = with containerTools; [
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
}
