[![covex Alire crate badge](https://img.shields.io/endpoint?url=https://alire.ada.dev/badges/covex.json)](https://alire.ada.dev/crates/covex)
![SPARK](docs/badges/spark.svg)
![Tests](docs/badges/tests.svg)
![DO-178C](docs/badges/do178c.svg)
![docs](docs/badges/docs.svg)

# adacovex

**Zero-library-dependency Ada/SPARK CLI tool** for coverage analysis, proof verification,
test-result parsing, DO-178C DAL compliance assessment, and interactive dashboards.
gnatprove is the only declared (tool) dependency; no libraries beyond the GNAT runtime.

## Features

- **Source scanning** -- walks `.ads` files, extracts subprogram declarations, [docstring
  annotations](docs/api-docs/adacovex-docstring-spec.md)
  (`@param`, `@return`, `@field`, `@formal`), and HLR traceability tags
- **Proof analysis** -- parses GNATprove `gnatprove.out` summaries per check category
  (flow, run-time, assertions, contracts, termination); assesses [SPARK assurance
  levels](docs/api-docs/adacovex-spark-levels.md) (Stone--Platinum)
- **Test parsing** -- reads [test-result markdown](docs/api-docs/adacovex-test-format.md)
  for pass/fail counts (supports both native Ada test output and AUnit format)
- **[DAL compliance](docs/api-docs/adacovex-dal-levels.md)** -- assesses DO-178C DAL A-E
  criteria (HLR coverage, orphan tags, test status, minimum SPARK proof level)
- **Multiple outputs**:
  - ANSI terminal report
  - SVG badges (Shields.io style) -- SPARK level, test status, DO-178C status, docstring coverage
  - Markdown reports -- `VERIFICATION.md` + `TRACE.md`
  - HTML dashboard + JSON API via built-in HTTP server
- **Scalable** -- package/subprogram collections use `Ada.Containers.Vectors`
(heap-allocated, no compile-time limits on count). Fixed-size buffers: 8192-char
lines, 4096-char paths.

## Quick start

```bash
# Build
make build

# Run against adacovex itself (strict mode, default)
make run-self

# Run against Ada_CRDT (relaxed mode, skip demo/deps/examples)
make run-ada-crdt

# Explicit target
./bin/adacovex --target=../Ada_CRDT --dal=C
```

## CLI reference

```
adacovex [options]
```

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
| `--verbose` | off | both | Verbose diagnostics |
| `--help` | - | both | Print usage and exit |

### Flag details

**`--target=PATH`** -- Project to analyze. Relative paths resolved against CWD.
Default: current working directory.

**`--manifest=PATH`** -- Override project manifest file. Auto-detected from
`<target>/alire-dev.toml` or `<target>/alire.toml`. Displayed as metadata only.

**`--dal=LEVEL`** -- Target DAL level: `A`, `B`, `C`, `D`, or `E` (case-insensitive).
Determines minimum SPARK level and criteria checked. See [DAL levels](#dal-levels).

**`--serve`** -- After scanning, start HTTP server on `--port` (default 8080):
- `GET /` -- HTML dashboard
- `GET /api/metrics` -- JSON metrics
- `GET /badge/spark.svg`, `GET /badge/tests.svg`, `GET /badge/do178c.svg` -- SVG badges

**`--emit-svg=PATH`** -- Write SVG badges (`spark.svg`, `tests.svg`, `do178c.svg`, `docs.svg`)
to directory. Default: `<target>/docs/badges`. Override with `--no-svg`.

**`--no-svg`** -- Suppress all SVG badge output. Overrides `--emit-svg`.

**`--emit-markdown=PATH`** -- Write `VERIFICATION.md` (full report) and `TRACE.md`
(HLR traceability matrix) to the given directory.

**`--skip-dir=NAME`** -- Add directory name to skip list (repeatable).
Only effective in relaxed mode. Default skip list: `demo,deps,examples`.

**`--relaxed`** -- Disable strict mode. Enables the skip list (default: `demo,deps,examples`
plus any `--skip-dir` entries). Does NOT apply `.adacovex/patches/`.
Default: OFF (strict mode is on by default).

**`--compare-base=REF`** -- Differential mode: assess a git base revision in a
temporary worktree and print a side-by-side comparison against the current
tree (packages, docstrings, HLR trace, orphans, SPARK level, VCs, tests, DAL).
Exit `0` only if there are no regressions and the current DAL is Achieved.
The target must be a git repository with `git` on `PATH`. Artifacts the base
does not commit (`gnatprove.out`, `test_result.md`) report `N/A`.

**`--coverage-delta=REF`** -- Docstring-coverage gate for PR checks: scans
sources + patches on a git base ref and the current tree, prints a compact
coverage table plus a machine-parseable `coverage_delta:` line, and exits `1`
if current coverage dropped below the base. Runs without GNATprove/tests, so
it works when the base does not commit build artifacts. Mutually exclusive
with `--compare-base`.

**`--verbose`** -- Print pipeline step diagnostics to stderr.

### Strict vs relaxed mode

| Aspect | Strict (default) | Relaxed (`--relaxed`) |
|--------|-----------------|----------------------|
| Directory exclusions | `.git`, `obj`, `tests`, `config`, `.adacovex` only | Same + `demo,deps,examples` + `--skip-dir` additions |
| Vendored code | Scanned and counted | Skipped |
| Patch files | Applied from `.adacovex/patches/` | Not applied |
| Use case | Full compliance audit | Quick assessment of production code |

### Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success (DAL achieved, all checks pass) |
| `1` | Compliance failure (DAL unmet, tests failing, etc.) |

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
```

### Using adacovex from another project

Two approaches are equally valid; pick whichever fits the project.

**1. Point `--target` at the adacovex dev source (no install needed):**

```bash
cd /path/to/adacovex && make build
cd /path/to/project
/path/to/adacovex/bin/adacovex --target=. --dal=C
```

Because `--target` defaults to the current directory, running the binary from
inside the project scans it with no extra flags. The project needs no Ada
tooling of its own -- only the adacovex working tree needs GNAT and Alire.

**2. Manage adacovex as an Alire dev dependency:**

```toml
# <project>/alire-dev.toml (never alire.toml, so release builds stay clean)
[[depends-on]]
covex = "*"
```

Then `alr build` produces `bin/adacovex` inside the project and
`adacovex` runs against the current directory by default.

In both cases the assessed project is the `--target` directory (or CWD when
omitted); the two approaches differ only in how the binary is obtained.

### GitHub Actions

A composite action at `.github/actions/adacovex` runs the full adacovex
pipeline in CI. It installs the Alire toolchain via
[`alire-project/setup-alire`](https://github.com/alire-project/setup-alire),
obtains the adacovex binary, runs the assessment, and publishes a Markdown
step summary, machine-readable outputs, and SVG badge artifacts.

The action is version-matched to the adacovex binary: the release workflow
bundles `adacovex-vX.Y.Z.tar.gz` for every `vX.Y.Z` tag, and the action
downloads the binary for the tag it is referenced by. Reference it by a
floating tag to always get the latest published release, or pin to an exact
release for reproducibility. So the marketplace action at `@v1` always runs the
latest `v1.x` binary — no building in the consumer's repo.

Reference it from any Ada/SPARK repo (recommended: `@latest`-style floating
tag; you can pin to a specific release if needed):

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: bladeacer/adacovex/.github/actions/adacovex@v1
    with:
      target: .
      dal: C
```

To target a specific release instead, pin the ref:

```yaml
  - uses: bladeacer/adacovex/.github/actions/adacovex@v1.3.0
```

#### Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `target` | `.` | Target project root (relative to workspace root) |
| `dal` | `C` | DO-178C DAL level to assess (A-E) |
| `gnat-version` | `15.2.1` | GNAT toolchain version to select via `alr` |
| `version` | `''` | adacovex version to use; defaults to the tag the action is referenced by |
| `build` | `false` | Build adacovex from source instead of downloading the version-matched binary (`true` for in-repo self-assessment) |
| `release-build` | `false` | Pass `--release` to `alr build` (for release workflows) |
| `prove` | `false` | Run GNATprove before assessing, for repos that don't commit `gnatprove.out` (gnatprove is a declared dependency, no dev-manifest swap) |
| `run-tests` | `false` | Build and run the native test suite (requires `build: true`) |
| `assess` | `true` | Run the assessment and publish outputs/badges (set `false` for build/test-only jobs) |
| `compare-base` | `''` | Git ref to run `--compare-base` against (fails on regression) |
| `coverage-delta` | `''` | Git ref to run `--coverage-delta` against (fails if coverage dropped) |
| `emit-markdown` | `''` | Write `VERIFICATION.md` + `TRACE.md` into this directory |
| `cache` | `true` | Cache Alire toolchain/deps with `actions/cache` |

#### Outputs

| Output | Description |
|--------|-------------|
| `dal-status` | `Achieved` or `Unmet` |
| `spark-level` | SPARK level detected (Stone..Platinum) |
| `test-count` | Number of passing tests |
| `coverage-pct` | Current docstring coverage (in `--coverage-delta` mode) |

#### PR coverage gate

Gate every pull request on docstring coverage not regressing against the base
branch (this is exactly what `--coverage-delta` was built for). Use the
floating tag to track the latest release, or pin to a full release tag to
download a matching binary deterministically:

```yaml
# .github/workflows/pr-check.yml
on:
  pull_request:
jobs:
  coverage-delta:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: bladeacer/adacovex/.github/actions/adacovex@v1
        with:
          target: .
          dal: C
          coverage-delta: ${{ github.event.pull_request.base.sha }}
```

The action exits non-zero when coverage drops, failing the check. This
workflow ships in the repo at `.github/workflows/pr-check.yml`.

#### Release bundling

Every `vX.Y.Z` tag triggers `.github/workflows/release.yml`, which calls the
composite action with `build`, `release-build`, and `prove` to build the
release binary, run GNATprove, and validate the self-assessment, then packages
and publishes the bundle to the GitHub Release:

- `adacovex-vX.Y.Z.tar.gz` -- the version-matched binary (`adacovex` plus the
  `covex` alias). The action downloads this asset for the tag it is referenced
  by, so `@v1.3.0` runs adacovex `v1.3.0` and `@v1` runs the latest `v1.x`
  release.
- `adacovex-action-vX.Y.Z.tar.gz` -- a copy of the composite action itself for
  vendoring or air-gapped use.

`make release VERSION=x.y.z` does the same locally (build `--release`,
generate proofs, validate DAL-C, bundle `dist/`), then tags and pushes to
trigger the workflow.

#### Releases on tags

Pushing a `vX.Y.Z` tag triggers `.github/workflows/release.yml`, which builds
the release binary, runs the self-assessment as validation, and creates a
GitHub Release with two artifacts:

- `adacovex-<version>.tar.gz` -- `adacovex` plus a `covex` symlink pointing at
  it.
- `adacovex-action-<version>.tar.gz` -- the composite action directory, for
  vendoring/consuming the action outside the repo.

The tag itself is what "publishes" the action: once pushed,
`uses: bladeacer/adacovex/.github/actions/adacovex@v<version>` resolves for any
workflow. Each release therefore corresponds to one adacovex version. The
action ships with `branding` and an `author`, so once it is listed on the
GitHub Actions marketplace, every `vX.Y.Z` tag auto-publishes that version of
the action.

The release workflow also force-pushes the floating tags `vMAJOR` and
`vMAJOR.MINOR` (e.g. `v1` and `v1.3` from `v1.3.0`). Reference `@v1` /
`@v1.3` to always get the latest release within a major or minor version, or
pin an exact `@vX.Y.Z` when you need a fixed version.

## Requirements for target projects

To run adacovex against an Ada/SPARK project, it must have:

1. **Ada source files** (`.ads`) under the target root.
2. **GNATprove output**: `gnatprove.out` in the target root or
   `<target>/obj/gnatprove/gnatprove.out`.
3. **Test results**: `<target>/test_result.md` with a Markdown table
   containing `Tests` and `Status` columns (PASS/FAIL).
4. **HLR document** (for DAL assessment): `<target>/docs/compliance/HLR.md`.

Missing data shows "N/A" and relevant DAL checks report `Unmet`.

Non-Ada projects (C/C++, Python, JS, ...) that run adacovex provision their
own `alire.toml` / `alire-dev.toml` to manage the Ada deps needed to build
adacovex itself (adacovex + GNAT toolchain). Running `adacovex` from the repo
scans it and uses its manifest.

## Docstring format

```ada
--  Summary sentence describing what the subprogram does.
--  @param Name  Description of the parameter.
--  @return Description of the return value.
procedure Do_Something (Name : in Some_Type);

--  A plain summary line is sufficient for no-param procedures.
procedure Simple_Thing;
```

Tags: `@param`, `@return`, `@field`, `@formal`. Prefix: `--  ` (two dashes + two spaces).

See [full spec](docs/api-docs/adacovex-docstring-spec.md).

## Patch files (strict mode)

For vendored/third-party code that you cannot modify, create docstring patches:

```
<target>/.adacovex/patches/<relative-path>
```

Example: to patch `Ada_CRDT/demo/deps/vt100/vt100.ads`:

```
Ada_CRDT/.adacovex/patches/demo/deps/vt100/vt100.ads
```

The patch file is a valid Ada `.ads` with docstrings for subprograms you want
to document. Overloaded subprograms require one patch entry per overload.

## DAL levels

| DAL | Min SPARK | Tests must pass | HLRs traced | No orphans |
|-----|-----------|-----------------|-------------|------------|
| A | Gold | Yes | Yes | Yes |
| B | Silver | Yes | Yes | Yes |
| C | Bronze | Yes | Yes | Yes |
| D | None (Stone) | Yes | Yes | Yes |
| E | None (Stone) | No | Yes | Yes |

## Makefile targets

| Target | Description |
|--------|-------------|
| `build` | `alr build` (adacovex + test_runner, covex alias) |
| `test` | Build and run native test suite (169 tests) |
| `prove` | `alr gnatprove` (gnatprove is a declared dependency) |
| `fmt` | Format Ada sources with `gnatformat` |
| `doc` | Generate API docs via gnatdoc + rst2md |
| `run-self` | Run against adacovex itself (default target: cwd) |
| `run-ada-crdt` | Run against `../Ada_CRDT` (strict mode) |
| `bump-version` | Bump version across manifests + changelog (`VERSION=x.y.z`) |
| `release` | Build `--release`, prove, validate, run docstring-coverage gate vs last release, bundle + push (`VERSION=x.y.z`) |
| `ascii-check` | Verify all source files are pure ASCII |
| `dev-setup` | Copy alire-dev.toml over alire.toml |
| `prod-setup` | Restore clean publishing alire.toml |
| `clean` | Remove `bin/`, `obj/`, generated reports |

## Project structure

```
src/
|-- adacovex.ads                  -- Version constant
|-- adacovex_main.adb             -- CLI entry point (builds as bin/adacovex)
|-- core/                         -- Types + CLI config
|-- parsers/                      -- Source, proof, test, DO-178C parsers
|-- compliance/                   -- DAL assessment logic
|-- renderers/                    -- ANSI, SVG, Markdown, HTML output
|-- server/                       -- HTTP/1.1 dashboard server
|-- tests/                        -- Native test suite (169 tests)
```

## Verification

| Check | Command | Requirement |
|-------|---------|-------------|
| Unit tests | `make test` | 169/169 passing |
| Self-assessment | `make run-self` | 100% docs, Platinum, DAL-C |
| SPARK proof | `make prove` | 28/28 VCs Platinum |
| Ada_CRDT regression | `make run-ada-crdt` | 100% docs, Platinum, DAL-C (strict mode) |

See [changelogs](docs/changelogs/index.md) for full release notes.

## Documentation

| Reference | Description |
|-----------|-------------|
| [Docstring Spec](docs/api-docs/adacovex-docstring-spec.md) | Annotation format, placement, conventions |
| [Test Format](docs/api-docs/adacovex-test-format.md) | Supported test-result output format |
| [SPARK Levels](docs/api-docs/adacovex-spark-levels.md) | Assurance level objectives (Stone--Platinum) |
| [DAL Levels](docs/api-docs/adacovex-dal-levels.md) | DO-178C DAL A - E criteria |
| [API Reference](docs/api-docs/index.md) | Auto-generated package API docs |
| [Changelog](docs/changelogs/index.md) | Release history |

## Requirements

- **Alire** >= 2.0
- **GNAT** Ada compiler (managed by Alire)
- **GNATprove** (optional, for proof targets, managed by Alire)
- **gnatpp** / **gnatdoc** (optional, for fmt/doc targets, managed by Alire)

## Credits

- **[setup-alire](https://github.com/alire-project/setup-alire)** GitHub Action (used in CI)

## License

Apache-2.0 -- see [LICENSE](LICENSE) for details.
