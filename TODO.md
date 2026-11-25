# TODO & Roadmap

Tracked tooling, PR testing improvements, and architectural optimizations to make managing and scaling `nix-containers` easier.

---

## 🧪 Testing New & Changed Container PRs

- [x] **Unblock fork PRs by splitting `build` vs. `push` workflow permissions**: Split read-only builds (`.github/workflows/_build.yaml`, requiring only `contents: read`) from publishing (`.github/workflows/_publish.yaml`) so Pull Requests from forks automatically build and smoke-test on `amd64` and `arm64`.
- [x] **Enforce Kubernetes `restricted` runtime flags in container tests**: Added `nix/modules/container-tools/tests/test-restricted.nu` (`passthru.tests.restricted`) to verify numeric non-zero `Config.User` UIDs and run commands under `--read-only --tmpfs /tmp --cap-drop=ALL --security-opt=no-new-privileges` (unless opted out via `runAsNonRoot = false` or `passthru.tests.restricted = null`).
- [x] **Automated PR inspection summary (`dive --ci`, `nvd`, closure size)**: Added `nix/modules/scripts/inspect-image.nu` (`packages.inspect-image`) and wired it into `.github/workflows/_build.yaml` to post a markdown report to `$GITHUB_STEP_SUMMARY` on every build showing compressed/uncompressed sizes, layer count, `dive --ci` efficiency enforcement, top runtime store paths (`nix path-info -sSh`), and `nvd` runtime package diffs vs. `main`.

---

## 🛠️ Repo Management & Maintainer Tooling

- [x] **Unified maintainer task runner (`just` + Nushell helpers)**: Added root `justfile`, `nix/modules/scripts/new-container.nu` (`packages.new-container`), and host-native `legacyPackages.containerTests.<name>`:
  - `just new <name>` (`nix run .#new-container -- <name>`): Scaffolds `default.nix`, `structure-test.yaml`, and `README.md`, runs `jj status`, updates the `README.md` catalog, and runs `nix fmt`.
  - `just test <name>`: Builds `.#packages.<arch>-linux.<name>` and runs host-native `.#containerTests.<name>` + `dive-archive ./result --ci`.
  - `just dive <name>` / `just inspect <name>`: Opens `dive-archive` or `nix-tree --derivation`.
- [x] **Closure inspection & diff tools in `devShell` (`nix-tree`, `nvd`, `regctl`, `cosign`)**: Expanded `devShells.default` in `nix/modules/devshell.nix` with `nix-tree`, `nvd`, `regctl`, `container-structure-test`, `cosign`, `just`, `nushell`, and `update-readme`, and hardened `dive-archive` to support `.tar.gz`/`.tar` files and forwarded CLI flags (`--ci`).
- [x] **PR-gated `flake.lock` updates with `nvd` changelogs**: Updated `.github/workflows/update-flake.yaml` (backed by `passthru.closure` in `build-image.nix` and `nix/modules/scripts/flake-update-report.nu`) to open/update a `chore/update-flake-lock` PR with per-container version + `nvd` runtime closure diffs and validate changed containers via multi-arch `_build.yaml` builds/smoke tests instead of pushing directly to `main`.
- [x] **Deduplicated Nix CI binary caching (`magic-nix-cache-action`)**: Switched `.github/actions/setup-nix/action.yml` from monolithic `cache-nix-action` `/nix/store` tarballs to `DeterminateSystems/magic-nix-cache-action@v15` for per-NAR deduplication across jobs and automatic skipping of `cache.nixos.org` paths.
- [x] **Workflow & supply-chain security gates (`zizmor`, `pinact`, `syft` + `grype`)**:
  - [x] Added `zizmor` and `typos` to `nix/modules/treefmt.nix`, pinned all GitHub Actions to full commit SHAs (`pinact`), hardened workflows (`persist-credentials: false`, `env:` template bindings, dropped `secrets: inherit`), and grouped `.github/dependabot.yml` PRs with a 7-day cooldown.
  - [x] Generate Nix-aware SPDX SBOMs (`syft` `nix-cataloger` via `nix/modules/scripts/scan-image.nu`), attach signed SBOM attestations on publish (`actions/attest`), and post `grype` CVE scan summaries to `$GITHUB_STEP_SUMMARY` on builds.

---

## 📦 `containerTools` & Publishing Polish

- [ ] **Evaluate `nix2container` or `dockerTools.streamLayeredImage` + direct per-arch digest pushes**: Avoid writing intermediate `.tar.gz` archives into `/nix/store` and uploading/downloading artifacts between `build` and `push` jobs—push arch blobs directly from `build` runners by digest and assemble the multi-arch OCI index remotely in `push`.
- [x] **Declarative directory ownership (`dirs` helper), configurable `user`, & `/home/nonroot` default**: Added `dirs` (`mode`/`uid`/`gid` via `fakeRootCommands`), configurable non-root `user = { uid ? 65532; gid ? uid; name ? "nonroot"; home ? "/home/${name}"; }`, and default `/home/nonroot` (`HOME=/home/nonroot`) to `nix/modules/container-tools/build-image.nix`, replacing `chmod 1777` in `nix/containers/keycloak/default.nix` and `0:0` `0750` dirs in `nix/containers/nut/default.nix` with exact numeric ownership verified in `structure-test.yaml`.
- [x] **Keep `ociTest` enabled alongside custom `passthru.tests` and load once**: Handled in `nix/modules/container-tools/tests/` (`default.nix` + `run-tests.nu`), which always includes `ociTest` by default and loads/removes the archive once across all configured test suites.
- [x] **Workflow `concurrency`, richer semver tags, & `org.opencontainers.image.revision`**: Added `concurrency` groups to `ci.yaml` (canceling stale PR runs while queuing `main` publishes) and `update-flake.yaml`, added `{{major}}.{{minor}}` + `{{major}}` semver tags and declarative `extraTags` (`options.nix` + `lib.ci`), and stamped `org.opencontainers.image.revision` at publish time in `nix/modules/scripts/push-multiarch.nu`.
