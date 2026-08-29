# adacovex CI/CD

## GitHub Actions

The composite action at `./action.yml` mirrors the base CLI. CI can drive every
assessment feature the same way the binary does.

### Quick start

```yaml
# .github/workflows/adacovex.yml
on:
  push:
    branches: [main]
  pull_request:

jobs:
  adacovex:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: bladeacer/adacovex@v1
        with:
          target: .
          standard: all          # DO-178C + ISO 26262 + IEC 62304
          require-spark: Platinum
          require-docstrings: 100
          require-tests: 1167
          run-tests: true
          generate-sbom: true
```

This job builds adacovex. It runs the target's native tests and the full
assessment. It gates on Platinum SPARK, 100% docstring coverage, and 900
passing tests. On failure, the job publishes `adacovex-assessment` artifacts
and Markdown summaries.

### PR coverage gate

Use `--coverage-delta` to fail PRs that drop docstring coverage:

```yaml
# .github/workflows/pr-coverage.yml
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
          coverage-delta: ${{ github.event.pull_request.base.sha }}
```

### Release workflow

Tag a release. The bundled workflow (`release.yml`) builds the binary and runs GNATprove. It validates the self-assessment. It publishes `adacovex-vX.

Y. Z.tar.gz` and the composite action bundle. Floating tags (`@latest`, `@v1`, `@v1.3`) always point at the newest release. Pin `@vX.

Y. Z` for reproducibility.

## GitLab CI

The same inputs map to GitLab CI variables:

```yaml
# .gitlab-ci.yml
adacovex:
  image: ubuntu:latest
  before_script:
    - apt-get update -qq && apt-get install -y -qq curl
    - curl -fsSL https://raw.githubusercontent.com/bladeacer/adacovex/main/install.sh | bash
  script:
    - adacovex --target=. --standard=all --dal=C --require-spark=Platinum --require-docstrings=100
  artifacts:
    when: always
    paths:
      - sbom.json
      - docs/badges/*.svg
```

If your runner already has Alire, replace the `install.sh` step with
`alr install covex gnatprove`.

## Other CI systems

The action is a pure composite of shell steps. It works on any runner that can
run `bash` and install Alire:

1. Install Alire + GNAT (`alr toolchain --install gnat_native`).
2. Download the release bundle or build from source.
3. Run `adacovex` with the same flags as the GitHub Action inputs.

The JSON API (`/api/metrics` when using `--serve`, or `--emit-metrics`) lets
you parse results in any language.

**Action/CLI/docs parity is a feature gate.** `ci.yml` runs
`make action-parity-check` (wired into `make check`). The build fails when the
action's inputs stop mirroring the base CLI option set. The build also fails
when the `### Inputs` table below drifts from `action.yml`. See
`tools/check-action-parity.py` for the mapping rules.

## Composite action (`./action.yml`)

The composite action installs Alire via
[`alire-project/setup-alire`](https://github.com/alire-project/setup-alire).
GNAT comes from `gnat-version` plus `gprbuild`. `gnatprove` is NOT an
`alr toolchain` component. The `prove` subcommand resolves it through the
target project's manifest, `$PATH`, cached toolchain, or download.

The action obtains the version-matched adacovex binary. It downloads the
release bundle by default. You can set `build: true` to build from source.

Optionally, the action runs GNATprove (`prove`) and the native tests
(`run-tests`). Then it runs the assessment. It generates a proof-aware SBOM
(`generate-sbom`, default `true`). It publishes a Markdown step summary,
machine-readable outputs, and SVG badge artifacts.

`run-tests` **builds the target's native test suite first**. In a consumer
workspace, the `build: true` step builds adacovex in a scratch checkout. It
leaves the target untouched.

The action runs `alr build` in the target root before executing
`test-command`. The target root is a subdirectory when `target` points at one.
In the self-assessment case, the build is an incremental no-op.

This design keeps `test-command: ./test_crdt`-style usage working in consumer
repositories such as Ada_CRDT's release workflow.

The action is version-matched to the adacovex binary. The release workflow bundles `adacovex-vX. Y. Z.tar.gz` for every `vX.

Y. Z` tag. The action downloads the binary for the tag it is referenced by. Reference it by a floating tag to always get the latest published release.

You can pin to an exact release for reproducibility:

```yaml
steps:
  - uses: actions/checkout@v7
  - uses: bladeacer/adacovex@v1
    with:
      target: .
      standard: all   # badges/reports for DO-178C + ISO 26262 + IEC 62304
```

### Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `target` | `.` | Target project root (relative to workspace root) |
| `dal` | `C` | DO-178C DAL level to assess (A-E); also the shared rigor tier |
| `standard` | `''` | Compliance standard: `do178c`, `iso26262`, `iec62304`, or `all` (badges/reports for every standard) |
| `asil` | `''` | ISO 26262 ASIL level (A-D, QM); sets the standard and tier |
| `class` | `''` | IEC 62304 safety class (A-C); sets the standard and tier |
| `gnat-version` | `16.1.0` | GNAT toolchain version to select via `alr` |
| `version` | `''` | adacovex version; defaults to the tag the action is referenced by |
| `build` | `false` | Build adacovex from source instead of downloading the version-matched binary |
| `prove` | `false` | Run GNATprove before assessing, for repos that don't commit `gnatprove.out` |
| `require-spark` | `''` | Minimum SPARK level (Stone..Platinum); CI threshold gate |
| `require-docstrings` | `''` | Minimum docstring coverage % (0-100); CI threshold gate |
| `require-tests` | `''` | Minimum passing test count; CI threshold gate |
| `require-proof` | `''` | Minimum proved-VC coverage % (0-100); CI threshold gate |
| `run-tests` | `false` | Build the target's native test suite and run it (requires `build: true`; the action runs `alr build` in the target root first) |
| `test-command` | `./bin/test_runner` | Command (relative to workspace root) that runs the target's test suite |
| `release-build` | `false` | Pass `--release` to `alr build` |
| `assess` | `true` | Run the assessment and publish outputs/badges (`false` for build/test-only jobs) |
| `compare-base` | `''` | Git ref to run `--compare-base` against (fails on regression) |
| `coverage-delta` | `''` | Git ref to run `--coverage-delta` against (fails if coverage dropped) |
| `emit-markdown` | `''` | Write `VERIFICATION.md` + `TRACE.md` into this directory |
| `emit-metrics` | `''` | Write a JSON export of assessment metrics + the dependency graph to this file |
| `generate-sbom` | `true` | Generate a proof-aware SBOM after the assessment and upload it |
| `sbom-format` | `cyclonedx-json` | SBOM format: `cyclonedx-json`, `spdx-json`, or `md` |
| `cache` | `true` | Cache Alire toolchain/deps with `actions/cache` |
| `result-cache` | `true` | Persist adacovex's on-disk result cache across runs |
| `manifest` | `''` | Override the target project manifest path |
| `no-svg` | `false` | Suppress SVG badge generation |
| `relaxed` | `false` | Disable strict mode (skip dirs, no patches) |
| `skip-dir` | `''` | Directory name to skip in relaxed mode (repeatable, comma-separated) |
| `verbose` | `false` | Verbose diagnostics on stderr |
| `no-cache` | `false` | Disable adacovex on-disk result caching |
| `cache-dir` | `''` | Override adacovex result cache directory |
| `cache-max` | `''` | Max adacovex result-cache entries before eviction |
| `prove-jobs` | `''` | GNATprove parallelism for the `prove` subcommand |
| `prove-level` | `''` | GNATprove proof effort 0-4 |
| `prove-timeout` | `''` | GNATprove per-check prover timeout in seconds |
| `prove-steps` | `''` | GNATprove max proof steps |
| `prove-memlimit` | `''` | GNATprove prover memory limit in MB |
| `prove-force` | `false` | Force full GNATprove reanalysis (`-f`) |
| `prove-no-loop-unrolling` | `false` | Disable GNATprove automatic loop unrolling |
| `prove-no-inlining` | `false` | Disable GNATprove contextual-analysis inlining |
| `prove-quiet` | `false` | Suppress GNATprove benign info messages (the default set) from prove output. Quiet is already the default for local runs; this is the explicit prove-mode form. `--verbose` wins |
| `prove-suppress-warnings` | `''` | Comma-separated GNATprove info tags to suppress from prove output (for example `unrolling-inlining,xyz`); a tag `S` suppresses blocks tagged `[info-S]` (or `[S]`). `--verbose` wins |

### Outputs

| Output | Description |
|--------|-------------|
| `dal-status` | `Achieved` or `Unmet` |
| `spark-level` | SPARK level detected (Stone..Platinum) |
| `test-count` | Number of passing tests |
| `coverage-pct` | Current docstring coverage (in `--coverage-delta` mode) |

### Result caching

The action restores `~/.adacovex/cache` before running adacovex. It saves the
cache when the job finishes (`result-cache`, default `true`).

Every entry is keyed by its artifact's SHA-256 content hash. Restoring a cache
from an earlier run or commit is always safe. Only files that are byte-for-byte
unchanged are served from it. The remaining files are rescanned and re-parsed
automatically.

## Workflows

- **`.github/workflows/ci.yml`** -- three jobs on push to `main` and pull
  requests:
  - `self-assessment` -- build + prove + assess at `--standard=all` (so the
    DO-178C, ISO 26262, and IEC 62304 badges/reports are all emitted and
    gated), with the Platinum / 100% docstrings / test-count / 100% proof
    thresholds.
  - `adacovex-tests` -- build + native test suite (`run-tests`, `assess: false`).
  - `coverage-gate` (push only) -- runs `make coverage-gate`, comparing
    docstring coverage between the latest two release tags.
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
| `CI GATE: SPARK level X below required Y (--require-spark)` | Proven VCs or `gnatprove` version drift below the pinned gate | Check the `gnatprove` pin in `alire-dev.toml` or the `gnat-version` input. Re-run `make prove`. Update `--require-spark` only if the prover legitimately tightened |
| `CI GATE: docstring coverage N% below required M% (--require-docstrings)` | Missing `--` docstrings or patches | Run `adacovex --verbose` to list undocumented subprogs. Add patches under `.adacovex/patches/` |
| `CI GATE: proved-VC coverage N% below required M% (--require-proof)` | Some VCs unproved/justified | Inspect `gnatprove.out`. Add contracts or fix `SPARK_Mode` |
| `Warning: N source file(s) skipped: line exceeds Max_Line` | A physical line > `Max_Line` (262144 on 64-bit) | Split the declaration. DAL becomes `Unmet` by design (`docs/architecture.md#overflow-contract`) |
| `result cache: X hit(s), Y miss(es), Z evicted` | Cache stats per run | `Z>0` means `--cache-max` evicted the oldest entries. Increase `--cache-max`. Pass `--no-cache` to force a full rescan |
| `Unknown option --foo (did you mean --bar?)` | Typo | Use `adacovex --help` or `adacovex help <topic>` |
| `::notice::WARNING ...` annotation | Non-fatal warning surfaced from `adacovex.out` | Download the `adacovex-assessment` artifact for the full log. Warnings do not fail the gate. They indicate missing tests or proof |
| `make complexity-check` failed | File or function exceeds caps (`--max-file-loc`/`--max-file-pct`/`--max-fn-complexity`) | Run `./bin/adacovex complexity --help`. Split god objects or functions |

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
--version` after unpacking the release bundle. Locally, `make release
VERSION=x.y.z` does the same. Normal `make build` reads the version from
`alire-dev.toml` instead.

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

## Release bundling

Every `vX. Y. Z` tag triggers `.github/workflows/release.yml`. The workflow calls the composite action with `build`, `release-build`, and `prove`.

It builds the release binary, runs GNATprove, and validates the self-assessment. Then it packages and publishes:

- `adacovex-vX.Y.Z.tar.gz` -- the version-matched binary (`adacovex` plus the
  `covex` alias). The action downloads this asset for the tag it is referenced
  by, so `@v1.9.0` runs adacovex `v1.9.0`.
- `adacovex-action-vX.Y.Z.tar.gz` -- a copy of the composite action itself for
  vendoring or air-gapped use.

Both bundles are attested with
[`actions/attest`](https://github.com/actions/attest)
on every tag. OIDC attestations appear under the release's attestations tab.
The release notes link the signed attestation via the action's
`attestation-url` output. They also link a *Git Changelog* compare link
(`compare/v1.9.0...v1.14.0`) and the human-readable changelogs.

**Changelog listing.** The `Create GitHub Release` step derives the changelog
list from the available `docs/changelogs/adacovex-*.md` entries. The entries
are between the previous release tag and the released version.

It resolves the previous three-component release tag
(`git tag --sort=-version:refname`, for example `v1.9.0` when releasing
`v1.14.0`). Then it lists every changelog whose version is strictly above the
previous release and at or below the released version. Releasing `v1.14.0`
after `v1.9.0` links the `1.10.0`..`1.14.0` changelogs in one release.

The list is emitted **newest-first** (version-sorted, not shell glob order).
The entries read `1.14.0` down to `1.10.0`.

The list is derived from the changelog files present in the tree, not from
tags. A version that was never released has no entry. A release that skips
versions still links every changelog in the range.

**The CI release binary is Linux x86-64 only for now.** The release workflow
runs on `ubuntu-latest`. It packages the Linux binary and the prebuilt
GNATprove toolchain bundle for that target. macOS, FreeBSD, Windows, and Linux
aarch64 build adacovex from source via Alire instead. See
[Platforms](platforms.md#release-binaries).

`make release VERSION=x.y.z` does the same locally. It builds `--release`,
generates proofs, validates DAL-C, and bundles `dist/`. Then it tags and
pushes to trigger the workflow. `make build` regenerates
`src/adacovex_version_info.ads` from `alire-dev.toml` (or `ADACOVEX_VERSION`)
before compiling. The bundled version is always the build's version.

## Floating tags

The release workflow force-pushes the floating tags `vMAJOR`, `vMAJOR. MINOR`, and `latest`. For example: `v1`, `v1.3`, and `latest` from `v1.3.0`. Reference `@latest` to always get the newest published release.

Use `@v1` or `@v1.3` for the latest release within a major or minor version. Pin an exact `@vX. Y. Z` for a fixed version.

Once the action is listed on the GitHub Actions marketplace, each `vX. Y. Z` tag auto-publishes that version.

## Consumer manifest prerequisites (avoid a broken CI)

adacovex's `prove` subcommand and the GitHub Action resolve `gnatprove`
through the *target project's* manifest. The pinned gnatprove crate is
deployed via `alr -n get gnatprove=<version>`. It is run directly, with no
`alr exec` over the whole workspace.

For the command to succeed in a clean checkout or on CI, the consumer's
manifests must follow two rules:

1. **`alire.toml` must be the clean publishing manifest.** It must contain no
   dev tooling (`gnatprove`, `gnatdoc_bin`, `gnatformat_bin`, `covex`). It must
   contain **no `[[pins]]`**. Alire reads this manifest when the action runs
   `alr build`. It must resolve with nothing but Alire + GNAT.
2. **`alire-dev.toml` must declare `covex` as a normal index dependency**
   (`covex = "*"`). It must never be pinned to a local path such as
   `covex = { path = "../adacovex" }`. A path pin resolves only on the machine
   that has the sibling checkout. In a consumer workspace or on CI, Alire
   fails the whole workspace load with a confusing error. This happens before
   adacovex or `alr` runs:

    ```
    ERROR: Failed to load alire.toml:
    ERROR:    pins:
    ERROR:    covex:
    ERROR:    Pin path is not a valid directory: /home/runner/work/<repo>/<repo>/../adacovex
    ```

If you see that, drop the `covex` path pin. Use `covex = "*"`. Strip the dev
deps and pins out of `alire.toml`. Keep them only in `alire-dev.toml`.

The Makefile pattern in many projects keeps the published `alire.toml` clean.
It swaps `alire-dev.toml` over `alire.toml` only for the duration of a
`prove`/`fmt`/`doc` target, then restores it. This gives local tooling the dev
deps.
