# TODO & Roadmap

Tracked tooling, PR testing improvements, and architectural optimizations to make managing and scaling `nix-containers` easier.

---

## 🧪 Testing New & Changed Container PRs

- [x] **Unblock fork PRs by splitting `build` vs. `push` workflow permissions**: Split read-only builds (`.github/workflows/_build.yaml`, requiring only `contents: read`) from publishing (`.github/workflows/_publish.yaml`) so Pull Requests from forks automatically build and smoke-test on `amd64` and `arm64`.
- [x] **Enforce Kubernetes `restricted` runtime flags in container tests**: Added `nix/modules/container-tools/test-restricted.nu` (`passthru.tests.restricted`) to verify numeric non-zero `Config.User` UIDs and run commands under `--read-only --tmpfs /tmp --cap-drop=ALL --security-opt=no-new-privileges` (unless opted out via `runAsNonRoot = false` or `passthru.tests.restricted = null`).
- [ ] **Add daemon / readiness integration testing (`dgoss` or health-probe runner)**: `container-structure-test` only runs one-shot CLI commands (`--version`, `--help`) and static file checks. Add an optional `serviceTest` helper (using `dgoss`/`goss` or a Nushell background container health probe) that boots long-running containers (`keycloak`, `nut`, web/DB services), waits for TCP/HTTP readiness (e.g., `:9000/health/ready`), and asserts clean startup/shutdown logs.
- [ ] **Require `test.yaml` & `README.md` for new containers in `nix flake check`**: Today, a PR adding `nix/containers/<name>/default.nix` without `test.yaml` silently falls back to `ociTest` (which checks 3 OCI labels without executing the binary). Add a flake check asserting every container either provides `test.yaml` + `README.md` or explicitly opts out, and validate `test.yaml` files against the `container-structure-test` schema.
- [ ] **Automated PR inspection summary (`dive --ci`, `nvd`, closure size)**: Post a markdown report to `$GITHUB_STEP_SUMMARY` on every PR `build` job showing:
  - Total compressed image size, uncompressed size, and layer count.
  - Headless layer-efficiency check via `dive --ci` (failing on excessive wasted space).
  - Top runtime store dependencies (`nix path-info -rsSh`) and package version diffs vs. `main` via `nvd` (`Nix/NixOS version diff`).

---

## 🛠️ Repo Management & Maintainer Tooling

- [ ] **Unified maintainer task runner (`just` + Nushell helpers)**: Add `just` (with a root `justfile` in `devShells.default`) and flake apps so maintainers and contributors don't have to memorize multi-arch flake paths:
  - `just new <name>` (`nix run .#new-container -- <name>`): Scaffolds `default.nix`, `test.yaml`, and `README.md`, runs `git add`, updates the `README.md` catalog, and runs `nix fmt`.
  - `just test <name>`: Builds the Linux image (automatically targeting `.#packages.aarch64-linux.<name>` via `linux-builder`/OrbStack when run on macOS) and runs `.#<name>.test` + `dive --ci`.
  - `just inspect <name>`: Opens `nix-tree` (to trace `why-depends` bloat) or `dive-archive` (harden `dive-archive` in `nix/scripts/default.nix` to handle both `.tar.gz` and `.tar` without FIFO pipe issues).
- [ ] **Closure inspection & diff tools in `devShell` (`nix-tree`, `nvd`, `regctl`, `cosign`)**: Expand `devShells.default` in `flake.nix` with `nix-tree` (interactive dependency explorer to trim image bloat), `nvd` / `nix-diff` (compare two container closures), `regctl`, `container-structure-test`, `cosign`, and `nushell`.
- [ ] **PR-gated `flake.lock` updates with `nvd` changelogs**: `.github/workflows/update-flake.yaml` currently runs eval-only `nix flake check` and pushes directly to `main` before images are built. Switch to opening an automated PR (via `peter-evans/create-pull-request` + GitHub auto-merge, or Renovate) that includes an `nvd` table of bumped upstream package versions per container and waits for multi-arch builds + smoke tests to pass before merging.
- [ ] **Deduplicated Nix CI binary caching (`magic-nix-cache` or `cachix`)**: As more containers (especially JVM/heavy closures like `keycloak`) are added across `amd64` and `arm64`, monolithic `cache-nix-action` tarballs in `.github/actions/setup-nix/action.yml` will hit GitHub Actions' 10 GB cache eviction limit. Adopt `DeterminateSystems/magic-nix-cache-action` (or `cachix`) for per-NAR deduplication across containers and runs.
- [ ] **Workflow & supply-chain security gates (`zizmor`, `pinact`, `sbomnix` + `grype`/`vulnix`)**:
  - Add `zizmor` (GitHub Actions security linter) and `typos` to `nix/modules/treefmt.nix`, pin Actions to full commit SHAs (`pinact`), and group `.github/dependabot.yml` PRs.
  - Generate Nix-native SBOMs (`sbomnix` or `syft`) for `actions/attest-sbom` and scan them with `grype` or `vulnix` on PRs (since standard scanners miss packages in dpkg/apk-less Nix images).
  - Add scheduled GHCR retention cleanup for untagged/superseded `:main` manifests while preserving semver tags and Sigstore referrers.

---

## 📦 `containerTools` & Publishing Polish

- [ ] **Evaluate `nix2container` or `dockerTools.streamLayeredImage` + direct per-arch digest pushes**: Avoid writing intermediate `.tar.gz` archives into `/nix/store` and uploading/downloading artifacts between `build` and `push` jobs—push arch blobs directly from `build` runners by digest and assemble the multi-arch OCI index remotely in `push`.
- [ ] **Declarative directory ownership (`dirs` helper) & `/home/nonroot` default**: Replace world-writable `chmod 1777` workarounds in `nix/containers/keycloak/default.nix` and root-owned `0750` dirs in `nix/containers/nut/default.nix` with a `dirs` option setting exact `uid:gid` + mode, and create `/home/nonroot` (`HOME=/home/nonroot`) by default when `runAsNonRoot = true`.
- [x] **Keep `ociTest` enabled alongside custom `passthru.tests` and load once**: Ensure `nix/modules/container-tools/default.nix` always runs OCI label checks and loads/removes the archive once across multiple test suites.
- [ ] **Workflow `concurrency`, richer semver tags, & `org.opencontainers.image.revision`**: Add `concurrency` groups to cancel stale PR builds while queuing `main` pushes, add `{{major}}.{{minor}}` tags + `passthru` tag aliases for downstream Renovate/GitOps users, and stamp `org.opencontainers.image.revision` at publish time in `nix/scripts/push-multiarch.nu`.
