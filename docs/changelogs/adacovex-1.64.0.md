# adacovex 1.64.0

Date: _2026-10-25_

Version bumped 1.63.0 -> 1.64.0.

## Changes

### C1: SPARK Platinum requires a complete formal specification and full proof coverage

The SPARK-level classifier granted **Platinum** to any project that had at
least one proved functional contract, or that proved all of its flow, run-time,
and assertion checks but had no functional contracts to prove. That misread the
SPARK Platinum definition: Platinum is the highest level and it requires a
complete formal specification of *all* subprogram behaviour, so a project with
no functional contracts has nothing to prove at that level and is not Platinum.

It also treated a fully proved *summary* as a fully proved *program*. A project
that leaves subprograms outside the proof -- skipped units, or units gnatprove
never analysed -- still got Platinum because the summary rows look complete.

`Determine_SPARK_Level` now grants Platinum only when all of these hold:

- there is a functional-contract surface to prove (`Functional_Ct > 0`) and
  every functional contract is proved;
- the SPARK coverage report has been measured and shows full proof coverage:
  every subprogram it assesses is proved (`Subs_Proved = Subs_Total`).

The coverage evidence comes from the existing `spark-coverage` analysis
(`Spark_Coverage.Analyze`, folded into the summary by `Apply_To_Proof`), so the
level and the `--require-coverage` gate read the same numbers. An assessment
that never measures the coverage report never claims Platinum. Unproved VCs
still cap the level at **Silver**, and justified VCs still count neither proved
nor unproved and never downgrade it.

adacovex's own assessment moves from Platinum to **Gold**: all 1054 VCs are
proved, but its coverage report shows 120 of 612 assessed subprograms proved,
because the deliberate `SPARK_Mode (Off)` units stay outside the proof. The
honest-level wording in the architecture, SPARK-levels, proving, and proof
pages now says this plainly, so the SPARK-levels page, the architecture page,
the CLI reference, and the badge, dashboard, and SBOM labels all describe the
same Platinum bar.

## Fixes

### F1: SPARK level is Gold, not Platinum, when there are no functional contracts

A project with no functional contracts had nothing to prove at Platinum, but
the classifier previously promoted it to Platinum whenever all of its other
checks were proved. That over-labelled projects such as pure-flow or
pure-runtime libraries and made the badge, dashboard, and SBOM show Platinum
for code that had no formal subprogram specification at all. The classifier now
returns Gold for that shape (runtime + assertion proved, no functional
contracts), and the SPARK-levels and architecture pages describe Platinum as
requiring a complete formal specification of all subprogram behaviour.

### F2: SPARK level is Gold, not Platinum, without full proof coverage

The summary parser also tracked a per-unit "functional contract coverage" flag
that real `gnatprove.out` records never carry, so it stayed True on every
parsed report and could never stop a Platinum claim. The flag and its dead
`skipped;`-record parsing are gone. The Platinum gate now reads the SPARK
coverage report instead, and a project whose report shows subprograms outside
the proof is Gold however complete its proved rows look. A bare parse of
`gnatprove.out` reaches Gold at most, which is also what
`tools/update-proof-status.py` reports.

### F3: consumer-run-tests CI job skips on pull requests

The `consumer-run-tests` workflow job previously ran on pull requests, testing
the GitHub Action's consumer workspace compatibility against the dated upstream
code -- which does not make sense when verifying downstream changes being merged.
The job now has `if: github.event_name != 'pull_request'`, so it is skipped on
PRs and only runs on main branch pushes. This avoids spurious CI failures
while preserving the regression test for main-line development.

## Test Suite

- `parsers-gnatprove`: regression tests cover the full Platinum rule (every
  functional contract proved plus full proof coverage, including justified
  VCs), the unmeasured-coverage case (Gold, never Platinum), the
  partial-coverage case (Gold), the no-functional-contract Gold case, and the
  incomplete-runtime Silver case. The parse-level tests now assert Gold, since
  a summary file alone carries no coverage evidence, and the empty-summary
  cases assert Stone. The existing Platinum, Gold, Silver, Bronze, and Stone
  level tests remain.

## Proof Results

- gnatprove 16.1.0: SPARK Gold, 1054 VCs, 0 unproved, 0 justified, 120/612
  subprograms proved by the coverage report (see
  `docs/proof/16.1.0-ledger.md`). Platinum is not claimed: full proof coverage
  is not met.

## Traceability

- `parsers-gnatprove.Determine_SPARK_Level` -- the exact same rules the
  classifier, the badge, the dashboard, and the SBOM read from
  (`docs/contributing/architecture-verification.md`);
- `parsers-gnatprove.Parse_Prove_Out` -- the summary parser whose rows feed
  the classifier (`docs/api-docs/adacovex-parsers-gnatprove.md`);
- `spark-coverage.Analyze` -- the per-unit subprogram coverage the Platinum
  gate now requires (`docs/api-docs/adacovex-spark-coverage.md`);
- `spark-coverage.Apply_To_Proof` -- folds that rollup into the proof summary
  and re-derives the level.

## Changes

### C2: Cache gnatprove explicitly in the composite action

gnatprove is not an `alr toolchain` component, so `setup-alire`'s own cache
(compiler + gprbuild) did not reliably cache it across CI runs. Every CI run
that proved fetched gnatprove fresh, even when the toolchain pin had not
changed. The composite action now caches the Alire home directory
(`~/.alire` / `$ALIRE_HOME`) with `actions/cache`, keyed on `gnat-version`
plus a hash of the target's dev-manifest `[[depends-on]]` section
(`gnatprove`, `gnatdoc_bin`, `gnatformat_bin` pins from `alire-dev.toml`,
falling back to `alire.toml` when no dev manifest is present). The cache
covers the gnatprove binary, the Alire crate index, and the downloaded
dev-tool crates, and is controlled by the existing `cache` input so every
action consumer gets it automatically.

This is the single biggest win for the prove path in CI.

### C3: Content-addressed result-cache key shared across PR and main

The composite action's result-cache key was `adacovex-result-<target>-<os>-<run_id>`,
which made every run save a new cache entry and only best-effort-restore the
latest. The PR run's cache did not reliably carry over to the post-merge
main run for the same tree state, even though they assess the same commit.

The key is now content-addressed on the target tree's proof-relevant sources:
a SHA-256 hash of every tracked `*.ads`, `*.adb`, and `*.gpr` under the
target, excluding the two generated bundle specs (`adacovex-docs_template.ads`,
`adacovex-dashboard_template.ads`) which are data-only string constants with
no proof surface. This is the same shape the gnatprove session store already
uses, so the two caches now behave consistently. A PR run and the post-merge
main run for the same tree state share one cache entry, so the main
self-assessment hits the cache the PR run populated instead of re-proving
everything from scratch. The safety property is preserved by construction --
a content-addressed key is an exact match or absent, never a partial match
that could mask a regression.

### C4: Deduplicate the complexity gate on pull requests

`ci.yml` and `pr-check.yml` both triggered on `pull_request`, and both ran
the `complexity-gate` job -- identical work twice on every PR. The
`complexity-gate` job in `ci.yml` now runs only on `push: main`; `pr-check.yml`
still runs it on every pull request. The `summary` job in `ci.yml` still
lists `complexity-gate` in its `needs` and shows `skipped` for it on PRs.

## Fixes

### F4: Alire home cache key tracks dev-manifest dependency pins, not just gnat-version

The Alire home cache key hashes the target's `[[depends-on]]` section rather
than only the `gnatprove` version line, so a change to `gnatdoc_bin` or
`gnatformat_bin` (or any other dev-manifest tool) also invalidates the cache.
This keeps the cached tool installation consistent with the manifest the
`prove` step consults. When the target has no manifest declaring gnatprove,
the key collapses to `gnat-version` alone and the cache still shares
identical toolchains across runs.

### F5: Result-cache key falls back to a stable nonce when the target is not a git repository

The result-cache key is computed from `git ls-files` of the target tree, but
some consumers assess a plain directory that is not a git repository. The
computation now falls back to a stable nonce when git is absent or the target
has no tracked files, so the cache still works (just not content-addressed
across runs) for non-git targets.

The nonce is the GitHub Actions run identifier for the step, so the fallback
is deterministic per job and does not depend on wall-clock time. The previous
timestamp fallback was both non-stable across reruns and, because it could be
empty plus a second line, could produce a value that spans more than one line
when written to the GitHub Actions output variable, which the runner rejects.
The result-cache key step now normalises the value before writing it, so an
unmanaged target no longer aborts the job; the PR/main post-merge runs for
that target continue with independent per-run caches instead.

This matches the local tool's behaviour, which also works on plain directories.

## Test Suite

- No Ada test suite changes. The changes are confined to the composite action
  (`action.yml`) and the CI workflow files (`ci.yml`, `pr-check.yml`), plus
  the user documentation (`docs/usage/ci-cd-action.md`, `docs/usage/ci-cd-workflows.md`).
  The action-parity gate (`tools/check-action-parity.py`) and the docs-coverage
  gate (`tools/check-docs-coverage.py`) both run on the changed files.

## Proof Results

- gnatprove 16.1.0: SPARK Gold, 1054 VCs, 0 unproved, 0 justified, 120/612
  subprograms proved by the coverage report (unchanged from C1; see
  `docs/proof/16.1.0-ledger.md`). No Ada source changed, so the proof surface
  is identical.

## Traceability

- `action.yml` -- the composite action's new Alire home cache step
  (`alire-cache`), the new result-cache key computation (`proof-hash`), and
  the updated restore/save steps (`tools/check-action-parity.py` enforces the
  action/CLI/docs parity for the unchanged `cache` and `result-cache` inputs)
- `.github/workflows/ci.yml` -- `complexity-gate` now runs on `push: main`
  only (`pr-check.yml` runs it on pull requests)
- `docs/usage/ci-cd-action.md` -- the `### Result caching` section documents
  the new result-cache key, the Alire home cache, and the cross-branch sharing
- `docs/usage/ci-cd-workflows.md` -- the `### Caching` section documents all
  four caches and the complexity-gate deduplication

