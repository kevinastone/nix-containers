# Developer & AI Agent Guidelines (AGENTS.md)

Welcome! If you are an AI coding assistant (like Antigravity) or a developer onboarding to this repository, please read these instructions to understand the code architecture, tooling, and coding standards of `nix-containers`.

---

## 🛠️ Tooling & Commands

A root `justfile` (available inside `nix develop` / `direnv`) provides shortcuts for common maintainer workflows (`just --list`):

```bash
just fmt              # Format the entire codebase (nix fmt)
just check            # Verify flake config, checks, and formatting (nix flake check)
just new <container>  # Scaffold default.nix, structure-test.yaml, and README.md + sync catalog
just build <container># Build the Linux OCI image tarball into ./result (works on macOS + Linux)
just test <container> # Build image, run OCI/structure/restricted tests, and run dive --ci
just dive <container> # Build image and inspect layers interactively in dive
just inspect <name>   # Inspect dependency tree in nix-tree (--derivation)
```

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
just build ffmpeg
# or directly on Linux:
nix build .#ffmpeg
```

### 3. Debugging & Inspecting
Enter the Nix devShell to load development tools like `just`, `dive`, `nix-tree`, `nvd`, `regctl`, `skopeo`, and custom helper scripts:
```bash
nix develop
```

Once in the devShell, you can inspect the OCI container layers or store closure:
```bash
dive-archive ./result
just inspect ffmpeg
```

### 4. Version Control (`jj`)
Prefer Jujutsu (`jj`) over `git` for all version-control operations (e.g., `jj status`, `jj diff`, `jj log`, `jj file list`).

- **Commit Rule:** Always commit changes locally (e.g., `jj commit -m "..."`) after completing each task or step, once formatted with `nix fmt` and verified with relevant checks (`nix flake check`).
- **Push Rule:** **Never** push to a remote (`jj git push` or `git push`) without explicit user consent. Always verify and ask the user before pushing changes.

---

## 📁 Repository Structure

- `flake.nix`: Entry point using `flake-parts` that imports `nix/modules/*`.
- `justfile`: Task runner recipes (`new`, `build`, `test`, `dive`, `inspect`, `fmt`, `check`, `readme`).
- `docs/`: Documentation (`contributing.md`, `container-tools.md`, `architecture.md`).
- `nix/modules/`:
  - `container-tools/`:
    - `default.nix`: `flake-parts` module wiring internal image builder helpers and exposing `containerTools` via `perSystem` `_module.args`.
    - `schema.nix`: Declarative `mkOption` and submodule definitions for `buildLayeredImage` (`category`, `user`, `extraUsers`, `dirs`, `enableShell`, `structureTest`, `config`, `variants`, etc.).
    - `eval.nix`: `lib.evalModules` evaluator, variant option inheritance (`toVariantBaseArgs`), and user/name assertions.
    - `oci.nix`: Pure OCI label, platform metadata, `Env` deduplication, and runtime `Config` helpers (`mkLabels`, `mkMeta`, `mkConfig`).
    - `rootfs.nix`: `fakeNss` `/etc/passwd` + `/etc/group` builder, declarative directory `mkdir`/`chmod`/`chown` layer commands, and baseline rootfs `structureTest` generation.
    - `mixins/`: Reusable `lib.evalModules` mixins (`config-dir.nix`, `python.nix`, `dotnet.nix`, `servarr.nix`) with built-in `structureTest` assertions.
    - `build-image.nix`: Thin wrapper around `pkgs.dockerTools.buildLayeredImage`, `closureInfo`, `streamLayeredImage`, variant builds, and test suite wiring.
    - `tests/`:
      - `default.nix`: Test suite builder (`ociTest`, `structureTest`, `restrictedTest`, `mkTestSuite`).
      - `run-tests.nu`: Nushell test runner (`passthru.test`) that loads the OCI archive once, executes every test in `passthru.tests` against `<runtime> <image>`, and removes the image on exit.
      - `test-oci.nu` / `test-structure.nu` / `test-restricted.nu`: Single-purpose tests for OCI labels, `container-structure-test` suites, and Kubernetes `restricted` Pod Security Standard enforcement.
  - `containers/`:
    - `default.nix`: `flake-parts` module wiring container discovery, `catalog`, `ci`, and `updates` into `flake.lib` and `perSystem`.
    - `discovery.nix`: Auto-discovers `nix/containers/*/default.nix`, expands `variants`, and filters by `meta.platforms`.
    - `catalog.nix`: Computes `flake.lib.catalog` (`docPath`, `recipePath`, `platforms`, `description`).
    - `ci.nix`: GitHub Actions runner pins (`ubuntuRunnerVersion`), SemVer tag expansion, and `flake.lib.ci`.
    - `updates.nix`: Custom package discovery (`flake.lib.updatePackageSpecs` and `legacyPackages.updatePackages`) for `nix-update`.
  - `devshell.nix`: `flake-parts` module configuring `devShells.default`.
  - `nixpkgs.nix`: `flake-parts` module configuring `perSystem` `pkgs` (`allowUnfreePredicate`).
  - `nushell.nix`: `flake-parts` module exposing `writeNuApplication` via `perSystem` `_module.args`.
  - `scripts/`:
    - `default.nix`: `flake-parts` module exposing CI and dev CLI packages plus `checks.readme-catalog`.
    - `lib.nu`: Shared Nushell helpers (`linux-system`, `$GITHUB_OUTPUT` / `$GITHUB_STEP_SUMMARY` writers, temporary git worktrees, and exponential-backoff retries).
    - `ci/`:
      - `ci-matrix.nu`: Filters the build/push matrix against GHCR's `dev.nix-containers.drv.<arch>` annotations to skip unchanged containers.
      - `flake-update-report.nu`: Diffs changed containers across branches/commits, renders `nvd` runtime closure changelogs, and syncs idempotent PR comments.
      - `push-multiarch.nu`: Stages multi-architecture OCI indexes by digest (`stage`) and promotes mutable tags atomically (`promote`) after signing/attestation.
      - `update-packages.nu`: Wrapper around `nix-update` with per-package fault isolation for custom container packages.
    - `dev/`:
      - `inspect-image.nu`: Validates `dive --ci` layer efficiency, summarizes sizes and top runtime store paths (`nix path-info`), and diffs closures vs `main` with `nvd`.
      - `new-container.nu`: Scaffolds `nix/containers/<name>/{default.nix,structure-test.yaml,README.md}`.
      - `scan-image.nu`: Generates SPDX SBOMs (`syft` `nix-cataloger`) and scans for vulnerabilities (`grype`).
      - `update-readme.nu`: Renders and syncs the `README.md` container catalog table from `flake.lib.catalog` (validated by `checks.readme-catalog`).
  - `treefmt.nix`: `flake-parts` module configuring `treefmt-nix` (`just`, `keep-sorted`, `nixfmt`, `statix`, `deadnix`, `nufmt`, `action-validator`, `ghalint`, `zizmor`, `yamlfmt`, `shfmt`, `shellcheck`, `typos`).
- `nix/containers/`:
  - `ffmpeg/`:
    - `default.nix`: OCI image derivation for minimal `ffmpeg` (`variants.argo = callPackage ./argo { }`).
    - `structure-test.yaml`: Base `container-structure-test` suite.
    - `argo/`: Self-contained `ffmpeg-argo` variant (`default.nix`, `argo-ffmpeg-progress.sh`, `structure-test.yaml`).
- `.github/`:
  - `renovate.jsonc`: Mend Renovate configuration managing weekly `flake.lock` updates and SHA-pinned GitHub Actions updates.
  - `workflows/`:
    - `pr.yaml`: Pull-request workflow that validates the flake, posts `nvd` closure changelogs on PRs, and fans out read-only `_build.yaml` checks (safe for fork PRs).
    - `ci.yaml`: Main/dispatch CI/CD workflow that validates the flake, detects changed containers via `ci-matrix`, and fans out full build-and-publish pipelines (`_publish.yaml`).
    - `_build.yaml`: Read-only reusable workflow that builds and smoke-tests a container across its supported architectures (`amd64`/`arm64`) with `contents: read` (safe for fork PRs).
    - `_publish.yaml`: Reusable per-container publish workflow that calls `_build.yaml`, stages the multi-arch OCI index by digest, signs and attests provenance + per-arch SBOMs, and atomically promotes mutable tags on GHCR.
    - `update-packages.yaml`: Weekly scheduled workflow that updates custom packages (`nix-update`) and opens/updates a PR with `nvd` runtime closure changelogs.
- `AGENTS.md`: Onboarding guidelines for developers and AI agents (this file).

---

## ➕ Adding a New Container

To add a new container (for example, `keycloak`):
1. Run `just new <name>` (or `nix run .#new-container -- <name>`) inside the devShell to scaffold `nix/containers/<name>/{default.nix,structure-test.yaml,README.md}`, track the files with `jj`, sync the `README.md` catalog, and format.
   - `containerTools.buildLayeredImage` accepts `package` to automatically derive `name`, `tag`, `description`, `config.Entrypoint`, and package inclusion (or pass/override any of those explicitly). Non-root user (`65532:65532` with `/home/nonroot` and `HOME=/home/nonroot`, customizable via `user = { uid = 1000; gid = 1000; name = "app"; }`), `caCertificates`, `tzdata`, writable `/tmp`, declarative `dirs` (`{ "/var/lib/app" = { mode = "0755"; uid = 65532; gid = 65532; }; }`), and standard OCI labels including `org.opencontainers.image.source` are supported out of the box (`runAsNonRoot`, `includeCaCerts`, `includeTzdata`, and `enableShell` can all be toggled).
2. Customize `default.nix`, `structure-test.yaml`, and `README.md` (plus any container-specific scripts or assets alongside them in `nix/containers/<name>/`).
   - Keep `<name>` minimal and general-purpose (`enableShell = false` unless required by the upstream entrypoint). For workflow/role integrations or alternate package flavors, define `variants.<variant> = { ... };` on `buildLayeredImage` to publish `<name>-<variant>` while inheriting scalar options and merging `contents`, `structureTest`, `dirs`, and `config` fields.
3. Ensure any additional files are tracked by running `jj status`, sync the catalog if descriptions changed (`just readme`), and verify with `just fmt` and `just check` (plus `just test <name>` to build and test the image).
