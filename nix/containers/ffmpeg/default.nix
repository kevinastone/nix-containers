{
  callPackage,
  containerTools,
  ffmpeg-headless,
}:
containerTools.buildLayeredImage {
  name = "ffmpeg";
  package = ffmpeg-headless;
  category = "media";
  description = "Minimal headless FFmpeg container";
  structureTest = ./structure-test.yaml;

  variants.argo = callPackage ./argo { };
}
