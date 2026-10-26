# CI Cache Improvements Plan

**Status**: Findings + decisions. Clarifying questions answered; no code changes yet.

**Date**: 2026-10-26
**Branch**: `better-ci-caching`

### Decisions (from user, 2026-10-26)

| Question | Decision |
|----------|----------|
| gnatprove cache scope | Composite action — all consumers get it via the existing `cache` input |
| PR self-assessment | Keep self-assessment on PRs; share cache with post-merge main run (do NOT move to main-only) |
| Result-cache key | Yes — content-addressed key across PR and main, replacing per-run `run_id` |
| Cross-branch cache sharing | Yes — caches shared across branches |
| Docs build in CI | CI only uses the committed spec; no docs build in CI (Python venv/Sphinx cache is not a current win) |

---

## What exists today

Three caches are already in place, and all three are content-addressed, which is the correct safety property — a restored cache entry is either an exact hit or absent, never a partial match that could mask a regression.

| Cache | Where | Key | What it saves |
|-------|-------|-----|---------------|
| Alire toolchain | `setup-alire` `cache: true` in action.yml + every workflow job that uses it | Toolchain version (`gnat_native=16.1.0 gprbuild`) | GNAT compiler + gprbuild download/build |
| adacovex result cache | `result-cache: true` on `uses: ./` (composite action) | `adacovex-result-<target>-<os>-<run_id>` with `restore-keys` prefix fallback | adacovex's own on-disk cache (`<cache>/`) — content-addressed per-artifact SHA-256 blobs for scan/proof/test/manifest results |
| gnatprove session store | `actions/cache` on `obj/gnatprove` in ci.yml `self-assessment` + release.yml `release` | `gnatprove-session-<os>-<proof-input-hash>` | gnatprove's incremental session store; skips re-proving unchanged units |

The result cache and session store are the two that remove solver cost. The result cache serves a file only when byte-for-byte unchanged; the session store skips re-proving units whose inputs did not change. Both refuse to mask a regression: the result cache drops any stored summary whose Total row reports unproved VCs, and the session key is content-addressed on sources excluding the two generated bundle specs (`adacovex-docs_template.ads`, `adacovex-dashboard_template.ads`).

**References**: `action.yml` (inputs `cache`, `result-cache`, the `adacovex-state` step, the restore/save steps); `ci.yml` `self-assessment` job (proof-hash step + session-store cache); `release.yml` `release` job (same proof-hash + session-store); `docs/usage/ci-cd-action.md` §Result caching; `docs/contributing/architecture-pipeline.md` §Caching; `docs/contributing/perf/prove-timing.md` (prove warm/cold timings).

---

## Finding 1: gnatprove itself is not cached in CI

### What happens today

On every CI run that does `prove: true` (ci.yml `self-assessment`, release.yml `release`), the action:

1. Installs Alire via `setup-alire` with `toolchain: 'gnat_native=16.1.0 gprbuild'` — this caches the **compiler**, not gnatprove. `alr toolchain` only accepts compilers and build tools; gnatprove is not a toolchain component.
2. The `prove` subcommand then resolves gnatprove at runtime: per-project manifest (`alire-dev.toml`, which the ci.yml self-assessment swaps in via `cp alire-dev.toml alire.toml`), then `$PATH`, then cached toolchain under `<data>/toolchain/`, then download as last resort.

So **gnatprove is fetched fresh on every CI run that proves**. The dev manifest pins `gnatprove = "^16.1.0"`, and `setup-alire`'s `cache: true` caches the Alire *crate index and downloaded crates*, but the action's `setup-alire` step only runs when `build == 'true' || prove == 'true'`, and the cached crate downloads are scoped to the Alire home directory (`~/.alire` / `ALIRE_HOME`), which is **not** persisted by any `actions/cache` step in the current workflows.

This means each CI run pays:
- Alire crate index fetch (cached by `setup-alire`'s own cache, which is scoped to the toolchain version — so this part is OK within a given runner image lifetime, but the index cache is not shared across branch/PR boundaries explicitly)
- GNAT compiler download/build (cached by `setup-alire` — good)
- **gnatprove binary download/build** — NOT cached across runs by any explicit step; depends on whether `setup-alire`'s underlying cache hits (which it may, since it caches `~/.alire` including downloaded crates, but this is implicit and not under adacovex's control)

### Why self-assessment is still 1+ minutes

Even with the session store cache hit (which skips re-proving unchanged units), the cold path is solver-bound. From `docs/contributing/perf/prove-timing.md`:

- Prove warm (cache short-circuit): 62.9 ms ± 5.9 ms (1.63.0 phase representative)
- Prove cold (result cache + session wiped): 79.4 s ± 2.7 s / 1054 VCs
- Prove cold clone (fresh tree, no cache, no session, no gnatprove.out): 80.8 s ± 2.7 s

A CI runner is cold for the first run on a given commit. With the session store cached from a previous run on the same commit, the solver still runs on any changed units; on an unchanged tree the session-store hit makes prove fast, but the **runner itself** is a fresh environment for each job (GitHub Actions runners are ephemeral), so the session-store `actions/cache` restore is what carries state across runs — and it is keyed on the proof-input hash, so it only hits when the same sources are re-proved.

The 1+ minute self-assessment is: `just build` (~600 ms warm, more cold) + `adacovex prove` (cold ≈ 79 s on first run, fast on session hit) + assessment pipeline (~48-77 ms) + gate checks. The dominant cost is the cold prove.

### What could be cached

1. **gnatprove binary/toolchain as an explicit cache step.** The Alire toolchain cache from `setup-alire` may already cache the downloaded gnatprove crate under `~/.alire`, but:
   - This is implicit (not an adacovex-controlled `actions/cache` step)
   - It is scoped to the toolchain version string; changing `gnat-version` invalidates it
   - It is not separately restorable/saveable from the action's perspective
   
   An explicit `actions/cache` on the Alire home directory (`~/.alire` or `$ALIRE_HOME`) keyed on `gnat-version` + a hash of `alire-dev.toml`'s `[[depends-on]]` for gnatprove would make gnatprove fetch a cache hit across CI runs on the same toolchain. This is the biggest single win for the prove path in CI.

2. **The `alr` binary itself.** `setup-alire` installs alire; on a fresh runner this is a download each time. `setup-alire`'s own caching may cover this, but it's worth confirming.

3. **The Alire crate index (`~/.alire/index/`)** is likely already covered by `setup-alire`'s cache, but the scope/restore behavior across PR and main should be verified.

**Decision**: Treat the gnatprove fetch as a primary CI caching target. Wire an explicit `actions/cache` for the Alire home directory into the composite action, controlled by the existing `cache` input, so all action consumers get it automatically. The cache key is `gnat-version` + a hash of the dev-manifest's gnatprove dependency line. This is scoped to the composite action, not adacovex's own workflows only.

---

## Finding 2: The result-cache key is per-run, so PR→main overlap wastes work

### What happens today

The composite action's result-cache key is:

```
adacovex-result-<target>-<os>-<github.run_id>
```

with `restore-keys`:

```
adacovex-result-<target>-<os>-
```

`github.run_id` is unique per workflow run. So:

- Every run gets a fresh primary key that will never hit from a previous save.
- The `restore-keys` prefix fallback finds the most recent cache for that target+os, regardless of run. This is a "best effort restore of the latest cache" — useful, but it restores *whatever is latest*, not "the cache for this exact commit/state."
- The save uses the unique `run_id` key, so each run saves a new cache entry. Over time this accumulates cache entries (one per run), and GitHub Actions cache has retention limits (7-day idle eviction for free tier, branch-scoped retention).

### The PR→main overlap problem

`ci.yml` triggers on **both** `push: branches: [main]` **and** `pull_request`. So:

- **PR opened/updated**: `ci.yml` runs (self-assessment + all gates) AND `pr-check.yml` runs (coverage-delta + complexity). Two workflow files, both on the PR.
- **PR merges to main**: `ci.yml` runs again on `push: main`. Same self-assessment job, nearly identical work to the PR's self-assessment run — but the PR run's result-cache save (keyed to the PR run's `run_id`) is NOT reachable by the main run's restore, because the main run has a different `run_id` and the prefix fallback picks up whatever was saved most recently (which might be the PR run, or might be an older main run — non-deterministic from the project's perspective).

This means: the self-assessment that ran on the PR does **not** reliably make the main-run self-assessment faster, even though they assess the same tree at the same SHA (the merge commit). The session store (`gnatprove-session-*`) is keyed on the proof-input hash, so it DOES carry over — but only if the PR run saved it and the main run restores it. Because both use `actions/cache` with the same key format, the main run's restore can pick up the PR run's session store if the PR ran first and the cache save completed. This is a best-effort carry-over, not a guarantee.

### What could be better

1. **Share the result cache across PR and main for the same tree state.** The current per-run key makes this impossible by construction. A content-addressed key (like the proof-input hash, or a hash of the target tree's relevant sources) would let a PR run and the subsequent main run for the same state share one cache entry. The safety property still holds: content-addressed means a restored entry is either exact or absent.

   Trade-off: a content-addressed key means the cache is shared by *any* run on the same tree state, across branches. This is the same model the local `adacovex prove` result cache uses (SHA-256 of inputs → cache key). It is safe by construction. The current per-run key was chosen so a stale restore "can never mask a regression" — but a content-addressed key has the same property (exact match or miss), so the safety concern is already addressed by the key scheme, not by the per-run uniqueness.

2. **Branch-scoped cache retention.** GitHub Actions caches are scoped to the branch by default (a PR's cache is not available to main, and vice versa, depending on repository settings). For adacovex's own repo this is fine to relax — the repo is small and the caches are content-addressed. Making caches available across branches (or using a shared scope) would let the PR's session-store + result-cache carry over to the main run.

   Trade-off: cross-branch cache sharing can be a security consideration for repos with untrusted PRs, but adacovex is a single-maintainer project and the caches are content-addressed (no executable code is restored from cache that the run doesn't already trust — the cache holds scan/proof results and gnatprove session state, all derived from source).

3. **Deduplicate the PR + main self-assessment.** The self-assessment job runs on both `pull_request` and `push: main`. After a PR merge, the main push runs the same assessment again. Options:
   - Run self-assessment only on `push: main` (not on PRs), and run a lighter PR gate (coverage-delta + the cheap static gates). This is a workflow-design change, not a cache change — but it directly addresses "the same CI is repeated and not cached right before PR merge and after PR merge lands in main."
   - Or: keep self-assessment on PRs but make the main run a no-op when the tree is identical to the merged PR's tree. This is harder to do reliably (commit SHAs differ for the merge commit vs the PR head).

**Decision**: Keep self-assessment on PRs (option a). Reviewers see the full assessment result on the PR. The win comes from making the PR run's cache carry over to the post-merge main run via the content-addressed key + cross-branch cache sharing — so the main run's self-assessment hits the same cache the PR run populated, rather than re-doing the work.

---

## Finding 3: Each part of the pipeline could be cached separately (modular caching)

The AGENTS.md pipeline order is:

```
0. Parse CLI args
0a. Early-exit modes
1. Determine ANSI color
2. (prove mode) Run GNATprove
3. Scan source files
4. Apply docstring patches
5. Compute doc metrics
6. Parse GNATprove output
7. Parse test results
8. Assess DAL compliance
9. Render ANSI summary
10. Emit SVG badges
11. Emit Markdown reports
12. Emit automatic SBOM
13. Start HTTP server
14. Set exit code
```

Today the adacovex result cache already caches per-step: scan results, proof summaries, test summaries, manifest graphs, tool probes, registry metadata — each under its own content-addressed key (`scan:`, `prove:`, `proveout:`, `provesarif:`, `tests:`, `hlr:`, `llr:`, `tools-`, `graph-`, etc., per `adacovex-cache.ads`).

So the **local** tool already does modular per-part caching. The CI gap is that this cache is saved/restored with a per-run key that doesn't share across PR→main.

### Per-part cache heat analysis

| Pipeline part | Current cache | CI cache situation | Cacheability |
|---------------|---------------|--------------------|--------------|
| Scan (step 3) | `scan:` blobs, content-addressed per file | Saved/restored with per-run key | High — a file changed in one part of the tree doesn't invalidate unrelated files' scan results. A PR touching one package reuses the rest. |
| Proof (step 2+6) | `prove:`, `proveout:`, `provesarif:` + session store | Session store is content-addressed on proof inputs (good). Result cache is per-run key. | High — the session store already skips unchanged units. The per-run result-cache key is the gap. |
| Test parse (step 7) | `tests:` blobs | Per-run key | High — test results change only when test code or test outcomes change. |
| Manifest/graph (SBOM) | `graph-` + `tools-` + registry meta | Per-run key; registry meta has its own 7-day TTL cache outside the result cache | Medium — dependency graphs change when manifests change; tool probes when tools change. Both are already content-addressed. |
| DAL assessment (step 8) | Derived from proof + scan + tests — not independently cached | n/a (derived) | Not a separate cacheable artifact; depends on the above. |
| SVG/Markdown/SBOM emit (steps 10-12) | Output files (committed or artifact-uploaded) | Not cached as inputs; regenerated each run | Low value — these are outputs, not inputs. Regenerating them is cheap compared to proof. |
| Dashboard serve (step 13) | In-memory | n/a in CI (CI doesn't serve) | n/a |

The modular caching already exists in the tool. The CI improvement is primarily about **cache key scope and sharing**, not about adding new per-part caches.

---

## Finding 4: What is and isn't worth caching

### Worth caching (high value, safe)

1. **gnatprove binary/install** — the biggest single cost on the prove path. Explicit `actions/cache` on the Alire home directory (or the gnatprove install path within it), keyed on `gnat-version` + hash of the dev-manifest gnatprove dependency. This is safe: gnatprove is a pinned versioned tool; caching its installed binary across runs is exactly what local `just prove` does implicitly (the tool is installed once and reused).

2. **gnatprove session store** — already cached, already content-addressed. The improvement here is making the cache **shareable across PR and main** (cross-branch cache scope, or a content-addressed key that the PR run and main run both hit).

3. **adacovex result cache** — already cached, already content-addressed. Same improvement: share across PR and main via a content-addressed key rather than per-run `run_id`.

4. **Alire crate index + downloaded crates** — likely already cached implicitly by `setup-alire`, but making it explicit and keyed on the manifest shape would make it predictable. This covers gnatprove, gnatdoc_bin, gnatformat_bin from `alire-dev.toml`.

### Worth caching (medium value, already partially done)

5. **`alr` binary** — `setup-alire` installs it; confirm it's cached. Low additional value if `setup-alire`'s cache already covers it.

6. **Python venv / Sphinx / docs build artifacts** — NOT currently cached in CI, and NOT currently built in CI (the bundled manual is committed as `src/adacovex-docs_template.ads`; CI doesn't run `just book`). The `coverage-gate` job runs `python3 tools/tasks.py coverage-gate` which needs the built binary but not Sphinx. So docs build caching is a developer-ergonomics concern, not a CI concern — but if CI ever builds the docs, caching the Sphinx `_build` and the Python venv would matter. **Decision**: CI only uses the committed spec; no docs build in CI. The Python venv + Sphinx cache is not a current win and is not a priority. If a CI job ever builds the Sphinx manual, cache the venv + `_build` at that point. Document the assumption in the plan.

### Not worth caching (low value or wrong layer)

7. **Build products (`bin/adacovex`, `bin/test_runner`, `obj/`)** — the `build: true` path runs `alr build` which already does incremental compilation via the Alire build cache (`alire/build_hash_inputs`, `alire/settings.toml`). The GNAT compiler's own dependency tracking handles incremental recompilation. Caching `obj/` explicitly would conflict with the GNAT build cache and is not needed. The `alr build` no-op on unchanged tree is the right mechanism here.

8. **Test results as cached artifacts** — test results are outputs, not reusable inputs. The test *execution* isn't cacheable (you must run the tests to know they pass), but the test *binary* is built incrementally by `alr build`. Caching the binary across runs doesn't help because `alr build` already does that.

9. **SBOM output (`sbom.json`)** — an output, regenerated each run. Not cacheable as an input. The dependency graph it's built from IS cached (content-addressed), which is the right layer.

---

## Finding 5: The self-assessment vs. adacovex-tests duplication

`ci.yml` has two jobs that both build adacovex:

- **`self-assessment`**: `build: true`, `prove: true`, `assess: true` (full assessment at `--standard=all` with all gates)
- **`adacovex-tests`**: `build: true`, `run-tests: true`, `assess: false` (build + native tests only, no proof, no assessment)

Both build adacovex from source. Both use `cache: true` and `result-cache: true`. They run in parallel on the same commit.

The `adacovex-tests` job is somewhat redundant with `self-assessment` when `self-assessment` also runs on the same trigger — `self-assessment` with `build: true` + `prove: true` already builds adacovex, and the native tests are part of the self-assessment's gate (`require-tests: 2040`). But the separation may be intentional: `adacovex-tests` is the "fast feedback" job (build + tests, no prover), and `self-assessment` is the "full gate" job (with proof). On a PR, you get fast test feedback from `adacovex-tests` and full assessment from `self-assessment` in parallel.

The duplication is: both download/build the same GNAT toolchain (cached, so OK) and both build adacovex (incremental, so the second build is a no-op if they share the Alire build state — but they don't share state because they're separate jobs on separate runners). This is a parallelism-vs-cache trade-off: two parallel jobs each paying a build cost, vs. one job doing both. The build is ~600 ms warm, so the duplication cost is small relative to the proof cost.

**Decision**: Keep the `adacovex-tests` job separate from `self-assessment`. The split is intentional — `adacovex-tests` is the fast-feedback path (build + native tests, no prover) and `self-assessment` is the full gate (with proof). They run in parallel on the same commit. The gnatprove cache improvement (#1) doesn't affect `adacovex-tests` (it doesn't prove). Sharing the built `bin/` between the two jobs via artifact upload/download would make them sequential and is not worth it given the build is ~600 ms warm relative to the ~79 s cold prove. Leave the two-job parallel structure as-is.

---

## Finding 6: `pr-check.yml` and `ci.yml` both trigger on PRs

This is the most concrete "repeated CI" issue:

- **`pr-check.yml`**: triggers on `pull_request`. Runs `complexity-gate` + `coverage-delta` (which uses the action with `coverage-delta: ${{ github.event.pull_request.base.sha }}`).
- **`ci.yml`**: triggers on `pull_request` AND `push: main`. On a PR, runs `self-assessment` + `adacovex-tests` + all the gate jobs + `consumer-run-tests` (which skips on PRs since 1.64.0).

So a PR triggers **two workflow files**, and `ci.yml` alone runs 9 jobs (self-assessment, adacovex-tests, no-spark-off, complexity-gate, action-parity, docs-coverage, version-consistency, consumer-run-tests [skipped], coverage-gate [push only, so skipped on PR]).

The `complexity-gate` runs in BOTH `pr-check.yml` AND `ci.yml` on a PR — identical work, twice. This is a clear duplication: the complexity gate is a cheap static check (it builds adacovex then runs `adacovex complexity`), and running it in two workflow files on the same PR is wasted.

Similarly, `coverage-delta` runs in `pr-check.yml`, and `ci.yml` on a PR runs `self-assessment` which does a full assessment (not a coverage-delta, but still assesses the same tree).

---

## Summary of recommendations (for later implementation, not done yet)

These are findings with decisions recorded; no code changes yet.

### High priority (addresses the 1+ minute self-assessment and the PR→main overlap)

1. **Cache gnatprove explicitly in the composite action.** Add an `actions/cache` step for the Alire home directory (`~/.alire` / `$ALIRE_HOME`), keyed on `gnat-version` + a hash of the dev-manifest's gnatprove dependency line, controlled by the existing `cache` input. This makes gnatprove fetch a cache hit across CI runs on the same toolchain — the single biggest win for the prove path in CI. Because it is in the composite action, all action consumers get it automatically; adacovex's own workflows that prove but bypass the action (none currently, but future ones) would need their own step.
   - The `alr` binary and the Alire crate index are already covered implicitly by `setup-alire`'s own cache; the explicit step makes gnatprove's install predictable and scoped correctly. Verify what `setup-alire`'s cache already covers before assuming the explicit step is the only thing needed.

2. **Replace the per-run result-cache key with a content-addressed key.** The current key `adacovex-result-<target>-<os>-<run_id>` (with `restore-keys` prefix fallback) makes every run save a new entry and only best-effort-restores the latest. Replace it with a content-addressed key — a hash of the target tree's relevant sources, same shape as the proof-input hash already computed in ci.yml/release.yml. The PR run and the post-merge main run for the same tree state then share one cache entry. Safety is preserved by construction (exact match or miss).
   - The session store already uses a content-addressed key (`gnatprove-session-<os>-<proof-input-hash>`); aligning the result-cache key to the same model makes the two caches behave consistently.

3. **Deduplicate the PR triggers.** A PR currently triggers both `ci.yml` and `pr-check.yml`, and `complexity-gate` runs in both — identical work twice. Options (pick one):
   - Remove `complexity-gate` from `ci.yml` when the trigger is `pull_request` (keep it on `push: main`), since `pr-check.yml` already runs it on PRs. Minimal change; keeps self-assessment on PRs.
   - Or: remove `pull_request` from `ci.yml` entirely and keep it only on `push: main`; move any PR-specific gates to `pr-check.yml`. Bigger change; makes PRs run one workflow file.
   - The `consumer-run-tests` job already skips on PRs (1.64.0 F3); the `coverage-gate` job already skips on PRs (`if: github.event_name == 'push'`). The remaining duplication on PRs is: `complexity-gate` (both files), and the self-assessment running on both the PR and the post-merge main push (addressed by #2 above — the main run hits the PR's cache).

### Medium priority (refinement)

4. **Verify `setup-alire`'s implicit cache covers gnatprove and the Alire index.** Before shipping the explicit gnatprove cache, confirm what `setup-alire`'s `cache: true` already covers. If it already caches the gnatprove crate under `~/.alire`, the explicit step may be partly redundant — but making it explicit and keyed on the manifest gives predictability and correct scoping. Do this verification as part of implementing #1, not before.

5. **Cross-branch cache scope.** Enable cache sharing across branches for adacovex's own repo (repository setting, not a workflow-file change). This is what makes #2's content-addressed key actually carry the PR run's cache over to the main run. For a single-maintainer repo with content-addressed caches this is low-risk. Needed for the PR→main carry-over to be reliable.

6. **Document the docs-build cache assumption.** CI does not build the Sphinx manual (the committed `src/adacovex-docs_template.ads` is used). Python venv + Sphinx caching is therefore not a current win. If a CI job ever builds the docs, cache the venv + `_build/` at that point. The `coverage-gate` job needs the built binary but not Sphinx.

### Low priority (not currently valuable)

7. Caching `bin/` or `obj/` build products — `alr build` incremental compilation already handles this via the Alire build cache (`alire/build_hash_inputs`, `alire/settings.toml`) and the GNAT compiler's dependency tracking. An explicit cache would conflict, not help.

8. Caching test execution — must run the tests to know they pass; only the test binary build is incremental (handled by `alr build`).

---

## Questions already answered (see Decisions table above)

All five clarifying questions are answered in the Decisions table at the top of this document. One additional question (the `adacovex-tests` job split) is answered inline in Finding 5. No open questions remain before implementation can begin.

---


## Files reads for this investigation

- `.github/workflows/ci.yml`
- `.github/workflows/pr-check.yml`
- `.github/workflows/release.yml`
- `action.yml` (composite action)
- `docs/usage/ci-cd.md`
- `docs/usage/ci-cd-action.md`
- `docs/usage/ci-cd-workflows.md`
- `docs/contributing/architecture-pipeline.md` §Caching
- `docs/contributing/perf/prove-timing.md` (warm/cold timings)
- `docs/proof/16.1.0-ledger.md` (VC counts)
- `src/core/adacovex-cache.ads` (cache schema, namespaces, key model)
- `tools/run.py` (how `just prove` / `just run-self` invoke the binary)
- `tools/tasks.py` (gate definitions, `CHECK_GATES` order)
- `alire.toml`, `alire-dev.toml` (dependency shape — what needs caching)
- `docs/test_result.md` (current test count: 2040/2040)
- `docs/changelogs/adacovex-1.64.0.md` (F3: consumer-run-tests PR skip — the most recent caching-adjacent change)
