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

### 4. Version Control (`jj`)
Prefer Jujutsu (`jj`) over `git` for all version-control operations (e.g., `jj status`, `jj diff`, `jj log`, `jj file list`).

- **Commit Rule:** Always commit changes locally (e.g., `jj commit -m "..."`) after completing each task or step, once formatted with `nix fmt` and verified with relevant checks (`nix flake check`).
- **Push Rule:** **Never** push to a remote (`jj git push` or `git push`) without explicit user consent. Always verify and ask the user before pushing changes.

---

## 📁 Repository Structure

- `flake.nix`: Entry point using `flake-parts` that imports `nix/modules/*`.
- `nix/modules/`:
  - `container-tools/`:
    - `default.nix`: `flake-parts` module exposing `containerTools` via `perSystem` `_module.args`.
    - `oci.nix`: Pure OCI label and platform metadata helpers (`packageLicense`, `mkLabels`, `mkMeta`).
    - `build-image.nix`: Wraps `pkgs.dockerTools` (`buildImage`/`buildLayeredImage`) with `nonRootNss`, default contents/shell, and test suite wiring.
    - `tests/`:
      - `default.nix`: Test suite wiring (`ociTest`, `structureTest`, `restrictedTest`, `mkTestSuite`).
      - `run-tests.nu`: Nushell test runner (`passthru.test`) that loads the OCI archive once, executes every test in `passthru.tests` against `<runtime> <image>`, and removes the image on exit.
      - `test-oci.nu` / `test-structure.nu` / `test-restricted.nu`: Single-purpose tests for OCI labels, `container-structure-test` suites, and Kubernetes `restricted` Pod Security Standard enforcement.
  - `containers.nix`: `flake-parts` module that auto-discovers `nix/containers/*/default.nix`, filters by `meta.platforms`, and computes `flake.lib.containers`, `flake.lib.catalog`, and `flake.lib.ci`.
  - `devshell.nix`: `flake-parts` module configuring `devShells.default`.
  - `nushell.nix`: `flake-parts` module exposing `writeNuApplication` via `perSystem` `_module.args`.
  - `scripts/`:
    - `default.nix`: `flake-parts` module exposing shared CI/dev packages (`ci-matrix`, `push-multiarch`, `update-readme`, `dive-archive`) and `checks.readme-catalog`.
    - `ci-matrix.nu`: CI/CD Nushell script that filters the build/push matrix against GHCR's `dev.nix-containers.drv.<arch>` annotations to skip unchanged containers.
    - `push-multiarch.nu`: CI/CD Nushell script to assemble and push multi-architecture OCI manifests.
    - `update-readme.nu`: Nushell script (`nix run .#update-readme`) that renders and syncs the `README.md` container catalog table from `flake.lib.catalog` (validated by `checks.readme-catalog`).
  - `treefmt.nix`: `flake-parts` module configuring `treefmt-nix` (`nixfmt`, `statix`, `deadnix`, `nufmt`, `actionlint`, `yamlfmt`, `shfmt`, `shellcheck`).
- `nix/containers/`:
  - `ffmpeg/`:
    - `default.nix`: OCI image derivation for `ffmpeg`.
    - `argo-ffmpeg-progress.sh`: Progress tracker script packaged into the `ffmpeg` container.
    - `structure-test.yaml`: Declarative `container-structure-test` suite run against the built `ffmpeg` image.
- `.github/workflows/`:
  - `ci.yaml`: Top-level CI/CD workflow that validates the flake, detects changed containers via `ci-matrix`, and fans out read-only builds on PRs (`_build.yaml`) or full build-and-publish pipelines on non-PR runs (`_publish.yaml`).
  - `_build.yaml`: Read-only reusable workflow that builds and smoke-tests a container across its supported architectures (`amd64`/`arm64`) with `contents: read` (safe for fork PRs).
  - `_publish.yaml`: Reusable per-container publish workflow that calls `_build.yaml` and publishes, signs, and attests the multi-arch OCI index on GHCR.
  - `update-flake.yaml`: Weekly scheduled workflow to update `flake.lock` and trigger `ci.yaml`.
- `AGENTS.md`: Onboarding guidelines for developers and AI agents (this file).

---

## ➕ Adding a New Container

To add a new container (for example, `keycloak`):
1. Create `nix/containers/<name>/default.nix` using `containerTools.buildLayeredImage` (or `containerTools.buildImage`). Pass `package` to automatically derive `name`, `tag`, `description`, `config.Entrypoint`, and package inclusion (or pass/override any of those explicitly). Non-root user (`65532:65532`), `caCertificates`, `tzdata`, writable `/tmp`, and standard OCI labels including `org.opencontainers.image.source` are enabled by default (`runAsNonRoot`, `includeCaCerts`, `includeTzdata`, and `enableShell` can all be toggled).
2. Put any container-specific scripts or assets alongside it in `nix/containers/<name>/`.
3. Ensure new files are tracked by running `jj status` (Jujutsu automatically tracks new non-ignored files in the colocated Git index so Nix Flakes includes them in evaluation; use `git add` only if not using `jj`).
4. Run `nix fmt` and `nix flake check`.
