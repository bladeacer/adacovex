# CI/CD workflows, summaries, and release bundling

This page covers the GitHub Actions workflows, the Markdown summaries and loud failures, the release version bundling, floating tags, and the consumer manifest prerequisites. The composite action, its inputs and outputs, and result caching are on [the CI/CD home page](ci-cd.md).

## Workflows

- **`.github/workflows/ci.yml`** -- three jobs on push to `main` and pull
  requests:
  - `self-assessment` -- build + prove + assess at `--standard=all` (so the
    DO-178C, ISO 26262, and IEC 62304 badges/reports are all emitted and
    gated), with the Platinum / 100% docstrings / test-count / 100% proof
    thresholds.
  - `adacovex-tests` -- build + native test suite (`run-tests`, `assess: false`).
  - `coverage-gate` (push only) -- runs the coverage gate, comparing
    docstring coverage between the latest two release tags (a maintainer
    step; see the [developer guide](../contributing/developer-guide.md)).
- **`.github/workflows/pr-check.yml`** -- runs `--coverage-delta` against
  `pull_request.base.sha` to fail PRs that drop docstring coverage.
- **`.github/workflows/release.yml`** -- on a `v*` tag, builds the release
  binary, runs GNATprove, validates the `--standard=all` self-assessment, and
  publishes the GitHub Release (see [Release bundling](#release-bundling)).

### Markdown summaries and loud failures

Every CI run leaves a **Markdown summary at the bottom of the job page**
(`$GITHUB_STEP_SUMMARY`):

- The composite action's assessment step writes an `## adacovex assessment`
  table. The table shows target, bundled version, compliance label, SPARK
  level, tests, and coverage. It also writes the full raw output.
- An `if: always()` **Write run summary** step appends a run-overview table.
  The table shows version, target, standard, DAL, and job result.
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
- Badge and SBOM artifacts are uploaded even when the step failed
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

**Better debugging output contract.** `ci.yml` now has `timeout-minutes`,
`concurrency.cancel-in-progress`, `fetch-tags: true`, and `actions/cache` for
both toolchain and result-cache. After these brittleness fixes, every failure
leaves three things without a re-run:

1. The `::error`/`::notice` annotations at the top of the job page.
2. The `## adacovex assessment` Markdown table in `GITHUB_STEP_SUMMARY`.
3. The `adacovex-assessment` artifact (full untruncated `adacovex.out` +
   `adacovex-metrics.json` when `emit-metrics` is set).

When the gate is flaky, start from the artifact, not a local repro.

### Release version bundling

The release workflow builds the binary from the `vX. Y. Z` tag. It **bundles that version into the binary**.

The action's build step sets `ADACOVEX_VERSION` (from `github.ref_name`). It regenerates `src/adacovex_version_info.ads` before `alr build`. The shipped `adacovex --version` reports exactly the tag.

The download step of the published action verifies this with `adacovex
--version` after unpacking the release bundle. Maintainers reproduce the
release locally with `make release VERSION=x.y.z` (see the
[developer guide](../contributing/developer-guide.md)); a normal source build
reads the version from `alire-dev.toml` instead.

### PR coverage gate

Gate every pull request so docstring coverage does not regress against the
base branch. This is exactly what `--coverage-delta` was built for:

```yaml
# .github/workflows/pr-check.yml
on:
  pull_request:
jobs:
  coverage-delta:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - uses: bladeacer/adacovex@v1
        with:
          target: .
          standard: all
          coverage-delta: ${{ github.event.pull_request.base.sha }}
```

The action exits non-zero when coverage drops, failing the check. This
workflow ships in the repo at `.github/workflows/pr-check.yml`.

The release version bundling, the changelog listing, the floating tags, and
the consumer-manifest prerequisites are on [Release bundling, tags, and
consumer manifests](ci-cd-release.md).
