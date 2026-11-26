{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule (finalAttrs: {
  pname = "tf-runner";
  version = "0.17.0";

  src = fetchFromGitHub {
    owner = "flux-iac";
    repo = "tofu-controller";
    tag = "v${finalAttrs.version}";
    hash = "sha256-AdDxZnmcCllZwyfBAXRb4s+E6J5JZZXtahN9TIgpHn8=";
  };

  vendorHash = "sha256-pgvMftuiCOIWeRQQDW4WXuftogD8WFPL8tIgRkUdzu8=";

  subPackages = [ "cmd/runner" ];

  env.CGO_ENABLED = 0;

  ldflags = [
    "-s"
    "-w"
    "-X main.BuildVersion=v${finalAttrs.version}"
  ];

  # Tests require kubebuilder/envtest assets
  doCheck = false;

  postInstall = ''
    mv $out/bin/runner $out/bin/tf-runner
  '';

  meta = {
    description = "Flux Tofu Controller runner";
    homepage = "https://github.com/flux-iac/tofu-controller";
    license = lib.licenses.asl20;
    mainProgram = "tf-runner";
  };
})
