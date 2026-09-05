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
          require-tests: 1235
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

**Action/CLI/docs parity is a feature gate.** CI runs the action-parity
check (`tools/check-action-parity.py`), which fails when the action's inputs
stop mirroring the base CLI option set, and also fails when the `### Inputs`
table below drifts from `action.yml`. See `tools/check-action-parity.py` for
the mapping rules (maintainers run the same check locally via
`make action-parity-check`; see the [developer guide](../contributing/developer-guide.md)).

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
| `prove-args` | `''` | Extra raw GNATprove flags passed through verbatim to the `prove` subcommand (`--args=...`, for example `--prover=cvc5 --timeout=5`); the value is space-split into gnatprove arguments |
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
