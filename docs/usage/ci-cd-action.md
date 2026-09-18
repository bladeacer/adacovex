# The composite action

This page details the composite action at `./action.yml`: what it does, its
inputs and outputs, and its result caching. The quick start, the GitLab
mapping, other CI systems, and the parity gate are on the [CI/CD home
page](ci-cd.md). The workflow files, Markdown summaries, release bundling,
and floating tags are on [CI/CD workflows, summaries, and release
bundling](ci-cd-workflows.md).

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
| `dal` | `C` | DO-178C DAL level to assess (A-E); also the shared rigour tier |
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

## See also

- [CI/CD](ci-cd.md) -- the CI/CD home page.
- [CI/CD workflows, summaries, and release bundling](ci-cd-workflows.md) --
  the workflow files, Markdown summaries, and release bundling.
