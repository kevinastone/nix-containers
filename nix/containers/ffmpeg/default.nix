{
  containerTools,
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
containerTools.buildLayeredImage {
  name = "ffmpeg";
  package = ffmpeg-headless;
  description = "Minimal ffmpeg container with Argo Workflows progress reporting";
  enableShell = true;
  contents = [
    jq
    argo-ffmpeg-progress
  ];
  structureTest = ./structure-test.yaml;
}
