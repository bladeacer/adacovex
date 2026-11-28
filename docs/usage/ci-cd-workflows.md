# CI/CD workflows, summaries, and release bundling

This page covers the GitHub Actions workflows, the Markdown summaries and loud failures, the release version bundling, floating tags, and the consumer manifest prerequisites. The composite action, its inputs and outputs, and result caching are on [the CI/CD home page](ci-cd.md).

## Workflows

Three workflow files share the work, and each one runs only what its trigger
makes meaningful. `ci-scenario.md` in the repository root is the worksheet
that records the decision for every trigger.

- **`.github/workflows/ci.yml`** -- push to `main`, every pull request, and a
  manual dispatch. Four jobs and one summary:
  - `quality` -- the pure-Python gates in one job, one step each: ASCII, the
    CSS 4px rule, the `SPARK_Mode (Off)` rule, the changelog format, the
    action/CLI/docs parity, documentation coverage, diagnostics coverage, the
    test layout, test portability, CLI surface parity, the docs tree, markdown
    links, user documentation, the paragraph splitter, the [tldr](../glossary/ste100/identifiers.md#technical-name-tldr) structure, the
    tools unit tests, the version source, and version consistency. It then
    verifies that the crate description and `requirements.txt` are in sync
    without writing (`CHECK=1`).
  - `build-test` -- `alr build` plus the native suite, then the complexity
    and file-size gate.
  - `self-assessment` -- build + prove + assess at `--standard=all` (so the
    [DO-178C](../glossary/ste100/tooling-terms.md#technical-name-do-178c), [ISO 26262](../glossary/ste100/tooling-terms.md#technical-name-iso-26262), and [IEC 62304](../glossary/ste100/tooling-terms.md#technical-name-iec-62304) badges/reports are all emitted and
    gated), with the Gold / 100% docstrings / test-count / 100% proof
    thresholds and the statement-coverage floor.
  - `coverage-delta` (pull requests and manual dispatch) -- `--coverage-delta`
    against `pull_request.base.sha` (a manual dispatch falls back to `main`),
    so a change that drops docstring coverage fails.
  - `summary` -- writes the Markdown summary table and exits 1 when any job
    failed.

  A manual dispatch can skip any job with its `run_*` boolean input
  (`run_quality`, `run_build_test`, `run_self_assessment`,
  `run_coverage_delta`). A push or a pull request always runs every job,
  because the inputs are empty on those events.
- **`.github/workflows/version-bump.yml`** -- push to `main` that changes
  `alire-dev.toml`. It compares the `version` line with the parent commit and
  runs the macOS and Windows native suite only when the version moved. A
  dev-only dependency edit in that file does not start the matrix.
- **`.github/workflows/release.yml`** -- on a `v*` tag. It first checks that
  the tagged commit is on `main` (a tag off `main` stops every later job).
  It then re-runs the full `quality` gate set on the tagged tree (the release
  does not trust a green `main` that may have drifted) and the `coverage-delta`
  job against the previous release tag, so a release cannot ship a docstring
  coverage regression. In parallel it runs the `platform-build` matrix, the
  composite action regression (see [Project
  configuration](ci-cd-action.md#project-configuration)), and the end-to-end
  suites (one small fixture proves first so the pinned prover is in the
  [toolkit](../glossary/ste100/tooling-terms.md#technical-name-toolkit) cache). The publish job waits for all of them, builds the
  release binary, runs [GNATprove](../glossary/ste100/identifiers.md#technical-name-gnatprove), validates the `--standard=all` self-assessment, and publishes the
  GitHub Release (see [Release bundling](#release-bundling)); it is fully
  gated, so a failed run never creates or updates the release, and a re-pushed
  tag cancels the in-flight run (`cancel-in-progress`).

Every gate job runs as plain Python (`python3 tools/tasks.py <gate>`), the
same recipe `just <gate>` runs locally. The Ubuntu runner images ship
`python3`, so no `make` or `just` has to exist on the runner.

### Markdown summaries and loud failures

Every CI run leaves a **Markdown summary at the bottom of the job page**
(`$GITHUB_STEP_SUMMARY`):

- The composite action's assessment step writes an `## adacovex assessment`
  table. The table shows target, bundled version, compliance label, [SPARK](../glossary/ste100/ada-terms.md#technical-name-spark)
  level, tests, and coverage. It also writes the full raw output.
- An `if: always()` **Write run summary** step appends a run-overview table.
  The table shows version, target, standard, [DAL](../glossary/ste100/proof-terms.md#technical-name-design-assurance-level-dal), and job result.
- Each workflow adds a **`summary` job** (`if: always()`, `needs:` all other
  jobs) that aggregates every job result into one table at the bottom of the
  run.

Diagnostics are layered so a failure is debuggable from the Actions UI without
re-running locally:

- The assessment output is folded into a GitHub **log group**
  (``::group::``). The step result stays visible. The detail stays one click
  away.
- `WARNING` lines are re-surfaced as `::notice::` annotations.
- An **`adacovex-assessment` artifact** (uploaded `if: always()`) carries the
  full, untruncated assessment output. It also carries the `--emit-metrics`
  JSON export when `emit-metrics` is set. A flaky or unmet gate never requires
  a re-run to reproduce.
- Badge and [SBOM](../glossary/ste100/tooling-terms.md#technical-name-software-bill-of-materials-sbom) artifacts are uploaded even when the step failed
  (`if: always()`). Partially produced reports stay inspectable.

Threshold failures **fail loudly** at every layer:

1. Unmet `--require-*` gates make the adacovex binary exit non-zero.
2. The assessment step re-surfaces each `CI GATE:` line as a GitHub
   `::error::` annotation. The annotation is visible at the top of the job
   page, not just in the log. The step marks the summary table **FAILED** with
   the unmet gates.
3. The action's `Write run summary` step (runs on failure too) reports the
   failed job result.
4. The workflow `summary` job exits `1` when any dependency failed. The whole
   run is red even if the failing job was retried. An `if: always()` cleanup
   step does not mask this.

### Debugging guide: what to do when you see ...

| Output | Meaning | Action |
|--------|---------|--------|
| `CI GATE: SPARK level X below required Y (--require-spark)` | Proven VCs or `gnatprove` version drift below the pinned gate | Check the `gnatprove` pin or the `gnat-version` input. Re-run `adacovex prove`. Update `--require-spark` only if the prover legitimately tightened |
| `CI GATE: docstring coverage N% below required M% (--require-docstrings)` | Missing `--` docstrings or patches | Run `adacovex --verbose` to list undocumented subprogs. Add patches under `.adacovex/patches/` |
| `CI GATE: proved-VC coverage N% below required M% (--require-proof)` | Some VCs unproved/justified | Inspect `gnatprove.out`. Add contracts or fix `SPARK_Mode` |
| `Warning: N source file(s) skipped: line exceeds Max_Line` | A physical line > `Max_Line` (262144 on 64-bit) | Split the declaration. DAL becomes `Unmet` by design (`docs/architecture.md#overflow-contract`) |
| `result cache: X hit(s), Y miss(es), Z evicted` | Cache stats per run | `Z>0` means `--cache-max` evicted the oldest entries. Increase `--cache-max`. Pass `--no-cache` to force a full rescan |
| `Unknown option --foo (did you mean --bar?)` | Typo | Use `adacovex --help` or `adacovex help <topic>` |
| `::notice::WARNING ...` annotation | Non-fatal warning surfaced from `adacovex.out` | Download the `adacovex-assessment` artifact for the full log. Warnings do not fail the gate. They indicate missing tests or proof |
| `complexity-check` failed | File or function exceeds caps (`--max-file-loc`/`--max-file-pct`/`--max-fn-complexity`) | Run `adacovex complexity --help`. Split god objects or functions |
| `::error::cannot move refs/tags/...` | The server refused a floating-tag update at release time | The annotation names the ref. Check `Settings > Rules > Protected tags`, or a release that owns the tag. Remove the rule, then re-run the release workflow |

**Better debugging output contract.** `ci.yml` now has `timeout-minutes`,
`concurrency.cancel-in-progress`, `fetch-tags: true`, and `actions/cache` for
both toolkit and [result-cache](../glossary/ste100/tooling-terms.md#technical-name-result-cache). After these brittleness fixes, every failure
leaves three things without a re-run:

1. The `::error`/`::notice` annotations at the top of the job page.
2. The `## adacovex assessment` Markdown table in `GITHUB_STEP_SUMMARY`.
3. The `adacovex-assessment` artifact (full untruncated `adacovex.out` +
   `adacovex-metrics.json` when `emit-metrics` is set).

When the gate is flaky, start from the artifact, not a local repro.

### Caching

Four caches shorten a run. Every one is content-addressed, so a restored
cache can never mask a regression. Each keeps the GitHub default eviction
window; none is pinned.

| Cache | Scope | Key |
|-------|-------|-----|
| Alire toolchain | `setup-alire` `cache: true` | Toolchain version |
| Alire home (gnatprove install) | `actions/cache` on `~/.alire` / `$ALIRE_HOME` in the composite action | `gnat-version` + hash of the target's dev-manifest `[[depends-on]]` section |
| adacovex result cache | `result-cache: true` on `uses: ./` | SHA-256 of the target tree's proof-relevant sources (content-addressed, branch-independent) |
| gnatprove session store | `actions/cache` on `obj/gnatprove` in ci.yml/release.yml | SHA-256 of the proof-relevant sources |

The [Alire](../glossary/ste100/identifiers.md#technical-name-alire) home cache is new in 1.65.0: it makes the gnatprove binary that
the `prove` [subcommand](../glossary/ste100/tooling-terms.md#technical-name-subcommand) fetches at run time a cache hit across CI runs on the
same [toolchain](../glossary/ste100/tooling-terms.md#technical-name-toolchain). gnatprove is not an `alr toolchain` component, so
`setup-alire`'s own cache (compiler + gprbuild) does not reliably cover it.
The step lives in the composite action, so every action consumer gets it
automatically; the existing `cache` input controls it. The cache key tracks
the target's dev-manifest `[[depends-on]]` pins (`gnatprove`, `gnatdoc_bin`,
`gnatformat_bin`), so a changed pin invalidates the cache and the same pins
reuse it.

The result cache and the session store are the two that remove the solver
cost. The result cache serves a file only when it is byte-for-byte unchanged.
The session store skips re-proving units whose inputs did not change.

The result-cache key is content-addressed on the target tree's
proof-relevant sources (a SHA-256 hash of every tracked `*.ads`, `*.adb`,
and `*.gpr`, excluding the two generated bundle specs) instead of the
per-run `github.run_id`. This is the same shape the session store already
uses, so the two caches behave consistently. Because the key is
content-addressed rather than per-run, the cache is branch-independent: a
pull-request run and the post-merge `main` run for the same tree state share
one cache entry, so the `main` self-assessment hits the cache the pull-request
run populated instead of re-proving everything from scratch.

A pull request's
cache entry is scoped to its merge ref, so a release on `main` does not read a
pull-request entry directly; the content-addressed key makes the worst case an
absent entry (a re-prove), never a stale hit. The safety property is preserved
by construction -- a content-addressed key is an exact match or absent, never
a partial match that could mask a regression.

The session-store key hashes the tracked `*.ads`, `*.adb`, and `*.gpr`
sources. It excludes the two generated bundle specs
(`adacovex-docs_template.ads`, `adacovex-dashboard_template.ads`). Those are
data-only string constants with no proof surface, so a docs or dashboard edit
does not invalidate a cached session.

This is the same exclusion the prove
result cache uses (`Is_Proof_Input` in `adacovex-prove.adb`). The hand-written
`adacovex-docs_template.adb` body stays in the key. It is real code.

The result-cache key step writes its hash to a GitHub Actions output
variable, which must be one line. When the target is a plain directory with
no git history, the step falls back to a timestamp-based nonce, and the
step now normalises that value before writing it. The previous version could
emit a value that spanned more than one line on an unmanaged target, which
`GITHUB_OUTPUT` rejects and aborts the job. The fix lets the action still
cache an unmanaged target -- with a per-run key instead of a
content-addressed one -- instead of failing before it reaches the restore
step.

The false-pass guard holds across all four caches. The prove result cache
refuses to serve a stored summary whose Total row reports unproved [VCs](../glossary/ste100/proof-terms.md#technical-name-verification-condition-vc), so a
degraded run (one killed mid-session, for example) is re-proved rather than
replayed. Content-addressed keys make a stale restore either an exact hit or
absent, never a partial match.

The bundled manual is not built in CI, so it needs no cache there. Sphinx and
the uv/pip wheel cache are local developer concerns (`just book`,
`docs-venv`).

The complexity gate runs inside `build-test` for both events. The old
`pr-check.yml` file no longer exists: `ci.yml` handles both pull requests and
`main` pushes, so a pull request runs each gate once instead of twice.

### Release version bundling

The release workflow builds the binary from the `vX. Y. Z` tag. It **bundles that version into the binary**.

The action's build step sets `ADACOVEX_VERSION` (from `github.ref_name`). It regenerates `src/adacovex_version_info.ads` before `alr build`. The shipped `adacovex --version` reports exactly the tag.

The download step of the published action verifies this with `adacovex
--version` after unpacking the release bundle. Maintainers reproduce the
release locally with `VERSION=x.y.z just release` (see the
[developer guide](../contributing/developer-guide.md)); a normal source build
reads the version from `alire-dev.toml` instead.

### Coverage delta gate

Gate every pull request so docstring coverage does not regress against the
base branch, and gate the release the same way against the previous release
tag. This is exactly what `--coverage-delta` was built for. The `coverage-delta`
job in `ci.yml` runs it on every pull request (and on a manual dispatch, with
`main` as the base):

```yaml
# .github/workflows/ci.yml (the coverage-delta job)
  coverage-delta:
    if: (github.event_name == 'pull_request' || inputs.run_coverage_delta)
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - uses: bladeacer/adacovex@v1
        with:
          target: .
          coverage-delta: ${{ github.event.pull_request.base.sha || 'main' }}
```

The `coverage-delta` job in `release.yml` runs the same check against the
previous release tag (resolved from the tag list, falling back to `HEAD^` for
the first release) before the publish job runs. The action exits non-zero when
coverage drops, failing the check.

The release version bundling, the changelog listing, the floating tags, and
the consumer-manifest prerequisites are on [Release bundling, tags, and
consumer manifests](ci-cd-release.md).
