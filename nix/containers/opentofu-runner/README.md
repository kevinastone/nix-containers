# `opentofu-runner`

- **Image**: `ghcr.io/kevinastone/nix-containers/opentofu-runner`
- **Recipe**: [default.nix](default.nix)
- **Tests**: [structure-test.yaml](structure-test.yaml)

A minimal, non-root (`65532:65532`) Flux [Tofu Controller](https://github.com/flux-iac/tofu-controller) runner (`tf-runner`) image bundled with [OpenTofu](https://opentofu.org/) from Nixpkgs, replacing `ghcr.io/home-operations/opentofu-runner`.

Includes `tf-runner`, `opentofu`, `tini`, `git`, `gnupg`, `openssh`, `bash`, and `coreutils`.

## Flux Tofu Controller Helm Values

```yaml
runner:
  image:
    repository: ghcr.io/kevinastone/nix-containers/opentofu-runner
    tag: main
```
