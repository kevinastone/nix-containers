# Developer & AI Agent Guidelines (AGENTS.md)

Welcome! If you are an AI coding assistant (like Antigravity) or a developer onboarding to this repository, please read these instructions to understand the code architecture, tooling, and coding standards of `nix-containers`.

---

## 🛠️ Tooling & Commands

### 1. Code Formatting
`nix-containers` is fully Nix-integrated. To format the entire codebase, always run:
```bash
nix fmt
```

### 2. Building & Validating
To verify the flake config, checks, and formatting:
```bash
nix flake check
```

To build a specific OCI container image locally (which produces the symlink `./result` pointing to the built tarball):
```bash
nix build .#<container>
# e.g.:
nix build .#ffmpeg
```

### 3. Debugging & Inspecting
Enter the Nix devShell to load development tools like `dive`, `skopeo`, and custom helper scripts:
```bash
nix develop
```

Once in the devShell, you can inspect the OCI container layers using the `dive-archive` helper:
```bash
dive-archive ./result
```

### 4. Git Commits
Do **not** commit any code changes using `git commit` without explicitly asking and obtaining confirmation from the user first.

---

## 📁 Repository Structure

- `flake.nix`: Entry point using `flake-parts` that wires up `nix/modules/`, `push-multiarch`, and `devShells.default`.
- `nix/modules/`:
  - `container-tools/`:
    - `default.nix`: `flake-parts` module exposing `overlays.default` (adding `pkgs.containerTools`, which wraps `pkgs.dockerTools` with `buildImage`/`buildLayeredImage`, standard OCI labels, `meta.platforms`, `passthru.tests`, and optional `package` defaults) and configuring `perSystem` `pkgs`.
    - `smoke-test.nu`: Nushell runner wrapped by `containerTools.ociTest` / `containerTools.structureTest` (attached via `passthru.tests`).
  - `containers.nix`: `flake-parts` module that auto-discovers `nix/containers/*/default.nix`, filters by `meta.platforms`, and computes `flake.lib.containers` and `flake.lib.ci.{build,push}`.
  - `treefmt.nix`: `flake-parts` module configuring `treefmt-nix` (`nixfmt`, `statix`, `deadnix`, `nufmt`, `actionlint`, `yamlfmt`, `shfmt`, `shellcheck`).
- `nix/containers/`:
  - `ffmpeg/`:
    - `default.nix`: OCI image derivation for `ffmpeg`.
    - `argo-ffmpeg-progress.sh`: Progress tracker script packaged into the `ffmpeg` container.
    - `test.yaml`: Declarative `container-structure-test` suite run against the built `ffmpeg` image.
- `nix/scripts/`:
  - `ci-matrix.nu`: CI/CD Nushell script that filters the build/push matrix against GHCR's `dev.nix-containers.drv.<arch>` annotations to skip unchanged containers.
  - `push-multiarch.nu`: CI/CD Nushell script to assemble and push multi-architecture OCI manifests.
  - `default.nix`: Nix packaging expressions for shared CI and dev shell scripts (`ci-matrix`, `push-multiarch`, `dive-archive`).
- `.github/workflows/`:
  - `ci.yaml`: CI/CD pipeline that validates the flake, auto-discovers containers from `flake.nix`, builds images for `amd64`/`arm64`, and publishes them to `ghcr.io/${{ github.repository }}/<container>`.
- `AGENTS.md`: Onboarding guidelines for developers and AI agents (this file).

---

## ➕ Adding a New Container

To add a new container (for example, `keycloak`):
1. Create `nix/containers/<name>/default.nix` using `containerTools.buildLayeredImage` (or `containerTools.buildImage`). Pass `package` to automatically derive `name`, `tag`, `description`, `config.Entrypoint`, and package inclusion (or pass/override any of those explicitly). Non-root user (`65532:65532`), `caCertificates`, `tzdata`, writable `/tmp`, and standard OCI labels including `org.opencontainers.image.source` are enabled by default (`runAsNonRoot`, `includeCaCerts`, `includeTzdata`, and `enableShell` can all be toggled).
2. Put any container-specific scripts or assets alongside it in `nix/containers/<name>/`.
3. Stage new files with `git add` so Nix Flakes includes them in evaluation.
4. Run `nix fmt` and `nix flake check`.
