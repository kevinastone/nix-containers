# CI/CD Roadmap & Maintainability Recommendations

Recommendations for hardening `.github/` workflows and `nix/modules/scripts/` as the container catalog scales, focused on **zero-toil automation**, **failure isolation**, and **DRY workflows**.

---

## Pre-Existing Tools & Ecosystem Evaluation

Before building more custom workflow glue, several mature off-the-shelf tools can delete existing YAML/script boilerplate outright:

| Area | Current Approach | Pre-Existing Alternative | Verdict & Tradeoffs |
| --- | --- | --- | --- |
| **`flake.lock` + Action Updates** | [dependabot.yml](dependabot.yml) + [workflows/update-flake.yaml](workflows/update-flake.yaml) + [actions/open-update-pr](actions/open-update-pr/action.yml) | **Mend Renovate (Hosted GitHub App)** (`nix` + `github-actions` managers) | **Strongly recommended.** Replaces `dependabot.yml` *and* `update-flake.yaml`. Runs as a real GitHub App (solving `GITHUB_TOKEN` PR creation, `synchronize` suppression, and `automerge` with zero token management), pins Action SHAs (`helpers:pinGitHubActionDigestsToSemver`), and provides a Dependency Dashboard issue. *Caveat:* Hosted Renovate disables `postUpgradeTasks`, so it cannot run `nix-update` (FOD hash recalculation) or `flake-update-report` inline — solve the latter by posting `flake-update-report` as a PR comment from `pr.yaml` (which benefits human PRs too). |
| **Custom Nix Package Updates** | [workflows/update-packages.yaml](workflows/update-packages.yaml) + [../nix/modules/scripts/update-packages.nu](../nix/modules/scripts/update-packages.nu) | **`renovatebot/github-action`** (self-hosted Renovate with `postUpgradeTasks`) *or* **`Mic92/nix-update`** + **`peter-evans/create-pull-request`** | Keep `Mic92/nix-update` (nothing else recomputes Nix `hash` / `cargoHash` / `vendorHash` reliably), wrap PR creation with **`peter-evans/create-pull-request`** to delete custom git/branch/`gh pr` shell glue, or run self-hosted `renovatebot/github-action` if unified Dependency Dashboard tracking for custom packages is desired. |
| **PR Creation Boilerplate** | Custom `git checkout -B` / `git push --force` / `gh pr view` / `gh pr create` in [actions/open-update-pr](actions/open-update-pr/action.yml) | **`peter-evans/create-pull-request`** | Battle-tested action that handles no-op diff detection, branch creation/reset, commit signoff, labels, assignees, and automatic branch deletion on merge/close out of the box. |
| **OCI Image Builder & Layering** | `pkgs.dockerTools.buildLayeredImage` `.tar.gz` + GitHub Actions `upload-artifact` / `download-artifact` + `regctl image import` | **`nlewo/nix2container`** + `skopeo` | Worth evaluating as the catalog grows: streams Nix store layers directly to registries/daemons **without materializing `.tar.gz` tarballs on disk** or uploading/downloading multi-hundred-MB Actions artifacts between `build` and `push`, and enables fine-grained cross-container layer sharing (`glibc`, `openssl`, `ca-certificates`) on GHCR. |
| **Nix Installer & Binary Cache** | `cachix/install-nix-action` + `DeterminateSystems/magic-nix-cache-action` | **`DeterminateSystems/nix-installer-action`** + **Cachix / FlakeHub Cache / Attic** | `nix-installer-action` is faster and more resilient in CI. `magic-nix-cache` relies on GitHub Actions Cache (capped at **10 GB/repo**), which will thrash and evict layers once 15–30 multi-arch containers exist; plan to graduate to Cachix, FlakeHub Cache, or self-hosted Attic/Harmonia. |
| **Parallel Nix Evaluation & Builds** | Per-container × per-arch GitHub VM matrix (`nix eval` + `nix build` repeated in every job) | **`Mic92/nix-fast-build`** (or **Garnix** / **buildbot-nix**) | Evaluates the flake once and builds derivations in parallel with streaming cache uploads; particularly impactful if consolidating builds onto larger or self-hosted ARM/x64 runners. |
| **Action SHA Pinning Locally** | Manual SHA + `# vX.Y.Z` comments | **`suzuki-shunsuke/pinact`** (`pkgs.pinact` in `treefmt` / `devShell`) | Automatically resolves and pins `uses: owner/repo@vX` tags to immutable commit SHAs with version comments via `pinact run`, complementing `zizmor` and Renovate. |
| **Concurrent Update Merges** | Direct branch merges into `main` | **GitHub Merge Queue** (Repository Rulesets) | Prevents rebase churn and broken-`main` races when multiple automated container/action PRs are ready to merge simultaneously. |

### Recommended Target Architecture (Minimal Custom Code)
1. **Adopt Hosted Renovate** to delete [dependabot.yml](dependabot.yml) and [workflows/update-flake.yaml](workflows/update-flake.yaml) (enable `lockFileMaintenance`, `pinDigests`, and `automerge` for non-breaking updates).
2. **Move `flake-update-report` (`nvd` changelog) into [workflows/pr.yaml](workflows/pr.yaml)** as an idempotent sticky PR comment (`marocchino/sticky-pull-request-comment`) so *every* PR — Renovate, `update-packages`, or human — automatically gets runtime closure diffs without coupling PR creation to Nix evaluation.
3. **Keep only `update-packages`** for `nix-update` FOD hash updates, delegating git/PR lifecycle to `peter-evans/create-pull-request` authenticated via `actions/create-github-app-token`.

---

## P1: Resilience & State Integrity

### 1. Make OCI publishing atomic (`push digest` → `sign & attest` → `promote :main`)
- **Problem:** In [workflows/_publish.yaml](workflows/_publish.yaml), `push-multiarch` immediately pushes `:main` (carrying `dev.nix-containers.drv.<arch>` annotations) *before* `cosign sign` and `actions/attest*` run. If Sigstore/Fulcio OIDC or GitHub's attestation API has a transient failure:
  1. `:main` is already live in GHCR unsigned/unattested.
  2. Subsequent [workflows/ci.yaml](workflows/ci.yaml) runs see matching `dev.nix-containers.drv.<arch>` annotations on `:main` via `ci-matrix` and **permanently skip** the container unless manually re-run with `force: true`.
- **Recommendation:** Have [../nix/modules/scripts/push-multiarch.nu](../nix/modules/scripts/push-multiarch.nu) push the multi-arch index **by digest only** (e.g., via `regctl index create` against the registry or a temporary tag) first, run `cosign sign` and `actions/attest*` against `repo@sha256:...`, and promote mutable tags (`:main`, semver tags, `extraTags`) in a final step only after signing and attestation succeed.

### 2. Distinguish `404` from transient `429`/`5xx`/auth errors in `ci-matrix`
- **Problem:** In [../nix/modules/scripts/ci-matrix.nu](../nix/modules/scripts/ci-matrix.nu), `remote-annotations` treats *any* non-zero `regctl manifest get` exit code as `{}` (missing image), firing unbounded `par-each` requests across the entire catalog. As the container count grows, a GHCR `429 Too Many Requests` or transient `5xx` silently marks unaffected containers as "changed" and triggers unnecessary multi-arch rebuilds/republishes.
- **Recommendation:**
  - Treat only `MANIFEST_UNKNOWN` / `NAME_UNKNOWN` (`404`) as a new container.
  - Add bounded concurrency (`par-each --threads 8`) and exponential backoff retries on transient registry errors, failing fast if GHCR remains unreachable.

### 3. Isolate per-package failures in `update-packages`
- **Problem:** [../nix/modules/scripts/update-packages.nu](../nix/modules/scripts/update-packages.nu) runs `nix-update` sequentially with hardcoded `--use-github-releases` and aborts on the first error, putting all updates into a single `chore/update-packages` PR:
  1. One rate-limited or broken upstream blocks updates for *every* other custom package.
  2. Packages hosted on GitLab/Codeberg/PyPI/Crates or using plain Git tags instead of GitHub Releases fail `--use-github-releases`.
  3. One failing container build in a combined PR blocks merging healthy updates.
- **Recommendation:**
  - Allow per-package `nix-update` flags via container metadata (defaulting to GitHub releases only when applicable, or letting `nix-update` auto-detect).
  - Catch failures per package: revert dirty files for any package whose update or `nix build` fails, record the error in `$GITHUB_STEP_SUMMARY` / PR body, and continue updating healthy packages (or fan out per-package `chore/update-<pkg>` PRs once the catalog grows).

### 4. Add `timeout-minutes` and matrix concurrency guardrails
- **Problem:** No job in `.github/workflows/` sets `timeout-minutes`, inheriting GitHub's **360-minute (6-hour)** default. A hung container test or stalled Nix build ties up runners (especially scarce `ubuntu-24.04-arm` runners) for hours. Additionally, GitHub caps `strategy.matrix` at 256 jobs, and a `nixpkgs` bump changes `drvPath` for *every* container simultaneously.
- **Recommendation:**
  - Set explicit `timeout-minutes` on every job (e.g., `15` for `test`, `45` for `_build.yaml`, `15` for `_publish.yaml` `push`, `30` for update jobs).
  - Add a reasonable `max-parallel` cap on `build` / `publish` matrices if GHCR or ARM runner contention appears during `flake.lock` bumps.

---

## P2: Zero-Toil Update Automation

### 5. Replace `GITHUB_TOKEN` with a repo-scoped GitHub App in `open-update-pr`
- **Problem:** [actions/open-update-pr/action.yml](actions/open-update-pr/action.yml) defaults to `GITHUB_TOKEN` (`github-actions[bot]`), which causes two recurring friction points:
  1. **Silent `synchronize` suppression:** When an open `chore/update-flake-lock` PR already exists and next week's cron runs `git push --force origin "$BRANCH"` + `gh pr edit`, GitHub **suppresses `pull_request` (`synchronize`) events** for pushes authenticated with `GITHUB_TOKEN`, leaving [workflows/pr.yaml](workflows/pr.yaml) un-triggered on updated PRs.
  2. Requires loosening repository-wide `GITHUB_TOKEN` PR permissions and hits first-time-contributor approval gates on fresh repos.
- **Recommendation:** Mint a short-lived installation token with `actions/create-github-app-token` (scoped strictly to `contents: write` and `pull-requests: write` on this repo) and pass it to both `actions/checkout` and `open-update-pr`.

### 6. Enable guarded auto-merge for routine updates
- **Problem:** Weekly `flake.lock`, custom package, and Dependabot PRs still require manual review/click-to-merge even when `nix flake check`, multi-arch `container-structure-test`, `restricted` Pod Security checks, `dive --ci`, and vulnerability scans all pass.
- **Recommendation:** Once backed by a GitHub App token and branch rulesets requiring [workflows/pr.yaml](workflows/pr.yaml) checks, have `open-update-pr` (and a lightweight Dependabot auto-merge step for minor/patch Action bumps) run `gh pr merge --auto --squash` when changes contain no high/critical fixable CVEs.

### 7. Stagger scheduled workflows off `00:00 UTC` Monday
- **Problem:** [workflows/update-flake.yaml](workflows/update-flake.yaml) and [workflows/update-packages.yaml](workflows/update-packages.yaml) both run at `0 0 * * 1` (Monday 00:00 UTC — Peak GitHub Actions queue congestion) alongside weekly [dependabot.yml](dependabot.yml). Running both update workflows simultaneously guarantees one PR must rebase/re-run after the other merges.
- **Recommendation:** Stagger schedules to off-peak minutes (e.g., `update-flake.yaml` at `23 3 * * 1`, `update-packages.yaml` at `23 5 * * 1` after `flake.lock` has auto-merged).

---

## P3: DRY & Workflow Simplification

### 8. Deduplicate `update-flake.yaml` and `update-packages.yaml`
- **Problem:** [workflows/update-flake.yaml](workflows/update-flake.yaml) and [workflows/update-packages.yaml](workflows/update-packages.yaml) are ~90% identical: same permissions, runner, checkout + `zizmor` ignore comment, `setup-nix`, manual `if git diff --quiet <paths>` output plumbing, and `open-update-pr` call (passing `paths` a second time).
- **Recommendation:**
  - Move `nix fmt`, `nix run .#update-readme`, and the `git status --porcelain -- "${paths[@]}"` no-op check **inside** [actions/open-update-pr/action.yml](actions/open-update-pr/action.yml) (returning early if clean, and guaranteeing auto-updates never fail `treefmt` or `readme-catalog` checks).
  - Optionally extract a `_update.yaml` reusable workflow so each caller is ~15 lines declaring only its schedule, update command, branch, and title.

### 9. Move inline workflow Bash into tested Nushell scripts
- **Problem:** Several workflows still embed non-trivial Bash glue that duplicates logic and cannot be formatted/linted by `nufmt` or tested locally via `nix run`:
  - [workflows/_build.yaml](workflows/_build.yaml) (`L51-L59`) manually fetches `origin/main` and creates `/tmp/base` git worktrees — duplicating the `git worktree add --detach` pattern in [actions/open-update-pr/action.yml](actions/open-update-pr/action.yml).
  - [workflows/_publish.yaml](workflows/_publish.yaml) (`L94-L100`) loops over `artifacts/*.tar.gz` in Bash to construct `linux/<arch>=...` CLI flags.
  - [actions/test-and-discover/action.yml](actions/test-and-discover/action.yml) (`L44-L49`) evaluates `nix eval --json .#lib.ci` in Bash and builds `EXTRA_ARGS` arrays before calling `ci-matrix`.
- **Recommendation:**
  - Let `ci-matrix` evaluate `.#lib.ci` itself when `--ci-json` is omitted.
  - Let `inspect-image` accept `--base-ref origin/main` and manage/clean up its own temporary git worktree (`try ... finally`).
  - Let `push-multiarch` accept `--artifacts-dir artifacts` directly.
  - Extract shared Nushell helpers (`linux-system` mapping, `$GITHUB_OUTPUT` / `$GITHUB_STEP_SUMMARY` writers, temporary worktrees) into a shared module imported by scripts in `nix/modules/scripts/`.

### 10. Compute image tags in Nix instead of `docker/metadata-action`
- **Problem:** Image tag logic is split across two ecosystems: `nix/modules/containers.nix` computes `version` (`imageTag`) and `extraTags`, [workflows/_publish.yaml](workflows/_publish.yaml) invokes `docker/metadata-action` to derive semver tags (`{{version}}`, `{{major}}.{{minor}}`, `{{major}}`, `main`), and `push-multiarch.nu` merges both lists back together.
- **Recommendation:** Compute the complete tag list directly in `flake.lib.ci` (or `push-multiarch.nu`), removing `docker/metadata-action` as a third-party dependency and making tag derivation 100% inspectable locally via `nix eval .#lib.ci`.

### 11. Clean up dead `inputs.ref` plumbing and avoid redundant Nix evaluation in `push`
- **Problem:**
  - [workflows/_build.yaml](workflows/_build.yaml) and [workflows/_publish.yaml](workflows/_publish.yaml) still define and thread `inputs.ref` into three `actions/checkout` steps, even though no caller passes `ref` anymore.
  - In [workflows/_publish.yaml](workflows/_publish.yaml), the `push` job runs `actions/checkout` + `setup-nix` + `nix run .#push-multiarch` **once per changed container**, reinstalling Nix and re-evaluating the flake N times just to invoke `regctl`.
- **Recommendation:**
  - Remove unused `inputs.ref` from `_build.yaml` and `_publish.yaml`.
  - Centralize `actions/checkout` + `setup-nix` inside a single composite action (with optional inputs like `persist-credentials`) so Dependabot SHA updates touch one file instead of five.

---

## P4: Supply Chain, Security & Registry Hygiene

### 12. Fix multi-arch SBOM attestation dropping `arm64` SBOMs
- **Problem:** [workflows/_publish.yaml](workflows/_publish.yaml) (`L98-L99`, `L117-L123`) collects `SBOM_FILES=(artifacts/*.spdx.json)` and passes only `${SBOM_FILES[0]}` (`amd64.spdx.json`) to `actions/attest`, discarding `arm64.spdx.json` while attesting the multi-arch index digest. Any architecture-specific store paths on `aarch64-linux` are omitted from the attested SBOM.
- **Recommendation:** Have `push-multiarch` output per-platform manifest digests so `_publish.yaml` attests each architecture's SPDX SBOM against its corresponding platform manifest digest (or merges/attests per-platform subjects).

### 13. Enforce CVE gates, cache the Grype DB, and scan published `:main` images on a schedule
- **Problem:**
  - [../nix/modules/scripts/scan-image.nu](../nix/modules/scripts/scan-image.nu) runs `grype` without `--fail-on`, so newly introduced critical CVEs never fail PR builds or block merges.
  - Every container × arch matrix job downloads the Grype vulnerability DB from scratch.
  - Because `ci-matrix` skips containers whose Nix `drvPath` hasn't changed, newly disclosed CVEs affecting already-published `:main` images go undetected between `flake.lock` updates.
- **Recommendation:**
  - Add `--fail-on high` (with `--only-fixed` or a repo `.grype.yaml` ignore list for triaged false positives) and cache Grype's DB across matrix jobs.
  - Add a lightweight scheduled workflow (or step before `update-flake`) that scans published `:main` SBOMs/manifests against the latest Grype DB and opens an issue or triggers rebuilds when fixed CVEs appear.

### 14. Add GHCR untagged package version retention
- **Problem:** Weekly updates across many containers publish multi-arch manifests, Cosign signatures, and SLSA/SPDX referrers. Over time, superseded untagged manifests accumulate in GHCR.
- **Recommendation:** Add a scheduled retention job (or GitHub package retention policy) that prunes old untagged OCI manifests not referenced by any active semver/`:main` tag while preserving OCI referrers (`.sig` / attestations) for tagged digests.
