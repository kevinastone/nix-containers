{
  callPackage,
  containerTools,
  ffmpeg-headless,
}:
containerTools.buildLayeredImage {
  name = "ffmpeg";
  package = ffmpeg-headless;
  description = "Minimal headless FFmpeg container";
  structureTest = ./structure-test.yaml;

  variants.argo = callPackage ./argo { };
}
