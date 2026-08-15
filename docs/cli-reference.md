# adacovex CLI Reference

## Usage

```
adacovex [options]
adacovex sbom [--format=cyclonedx-json|spdx-json] [--out=PATH]
```

## Flags

| Flag | Default | Mode | Description |
|------|---------|------|-------------|
| `--target=PATH` | `.` (CWD) | both | Target project root directory |
| `--manifest=PATH` | auto-detected | both | Override project manifest path |
| `--dal=LEVEL` | `C` | both | Target DAL level (A-E) |
| `--serve` | off | both | Start HTTP dashboard server |
| `--port=N` | `8080` | serve | Dashboard server port |
| `--emit-svg=PATH` | `<target>/docs/badges` | both | Output directory for SVG badges |
| `--no-svg` | off | both | Suppress SVG badge output |
| `--emit-markdown=PATH` | off | both | Output directory for Markdown reports |
| `--skip-dir=NAME` | `demo,deps,examples` | relaxed | Directory name to skip (repeatable) |
| `--relaxed` | off | both | Disable strict mode (skip dirs, no patches) |
| `--compare-base=REF` | off | both | Differential mode vs a git base ref |
| `--coverage-delta=REF` | off | both | Docstring-coverage gate vs a git base ref |
| `--cache` | on | both | Enable on-disk result caching |
| `--no-cache` | off | both | Disable result caching (always re-scan/re-parse/re-prove) |
| `--cache-dir=PATH` | `~/.adacovex/cache/<ver>/<schema>` | both | Cache directory for analysis results |
| `--cache-max=N` | `4096` | both | Max cache entries before oldest-first eviction |
| `--require-spark=LVL` | off | both | Fail loudly (exit 1) if SPARK level < LVL (Stone..Platinum) |
| `--require-docstrings=PCT` | off | both | Fail loudly if docstring coverage < PCT% (0-100) |
| `--require-tests=N` | off | both | Fail loudly if passing test count < N |
| `--require-proof=PCT` | off | both | Fail loudly if proved-VC coverage < PCT% (0-100) |
| `--verbose` | off | both | Verbose diagnostics |
| `--help` | - | both | Print usage and exit |

## Flag details

### `--target=PATH`

Project to analyze. Relative paths are resolved against the current working
directory to an absolute path. Determines the root directory for source
scanning, manifest detection, SVG badge output, and patch file resolution.
Default: current working directory.

### `--manifest=PATH`

Override the project manifest file. Auto-detected from
`<target>/alire-dev.toml` or `<target>/alire.toml` (dev first). The manifest
path is shown in stderr output and used by `adacovex sbom` to resolve the root
project metadata for the dependency graph.

### `--dal=LEVEL`

Target DO-178C DAL level: `A`, `B`, `C`, `D`, or `E` (case-insensitive).
Determines the minimum SPARK proof level required and the specific DAL criteria
checked. Higher levels (A, B) require stricter proofs. See
[DAL levels](api-docs/adacovex-dal-levels.md).

### `--serve`

After scanning and assessment, start the built-in HTTP/1.1 web dashboard on
`--port` (default `8080`):

- `GET /` -- HTML dashboard with coverage, proof, test, and compliance cards
- `GET /api/metrics` -- JSON object with key metrics
- `GET /badge/spark.svg`, `GET /badge/tests.svg`, `GET /badge/do178c.svg` -- SVG badges

The server blocks (does not return to the shell) until interrupted.

### `--port=N`

HTTP server port when `--serve` is used. Must be a valid `Positive` integer.
Only relevant with `--serve`.

### `--emit-svg=PATH`

Write SVG badges to a directory. Default `<target>/docs/badges`
(project-scoped). Creates four files:

- `spark.svg` -- SPARK assurance level (Stone through Platinum)
- `tests.svg` -- test pass/fail count
- `do178c.svg` -- DO-178C DAL status (Achieved / Unmet)
- `docs.svg` -- docstring coverage percentage

`--no-svg` overrides and disables SVG output entirely.

### `--no-svg`

Suppress all SVG badge output. Overrides `--emit-svg` if both are given.

### `--emit-markdown=PATH`

Write compliance reports to a directory. Creates two files:

- `VERIFICATION.md` -- full verification report with all metrics
- `TRACE.md` -- HLR traceability matrix (source-to-requirement mapping)

### `--skip-dir=NAME`

Add a directory name to the scanner's skip list (repeatable). Directories whose
simple name matches an entry are not recursed into during source scanning.
Only effective in relaxed mode; in strict mode (default) the skip list is
always empty.

### `--relaxed`

Disable strict mode. Enables the skip list (default `demo,deps,examples` plus
any `--skip-dir` entries) and does NOT apply `.adacovex/patches/`. See
[Strict vs relaxed mode](#strict-vs-relaxed-mode).

### `--compare-base=REF`

Differential mode: assess a git base revision in a temporary worktree
(`/tmp/adacovex-diff-<pid>`) and print a side-by-side comparison against the
current tree (packages, subprograms, docstring %, HLR traced, orphan tags,
SPARK level, VCs proved, tests, DAL status). The `--target` directory must be a
git repository with `git` on `PATH`.

Exit `0` only if there are no regressions AND the current DAL is Achieved;
`1` otherwise. Artifacts the base does not commit (`gnatprove.out`, a
test-result summary) report `N/A` and are not compared.

### `--coverage-delta=REF`

Lightweight docstring-coverage gate for PR-style CI checks. Scans sources +
patches + computes docstring metrics on both a git base ref and the current
tree (no GNATprove/tests/DAL, so it works when the base does not commit build
artifacts), prints a compact coverage table plus a machine-parseable
`coverage_delta:` line, and cleans up the worktree.

Exit `0` if current docstring coverage is `>=` the base (or the base has no
sources); `1` if coverage regressed. Mutually exclusive with `--compare-base`.
`make release` runs the same gate against the last release tag (e.g.
`--coverage-delta=v1.1.0`) and aborts if docstring coverage regressed between
releases.

### CI threshold gates (`--require-*`)

The four `--require-*` flags add explicit minimum-bar checks on top of the DAL
criteria. They are off by default; when set, the assessment fails loudly
(exit code `1`, with an explicit `CI GATE:` reason printed to the report) if the
target does not meet the required level:

```bash
adacovex --target=. --require-spark=Platinum --require-docstrings=100 \
         --require-tests=372 --require-proof=100
```

- `require-spark` compares the honest assessed SPARK level (Stone..Platinum).
- `require-docstrings` and `require-proof` take a percentage (0-100).
- `require-tests` takes a count of passing tests.

CI that pins a gnatprove version (manifest or global `adacovex.toml` pin)
should set these to the values that version actually achieves -- a stricter
prover can legitimately leave more VCs unproved, so gate on the results of the
prover you pin.

### Result caching (`--cache` / `--no-cache` / `--cache-dir` / `--cache-max`)

adacovex persists parsed analysis results on disk so unchanged inputs are not
re-scanned / re-parsed / re-proved. Source scans, GNATprove summaries, and test
summaries are each keyed by `"scan:" | "prove:" | "tests:" + SHA-256` of the
artifact they were derived from, so re-parsing a byte-identical artifact yields
a cache hit regardless of the target directory or command line.

- **Schema namespace**: the default cache root is
  `~/.adacovex/cache/<version>/<Cache_Schema>`. `Cache_Schema` (in
  `src/core/adacovex-cache.ads`) is bumped whenever the serialized layout of a
  cached record or the scanner/parser semantics change, so blobs written by an
  incompatible build are never served as if valid.
- **Eviction**: `Put_Cached` evicts oldest-first by modification time when more
  than `--cache-max` entries (default `4096`) accumulate. `Eviction_Count`
  tracks removals and is reported in the ANSI cache line.
- **Overflow safety**: `Serialize` returns an empty blob when a package would
  exceed `Max_Cache_Blob`; callers skip storing it and `Deserialize` rejects
  empty/oversized input, so truncated data can never be served as a hit.
- **`--target` normalization**: `--target` is normalized (`.`/`..` collapsed to
  a canonical absolute path) before scanning, keeping the `File_Path` values in
  cached `Package_Info` consistent across invocations that spell the same
  directory differently.
- **CI**: the GitHub action persists `~/.adacovex/cache` between workflow runs
  (`result-cache` input, default true).

`--no-cache` bypasses it entirely (useful when artifacts change without their
content hash changing, or to measure rescan cost) and `--cache-dir` relocates
it. The ANSI report shows a
`result cache: X hit(s), Y miss(es), Z evicted` line per run.

### `--verbose`

Print pipeline step diagnostics to stderr.

### `--help`

Print all options, defaults, and examples to stdout, then exit. No scanning or
assessment is performed.

## Strict vs relaxed mode

| Aspect | Strict (default) | Relaxed (`--relaxed`) |
|--------|-----------------|----------------------|
| Directory exclusions | `.git`, `obj`, `tests`, `config`, `.adacovex` only | Same + `demo,deps,examples` + `--skip-dir` additions |
| Vendored code | Scanned and counted | Skipped |
| Patch files | Applied from `.adacovex/patches/` | Not applied |
| Use case | Full compliance audit | Quick assessment of production code |

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success (DAL achieved, all checks pass) |
| `1` | Compliance failure (DAL unmet, tests failing, a `--require-*` CI gate unmet, etc.) |

## NO_COLOR support

adacovex respects the `NO_COLOR` environment variable. If `NO_COLOR` is set,
ANSI color codes are suppressed in terminal output. Color is enabled by default.

## The `sbom` subcommand

`adacovex sbom` resolves the target project's dependency graph from its Alire
manifest (`alire.toml` / `alire-dev.toml`), the solved-crate list in
`alire/alire.lock`, and the root `.gpr` `with` clauses, then writes a
proof-aware software bill of materials in CycloneDX 1.5 JSON or SPDX 2.3 JSON.

- **Usage**: `adacovex sbom [--format=FMT] [--out=PATH]`.
- **Default output**: `<target>/sbom.json` for `cyclonedx-json`,
  `<target>/sbom.spdx.json` for `spdx-json`. The containing directory is
  created automatically.
- **Properties**: only the root component -- the project adacovex actually
  assessed -- carries `adacovex:proof_level` (`Stone`..`Platinum`, the honest
  assessed level) and `adacovex:dal_target` (`DAL-A`..`DAL-D`; omitted for
  `DAL-E`). Dependency components report `adacovex:proof_level = "Not proved"`
  (adacovex only proves the target itself, never third-party dependencies).
  Encoded as `attributionTexts` in SPDX.
- **Determinism**: the `metadata.timestamp` / `creationInfo.created` field
  honors the `SOURCE_DATE_EPOCH` environment variable (reproducible-builds
  convention); when set to a Unix epoch second count the timestamp is derived
  from it in UTC via pure integer math, so SBOM output is byte-for-byte
  deterministic across runs and machines. To tie it to a specific git commit,
  run `export SOURCE_DATE_EPOCH=$(git -C <target> log -1 --format=%ct)` before
  adacovex. The bundled `make` targets (`run-self`, `run-ada-crdt`, `prove`,
  `release`, and Ada_CRDT's `prove`/`badges`) already set it from the target's
  git `HEAD` commit time.
- **Exclusivity**: mutually exclusive with `--compare-base` and
  `--coverage-delta`. `sbom` scans sources, parses proof/test results, and
  assesses DAL first, so the emitted properties reflect the real assessment
  state.
- **Exit code**: `0` when the SBOM was written, `1` otherwise. If the target
  has no Alire manifest the SBOM cannot be generated (the GitHub Action reports
  this as a warning without failing the job).

Both formats validate against the official
[CycloneDX 1.5](https://github.com/CycloneDX/specification) and
[SPDX 2.3](https://spdx.dev) JSON schemas (see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)).

## Examples

```bash
# Self-assessment (strict mode, 100% docs required)
adacovex --target=.

# Assess a CRDT library at DAL-C in relaxed mode
adacovex --target=../Ada_CRDT --dal=C --relaxed

# DAL-A assessment (requires Gold SPARK)
adacovex --target=. --dal=A

# Without SVG output
adacovex --target=../Ada_CRDT --no-svg

# Custom skip dirs
adacovex --target=../Ada_CRDT --relaxed --skip-dir=vendor

# With Markdown reports
adacovex --target=. --emit-markdown=docs/compliance

# Web dashboard on custom port
adacovex --target=. --serve --port=9090

# Differential assessment vs a git base revision
adacovex --target=. --compare-base=HEAD

# Proof-aware SBOM (CycloneDX 1.5 JSON)
adacovex sbom --format=cyclonedx-json --target=. --dal=C

# Proof-aware SBOM (SPDX 2.3 JSON) at a custom path
adacovex sbom --format=spdx-json --out=docs/compliance/sbom.spdx.json
```
