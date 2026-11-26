# CI/CD & Architecture

`nix-containers` combines Nix's content-addressed dependency graph with multi-architecture OCI indexes and keyless supply-chain attestations.

---

## Module Layout

- **[`nix/modules/container-tools/`](../nix/modules/container-tools/default.nix)**: Evaluates container schemas (`schema.nix`, `eval.nix`), builds `/etc/passwd` + directory permissions (`rootfs.nix`), constructs OCI labels and runtime configs (`oci.nix`), wraps `dockerTools.buildLayeredImage` + `streamLayeredImage` (`build-image.nix`), and wires OCI/structure/restricted test suites (`tests/`).
- **[`nix/modules/containers/`](../nix/modules/containers/default.nix)**: Auto-discovers `nix/containers/*/default.nix`, expands `variants` (`discovery.nix`), and exports `flake.lib.catalog` (`catalog.nix`), `flake.lib.ci` (`ci.nix`), and `flake.lib.updatePackageSpecs` (`updates.nix`).
- **[`nix/modules/scripts/`](../nix/modules/scripts/default.nix)**: Nushell automation split between GitHub Actions workflows (`ci/`) and local maintainer tools (`dev/`).

---

## Build & Publish Pipeline

The GitHub Actions workflows in [`.github/workflows/`](../.github/workflows/) run in five stages:

1. **Flake Validation & Change Detection (`pr.yaml`, `ci.yaml`, `ci-matrix.nu`)**
   - Runs `nix flake check` (validating `treefmt`, `statix`, `deadnix`, `shellcheck`, `action-validator`, `ghalint`, `zizmor`, `typos`, and `README.md` catalog sync).
   - Evaluates `.#lib.ci` to obtain each container's supported architectures (`amd64`, `arm64`) and Nix `.drv` store paths (`drvPath`).
   - Queries GHCR's `:main` OCI index annotations (`dev.nix-containers.drv.amd64` and `dev.nix-containers.drv.arm64`) and skips any container whose derivation hashes have not changed.

2. **Per-Architecture Streaming, Testing & Scanning (`_build.yaml`)**
   - Builds `.#<container>.streamArchive` (`dockerTools.streamLayeredImage | pigz -nT`) so large final image tarballs are not duplicated in the Nix store cache.
   - Loads the archive once into Docker and runs `oci`, `structure`, and `restricted` Pod Security Standard tests.
   - Runs `inspect-image` (`dive --ci` layer efficiency, top runtime Nix store dependencies, and `nvd` closure diff vs. `main`).
   - Runs `scan-image` (`syft` with `nix-cataloger` to emit a per-arch SPDX JSON SBOM, followed by `grype` vulnerability scanning).
   - Safe for fork pull requests (`contents: read` only, no secrets required).

3. **Digest-Only Multi-Arch Staging (`_publish.yaml`, `push-multiarch stage`)**
   - Imports per-architecture tarballs into a temporary local OCI layout, creates a multi-arch OCI image index annotated with OCI metadata and `dev.nix-containers.drv.<arch>`, and pushes the index **by `@sha256:...` digest only** (before any mutable tags move).

4. **Signing & Supply-Chain Attestations (`_publish.yaml`)**
   - Signs the multi-arch OCI index digest keylessly with Sigstore `cosign` via GitHub Actions OIDC.
   - Attaches a GitHub SLSA build provenance attestation to the multi-arch index digest.
   - Attaches per-architecture SPDX SBOM attestations directly to the `amd64` and `arm64` manifest digests.

5. **Atomic Tag Promotion (`push-multiarch promote`)**
   - Only after signing and all attestations succeed, promotes the verified index digest to `:main`, SemVer tags (`<major>.<minor>.<patch>`, `<major>.<minor>`, `<major>`), and any configured `extraTags`.

---

## Automated Dependency Maintenance

- **Weekly Flake & Action Updates ([`.github/renovate.jsonc`](../.github/renovate.jsonc))**: Renovate updates `flake.lock`, SHA-pinned GitHub Actions, and runner version pins (`# renovate:` comments in Nix files) with a 3-day `minimumReleaseAge` cooldown.
- **Custom Package Updates ([`.github/workflows/update-packages.yaml`](../.github/workflows/update-packages.yaml))**: Discovers local Nix packages (such as `tf-runner`) via `.#lib.updatePackageSpecs`, runs `nix-update` with per-package fault isolation, syncs the `README.md` catalog, and opens/updates a pull request containing `nvd` runtime closure changelogs (`flake-update-report`).
