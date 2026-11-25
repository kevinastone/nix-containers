{
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
  package = ffmpeg-headless;
  description = "Minimal ffmpeg container with Argo Workflows progress reporting";
  copyToRoot = with containerTools; [
    usrBinEnv
    binSh
    fakeNss
    bash
    coreutils
    jq
    argo-ffmpeg-progress
  ];
}
