# CI/CD Roadmap & Maintainability Status

Tracking CI/CD hardening across `.github/` and `nix/modules/scripts/` for **zero-toil automation**, **failure isolation**, and **DRY workflows**.

---

## Completed Improvements

- [x] **Split PR vs `main`/dispatch workflows** ([workflows/pr.yaml](workflows/pr.yaml), [workflows/ci.yaml](workflows/ci.yaml), [actions/test-and-discover](actions/test-and-discover/action.yml)) so runs no longer show skipped dual `build`/`publish` matrices.
- [x] **Atomic OCI publishing (`stage` → `sign & attest` → `promote`)** ([workflows/_publish.yaml](workflows/_publish.yaml), [../nix/modules/scripts/push-multiarch.nu](../nix/modules/scripts/push-multiarch.nu)): Multi-arch indexes are staged by digest first, signed with Cosign and attested, and only promoted to `:main` and semver tags once all supply-chain steps succeed.
- [x] **Per-architecture SPDX SBOM attestations** ([workflows/_publish.yaml](workflows/_publish.yaml)): Attests `amd64.spdx.json` and `arm64.spdx.json` against their respective platform manifest digests instead of dropping `arm64`.
- [x] **Deterministic tag computation in Nix** ([../nix/modules/containers.nix](../nix/modules/containers.nix)): Computes semver tags and `extraTags` directly in `flake.lib.ci`, removing `docker/metadata-action`.
- [x] **Resilient registry lookups in `ci-matrix`** ([../nix/modules/scripts/ci-matrix.nu](../nix/modules/scripts/ci-matrix.nu)): Distinguishes `404` (`MANIFEST_UNKNOWN` / `NAME_UNKNOWN`) from transient `429`/`5xx`/auth errors, bounds concurrency (`--threads 8`), retries with exponential backoff, and evaluates `.#lib.ci` directly.
- [x] **Fault-isolated custom package updates** ([../nix/modules/scripts/update-packages.nu](../nix/modules/scripts/update-packages.nu), [../nix/modules/containers.nix](../nix/modules/containers.nix)): Isolates per-package `nix-update` failures, auto-runs `nix fmt` + `update-readme`, and derives `--use-github-releases` dynamically from package metadata (overridable via `passthru.nixUpdateArgs`).
- [x] **Mend Renovate + PR `nvd` closure changelog comments** ([renovate.jsonc](renovate.jsonc), [workflows/pr.yaml](workflows/pr.yaml), [../nix/modules/scripts/flake-update-report.nu](../nix/modules/scripts/flake-update-report.nu)): Replaced `dependabot.yml` and `update-flake.yaml` with Renovate (`nix` + SHA-pinned `github-actions` with 3-day `minimumReleaseAge`, `:maintainLockFilesWeekly`, `group:allNonMajor`, and automerge presets), and moved `flake-update-report` to sync an idempotent sticky PR comment whenever container derivations change.
- [x] **Shared Nushell CI library & workflow cleanup** ([../nix/modules/scripts/lib.nu](../nix/modules/scripts/lib.nu), [actions/open-update-pr](actions/open-update-pr/action.yml), [workflows/_build.yaml](workflows/_build.yaml)): Extracted shared retry/worktree/GitHub helpers into `lib.nu`, moved worktree lifecycle into `inspect-image` and `flake-update-report`, folded no-op path checks into `open-update-pr`, removed dead `inputs.ref` plumbing, staggered schedules off `00:00 UTC`, and added explicit `timeout-minutes` across all jobs.

---

## Remaining / Future Enhancements (As Catalog Scales)

### 1. Install the Mend Renovate GitHub App & Enable Branch Rulesets / Merge Queue
- Install the [Mend Renovate GitHub App](https://github.com/apps/renovate) on `kevinastone/nix-containers` so [renovate.jsonc](renovate.jsonc) begins managing `flake.lock` and GitHub Actions PRs.
- Configure GitHub Repository Rulesets on `main` requiring [workflows/pr.yaml](workflows/pr.yaml) status checks so Renovate's `:automergeMinor` / `:automergeDigest` / `lockFileMaintenance.automerge` presets wait for full container validation before merging (and optionally enable **GitHub Merge Queue**).

### 2. Optional GitHub App Token for `update-packages`
- [actions/open-update-pr/action.yml](actions/open-update-pr/action.yml) accepts `token`, `git-user-name`, and `git-user-email` inputs (defaulting to `github.token`).
- If force-pushes to an already-open `chore/update-packages` PR need to re-trigger `pull_request` (`synchronize`) automatically or auto-merge, mint an installation token via `actions/create-github-app-token` (or consider `peter-evans/create-pull-request`) and pass it to `actions/checkout` and `open-update-pr`.

### 3. Binary Cache & Layer Streaming at Scale (15–30+ Containers)
- **Binary cache graduation:** `DeterminateSystems/magic-nix-cache-action` uses GitHub Actions Cache (capped at **10 GB/repo**). If multi-arch closures begin evicting cache entries, graduate to **Cachix**, **FlakeHub Cache**, or self-hosted **Attic**/**Harmonia** (and consider `DeterminateSystems/nix-installer-action` + `Mic92/nix-fast-build`).
- **Direct layer streaming (`nlewo/nix2container` + `skopeo`):** Eliminates materializing intermediate `.tar.gz` archives and uploading/downloading multi-hundred-MB Actions artifacts between `_build.yaml` and `_publish.yaml`, while enabling fine-grained store-path layer sharing across containers on GHCR.

### 4. Scheduled `:main` Vulnerability Re-Scanning & GHCR Retention
- **Scheduled CVE scan of published images:** Because `ci-matrix` skips containers whose Nix `drvPath` has not changed, newly disclosed CVEs in published `:main` images only surface when `flake.lock` updates. Add a lightweight scheduled scan (or enable `--fail-on` thresholds once a `.grype.yaml` triage baseline is established).
- **GHCR untagged manifest retention:** Periodically prune superseded untagged OCI manifests in GHCR while preserving OCI referrers (`.sig` signatures and SLSA/SPDX attestations) attached to active tagged digests.
