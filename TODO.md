# TODO & Roadmap

Tracked ideas and recommended improvements as `nix-containers` grows into a general multi-container repository.

---

## 🧹 Repo Hygiene (Quick Wins)

- [x] **Remove duplicate root `dependabot.yml`**: Delete `./dependabot.yml` (GitHub only reads `.github/dependabot.yml`, which already exists with identical contents).
- [x] **Add `LICENSE` file**: Both `README.md` and `containerTools`'s default `org.opencontainers.image.licenses` declare `MIT`, so add a root `LICENSE` file to match.

---

## 📦 `containerTools` & Image Architecture

- [x] **Default to `buildLayeredImage` (or `streamLayeredImage`)**: `buildImage` packs the entire closure into a single tarball layer. Switching to `buildLayeredImage` splits Nix store paths across layers so GHCR and Kubernetes/Docker nodes deduplicate shared dependencies (`glibc`, `bash`, `coreutils`) across containers and upgrades. (Ensure `dive-archive` handles uncompressed `.tar` archives too if `streamLayeredImage` is used.)
- [x] **Non-root user support by default**: Add an opt-out non-root user helper (e.g., `65532:65532` / `nonroot` via `fakeNss.override` and `config.User`) so images satisfy Kubernetes `runAsNonRoot: true` Pod Security Standards out of the box.
- [x] **TLS / timezone defaults**: Add opt-out or shorthand options for `dockerTools.caCertificates` and `tzdata` so networked containers don't fail outbound HTTPS verification.
- [x] **Distroless vs. shell presets**: Add a clean toggle (e.g., `enableShell ? false`) to include `usrBinEnv`, `binSh`, `bash`, and `coreutils` when needed (like Argo steps in `ffmpeg`) while keeping pure single-binary services distroless by default.

---

## 🤖 CI/CD & Supply-Chain Security

- [x] **Build changed containers on Pull Requests**: Currently PRs only run `nix flake check` (`treefmt`) and skip `build`, so broken container derivations aren't caught until merge to `main`. Run `ci-matrix` + `build` on PRs while keeping `push-multiarch` gated to `main`.
- [x] **Scope GitHub Actions `permissions` per job**: Tighten workflow-level permissions in `ci.yaml` and `update-flake.yaml` to `contents: read`, granting `packages: write` (and `id-token: write`) only on the jobs that actually publish or push commits.
- [x] **Keyless image signing (`cosign`) & attestations**: Sign published multi-arch OCI index digests using Sigstore `cosign` with GitHub OIDC (`id-token: write`), and consider attaching SBOMs (`sbomnix` / `syft`) or SLSA build provenance.
- [ ] **Richer tagging options**: Decide whether `:latest` should be published alongside `:main` and `:<version>`, and allow containers to opt into extra tag aliases (e.g., major/minor semver or flavor tags) via `passthru` metadata.

---

## 🧪 Testing & Linting

- [x] **Container smoke tests**: Support an optional smoke test per container (e.g., running `<entrypoint> --version` or `container-structure-test` against the built archive in CI before pushing) so broken runtime paths or missing dynamic libs fail before publishing.
- [x] **Expand `treefmt` & static checks**: Add `actionlint` + `yamlfmt` (for `.github/workflows/*.yaml`) and `shfmt` + `shellcheck` (for container scripts like `argo-ffmpeg-progress.sh`) in `nix/modules/treefmt.nix`.

---

## 🛠️ Developer Experience

- [ ] **Container scaffolding (`new-container` script or flake template)**: Add a Nushell helper (`nix run .#new-container -- <name>`) to scaffold `nix/containers/<name>/default.nix` from a minimal template.
- [ ] **Auto-generated container catalog in `README.md`**: Generate or validate the `README.md` container table from `flake.lib` metadata (`name`, `description`, `version`, `platforms`) so documentation stays in sync as containers are added.
- [ ] **macOS Linux-builder ergonomics**: Document (or add a flake helper/app for) building `.#packages.aarch64-linux.<container>` from macOS using `nix-darwin`'s `linux-builder` or OrbStack.
