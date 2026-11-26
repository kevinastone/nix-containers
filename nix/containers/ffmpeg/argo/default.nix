{
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
{
  description = "Minimal FFmpeg container with Argo Workflows progress reporting";
  enableShell = true;
  contents = [
    jq
    argo-ffmpeg-progress
  ];
  structureTest = ./structure-test.yaml;
}
