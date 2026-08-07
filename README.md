[![covex Alire crate badge](https://img.shields.io/endpoint?url=https://alire.ada.dev/badges/covex.json)](https://alire.ada.dev/crates/covex)
![SPARK](docs/badges/spark.svg)
![Tests](docs/badges/tests.svg)
![DO-178C](docs/badges/do178c.svg)
![docs](docs/badges/docs.svg)

# adacovex

**Zero-dependency Ada/SPARK CLI tool** for coverage analysis, proof verification,
test-result parsing, DO-178C DAL compliance assessment, and interactive dashboards.
No library dependencies beyond the GNAT runtime. gnatprove is not a declared
dependency -- the `prove` subcommand resolves it at run time (per-project
manifest, `$PATH`, cached toolchain, or download) -- so installing adacovex
pulls nothing but the binary.

## Features

- **Source scanning** -- walks `.ads` files, extracts subprogram declarations, [docstring
  annotations](docs/api-docs/adacovex-docstring-spec.md)
  in three styles (Ada `@param`/`@return`/`@field`/`@formal`/`@brief`/`@summary`,
  Google `Args:`/`Returns:`, Sphinx `:param:`/`:returns:`), and HLR traceability tags
- **Proof analysis** -- parses GNATprove `gnatprove.out` summaries per check category
  (flow, run-time, assertions, contracts, termination); assesses [SPARK assurance
  levels](docs/api-docs/adacovex-spark-levels.md) (Stone--Platinum)
- **Test parsing** -- reads [test-result summaries](docs/api-docs/adacovex-test-format.md)
  for pass/fail counts (Markdown tables, TAP, Automake suites, Maven Surefire,
  Unity, and AUnit-compatible output)
- **[DAL compliance](docs/api-docs/adacovex-dal-levels.md)** -- assesses DO-178C DAL A-E
  criteria (HLR coverage, orphan tags, test status, minimum SPARK proof level)
- **Multiple outputs**:
  - ANSI terminal report
  - SVG badges (Shields.io style) -- SPARK level, test status, DO-178C status, docstring coverage
  - Markdown reports -- `VERIFICATION.md` + `TRACE.md`
  - HTML dashboard + JSON API via built-in HTTP server
- **Scalable** -- package/subprogram collections use `Ada.Containers.Vectors`
(heap-allocated, no compile-time limits on count). Fixed-size buffers: 262144-char
lines, 4096-char paths on a 64-bit host (scaled by the auto-detected host
word size).

## AI Assistance Disclosure

AI tools were utilized during the development of this project for tasks
such as boilerplate generation, contract drafting, and docstring formatting.

### "Why should I trust your code?"

Given the use of AI assistance, healthy skepticism is natural and encouraged.
However, project reliability is grounded in mathematical proof and
non-invasive design rather than implicit trust:

- **Formal Verification:** Core Ada logic is formally verified using
SPARK Ada (achieving Platinum/AoRTE-free verification conditions via `gnatprove`).
- **Read-Only Engine:** `adacovex` acts strictly as an assessment engine.
It processes input payloads, parses build artifacts, and produces reports without
modifying your source files in place.
- **Open Auditability:** The codebase is fully open source under the Apache-2.0
license for independent inspection and review.

> *Still skeptical?* See Ken Thompson's landmark paper,
[*Reflections on Trusting Trust*](https://dl.acm.org/doi/epdf/10.1145/358198.358210),
on the fundamental nature of trust in software toolchains.


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

## Installing adacovex

### Option 1: declare it in your project's Alire manifest (recommended)

The preferred way to use adacovex inside a project is to declare it as a
dependency, so Alire manages the binary together with the rest of the build
environment. Put `covex` in your project's `alire-dev.toml` (never `alire.toml`,
so release builds stay clean), alongside `gnatprove` -- proof runs are a
standard part of the workflow, so declare the prover in the same manifest:

```toml
# <project>/alire-dev.toml
[[depends-on]]
covex = "*"
gnatprove = "^15.1.0"
```

Then `alr build` produces `bin/adacovex` inside the project and the `prove`
subcommand runs gnatprove through `alr exec`, so each project pins its own
exact toolchain version -- no global install needed:

```bash
alr build
./bin/adacovex --target=. --dal=C
./bin/adacovex prove --target=.   # runs gnatprove via alr exec
```

For a project that is itself an Alire crate, `gnatprove` may instead be
declared in `alire.toml` if the proof toolchain should ship with the crate.
The `prove` subcommand consults both manifests (dev first) and resolves
accordingly.

### Option 2: `alr install` (global, to `$PATH`)

Install the binary and the prover together, then put Alire's bin directory on
`$PATH`:

```bash
alr install covex gnatprove
export PATH="$HOME/.local/bin:$PATH"   # or wherever `alr install` put the binaries
```

`covex` is the Alire crate name for adacovex
([crate page](https://alire.ada.dev/crates/covex)); the installed binary scans
the current directory by default, so once on `$PATH` it runs from any project
with no further setup. Alire installs to its bin directory (default
`~/.local/bin`; `alr install` prints the exact location after installing, and
`alr toolchain --install-dir` shows the toolchain directory) -- add it to
`$PATH` to call `covex` from anywhere. A `gnatprove` installed this way is
picked up from `$PATH` by `covex prove` when the target project declares no
manifest dependency of its own.

### Option 3: download a release bundle from GitHub

Every `vX.Y.Z` tag publishes `adacovex-vX.Y.Z.tar.gz`
(`adacovex` plus a `covex` alias symlink) on the
[GitHub Releases page](https://github.com/bladeacer/adacovex/releases).

**One-liner (latest release).** The bundled `install.sh` detects the OS and
architecture, resolves the latest tag, and installs to `~/.adacovex/bin`
(override with `ADACOVEX_HOME`, `ADACOVEX_VERSION`, `ADACOVEX_REPO`):

```bash
curl -fsSL https://raw.githubusercontent.com/bladeacer/adacovex/main/install.sh | bash
```

It warns if Alire is not on `$PATH` (so `covex prove` has no `alr exec`
fallback), then adds the install bin dir to your shell's `PATH` and symlinks
`covex` -> `adacovex`.

**Manual.** Or fetch the bundle and unpack anywhere on `$PATH`:

```bash
VERSION=v1.6.0
curl -fL -o adacovex.tar.gz \
  "https://github.com/bladeacer/adacovex/releases/download/$VERSION/adacovex-$VERSION.tar.gz"
mkdir -p ~/.local/bin
tar -xzf adacovex.tar.gz -C ~/.local/bin
export PATH="$HOME/.local/bin:$PATH"
adacovex --help
```

Release bundles are attested with
[`actions/attest`](https://github.com/actions/attest);
verify a download with `gh attestation verify` against the
[release](https://github.com/bladeacer/adacovex/releases) you fetched.

### Building from source

Clone the repo and `make build`, or manage adacovex as an Alire dev dependency
(see [Using adacovex from another project](#using-adacovex-from-another-project)).

## GNATprove toolchain resolution

The `prove` subcommand resolves the `gnatprove` executable in this order:

1. **Per-project manifest (preferred)**: if `<target>/alire.toml` or
   `<target>/alire-dev.toml` declares a `gnatprove` dependency, it is run via
   `alr exec gnatprove` so Alire manages the exact toolchain version for that
   project.
2. **`$PATH`**: a `gnatprove` already on `$PATH` (e.g. installed beforehand
   with `alr install gnatprove`).
3. **Cached toolchain**: `~/.adacovex/toolchain/`.
4. **Download**: last resort, fetch the platform toolchain bundle.

If the target manifest declares `gnatprove` but `alr` is not installed, install
Alire first (`curl https://alire.ada.dev -sSf | sh`); the fallback paths then
kick in automatically.

## CLI reference

```
adacovex [options]
adacovex sbom [--format=cyclonedx-json|spdx-json] [--out=PATH]
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
does not commit (`gnatprove.out`, a test-result summary) report `N/A`.

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

# Proof-aware SBOM (CycloneDX 1.5 JSON)
adacovex sbom --format=cyclonedx-json --target=. --dal=C

# Proof-aware SBOM (SPDX 2.3 JSON) at a custom path
adacovex sbom --format=spdx-json --out=docs/compliance/sbom.spdx.json
```

### Proof-aware SBOM (`adacovex sbom`)

`adacovex sbom` resolves the target project's dependency graph from its Alire
manifest (`alire.toml` / `alire-dev.toml`), the solved-crate list in
`alire/alire.lock`, and the GNAT project file's `with` clauses, then writes a
software bill of materials in either CycloneDX 1.5 JSON (`--format=
cyclonedx-json`, default, writes `<target>/sbom.json`) or SPDX 2.3 JSON
(`--format=spdx-json`, writes `<target>/sbom.spdx.json`). `--out=PATH`
overrides the output path; the containing directory is created automatically.

Only the **root component** -- the project adacovex actually assessed -- carries
the proof-aware properties `adacovex:proof_level` (`Gold` for the verified build
tier, `Platinum` when the assessment proved every verification condition) and
`adacovex:dal_target` (`DAL-A` through `DAL-D`; omitted for `DAL-E`). Dependency
components report `adacovex:proof_level = "Not proved"`: adacovex only proves
the target itself, never third-party dependencies, so they must not claim a
Gold/Platinum level. In SPDX these are encoded as `attributionTexts` entries.
Both formats validate against the official
[CycloneDX 1.5](https://github.com/CycloneDX/specification) and
[SPDX 2.3](https://spdx.dev) JSON schemas (specifications by the CycloneDX and
SPDX projects, licensed Apache-2.0 and CC0-1.0 respectively; see
[THIRD_PARTY_NOTICES.md](docs/THIRD_PARTY_NOTICES.md)).

`sbom` mode is mutually exclusive with `--compare-base` and
`--coverage-delta`, and it scans sources, parses proof/test results, and
assesses DAL first so the emitted properties reflect the real assessment
state. If the target has no Alire manifest the SBOM cannot be generated (the
GitHub Action reports this as a warning without failing the job).

SBOM output is **deterministic**: the `metadata.timestamp` (CycloneDX) /
`creationInfo.created` (SPDX) field honors the `SOURCE_DATE_EPOCH`
environment variable (the reproducible-builds convention). When it is set to
a Unix epoch second count the timestamp is derived from it in UTC with pure
integer math, so the emitted SBOM is byte-for-byte identical across runs and
machines. Without it the current time is used.

To tie the SBOM timestamp to the exact git commit the assessment ran on, set
`SOURCE_DATE_EPOCH` from the commit time before running adacovex:

```bash
export SOURCE_DATE_EPOCH=$(git -C /path/to/target log -1 --format=%ct)
adacovex --target=/path/to/target
```

The bundled `make` targets (`run-self`, `run-ada-crdt`, `prove`, `release`,
and Ada_CRDT's `prove`/`badges`) already do this from the target's git `HEAD`
commit time, so regenerated `sbom.json` stays stable per commit.

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

**2. Manage adacovex as an Alire dev dependency (preferred for real usage):**

```toml
# <project>/alire-dev.toml (never alire.toml, so release builds stay clean)
[[depends-on]]
covex = "*"
gnatprove = "^15.1.0"
```

Then `alr build` produces `bin/adacovex` inside the project, `adacovex` runs
against the current directory by default, and `covex prove` runs gnatprove
through `alr exec` (see [Installing adacovex](#installing-adacovex)).

In both cases the assessed project is the `--target` directory (or CWD when
omitted); the two approaches differ only in how the binary is obtained.

### GitHub Actions

A composite action at the repository root (`./action.yml`) runs the full
adacovex pipeline in CI. It installs Alire via
[`alire-project/setup-alire`](https://github.com/alire-project/setup-alire)
(GNAT at `gnat-version` plus `gprbuild`; `gnatprove` is not an `alr toolchain`
component and is resolved by the `prove` subcommand via the target project's
manifest, the README-preferred method), obtains the
adacovex binary, runs the assessment, generates a proof-aware
SBOM, and publishes a Markdown step summary, machine-readable outputs, and SVG
badge artifacts.

The action is version-matched to the adacovex binary: the release workflow
bundles `adacovex-vX.Y.Z.tar.gz` for every `vX.Y.Z` tag, and the action
downloads the binary for the tag it is referenced by. Reference it by a
floating tag to always get the latest published release, or pin to an exact
release for reproducibility. So the marketplace action at `@v1` always runs the
latest `v1.x` binary -- no building in the consumer's repo.

Reference it from any Ada/SPARK repo (recommended: `@latest`-style floating
tag; you can pin to a specific release if needed):

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: bladeacer/adacovex@v1
    with:
      target: .
      dal: C
```

To target a specific release instead, pin the ref:

```yaml
  - uses: bladeacer/adacovex@v1.4.0
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
| `prove` | `false` | Run GNATprove before assessing, for repos that don't commit `gnatprove.out` (resolved via per-project manifest, `$PATH`, cached toolchain, or download) |
| `run-tests` | `false` | Build and run the native test suite (requires `build: true`) |
| `assess` | `true` | Run the assessment and publish outputs/badges (set `false` for build/test-only jobs) |
| `compare-base` | `''` | Git ref to run `--compare-base` against (fails on regression) |
| `coverage-delta` | `''` | Git ref to run `--coverage-delta` against (fails if coverage dropped) |
| `emit-markdown` | `''` | Write `VERIFICATION.md` + `TRACE.md` into this directory |
| `generate-sbom` | `true` | Generate a proof-aware SBOM after the assessment and upload it as an artifact |
| `sbom-format` | `cyclonedx-json` | SBOM format: `cyclonedx-json` (writes `<target>/sbom.json`) or `spdx-json` (writes `<target>/sbom.spdx.json`) |
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
      - uses: bladeacer/adacovex@v1
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

Both bundles are attested with
[`actions/attest`](https://github.com/actions/attest)
on every tag (OIDC attestations appear under the release's attestations tab).
The release notes link the signed attestation directly via the action's
`attestation-url` output, plus a *Git Changelog* compare link
(`compare/v1.5.0...v1.6.0`) and the human-readable changelog.

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
`uses: bladeacer/adacovex@v<version>` resolves for any
workflow. Each release therefore corresponds to one adacovex version. The
action ships with `branding` and an `author`, so once it is listed on the
GitHub Actions marketplace, every `vX.Y.Z` tag auto-publishes that version of
the action.

The release workflow also force-pushes the floating tags `vMAJOR`,
`vMAJOR.MINOR`, and `latest` (e.g. `v1`, `v1.3`, and `latest` from `v1.3.0`).
Reference `@latest` to always get the newest published release, `@v1` /
`@v1.3` for the latest release within a major or minor version, or pin an exact
`@vX.Y.Z` when you need a fixed version.

## Requirements for target projects

To run adacovex against an Ada/SPARK project, it must have:

1. **Ada source files** (`.ads`) under the target root.
2. **GNATprove output**: `gnatprove.out` in the target root or
   `<target>/obj/gnatprove/gnatprove.out`.
3. **Test results**: a test-summary file in the target root -- adacovex
   auto-discovers conventional names (`test_result.md`, `test_results.md`,
   `test-result.md`, `test_report.md`, `test_output.md`, plus `.txt`/`.log`
   variants, and the `docs/` mirrors) containing a Markdown table with `Tests`
   and `Status` columns (PASS/FAIL), or a supported summary format (TAP,
   Automake `PASS:`/`FAIL:`, Maven Surefire `Tests run:`, Unity `N Tests M
   Failures`, or a `Passed:`/`Failed:` line).
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

Tags: `@param`, `@parameter`, `@return`, `@returns`, `@field`, `@formal`,
`@brief`, `@summary`. Prefix: `--  ` (two dashes + two spaces); the
single-space `-- ` and tab-separated styles are also recognized. Google
(`Args:`/`Returns:`) and Sphinx (`:param:`/`:returns:`) docstring styles are
supported too, so third-party and generated code needs no rewriting.

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
| `test` | Build and run native test suite (295 tests) |
| `prove` | `./bin/adacovex prove --target=. --no-svg` (resolves gnatprove from the dev manifest / `$PATH` / cache / download) |
| `fmt` | Format Ada sources with `gnatformat` |
| `doc` | Generate API docs via gnatdoc + rst2md |
| `run-self` | Run against adacovex itself (default target: cwd) |
| `run-ada-crdt` | Run against `../Ada_CRDT` (strict mode) |
| `coverage-gate` | Run `--coverage-delta` between the latest two release tags (worktree at latest tag) |
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
|-- tests/                        -- Native test suite (295 tests)
```

## Verification

| Check | Command | Requirement |
|-------|---------|-------------|
| Unit tests | `make test` | 295/295 passing |
| Self-assessment | `make run-self` | 100% docs, Platinum, DAL-C Achieved |
| SPARK proof | `make prove` | 500/500 VCs Platinum |
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
- **GNATprove** (optional; used by `prove`. Resolved at run time from the
  per-project manifest, `$PATH`, `~/.adacovex/toolchain/`, or a download --
  adacovex declares no gnatprove dependency itself)
- **gnatpp** / **gnatdoc** (optional, for fmt/doc targets, managed by Alire)

## Swapping the GNAT compiler for an LLVM-based one

adacovex and Alire both default to the GCC-based **GNAT** (`gnat_native`)
compiler; no action is needed. Only swap if you specifically want an
LLVM-backend GNAT (e.g. GNAT LLVM) for your target project -- for example to
exercise dissimilar redundancy via diverse code generation.

GNAT LLVM is **not** yet packaged as a standard Alire toolchain crate, so two
paths exist:

1. **Alire-managed compiler (preferred when available).** If a GNAT LLVM binary
   release becomes available in the Alire index, declare it in your
   `alire.toml` / `alire-dev.toml`:

   ```toml
   [[depends-on]]
   gnat_llvm = "*"
   ```

   `alr` then selects it automatically for that project's builds. You can also
   pick a default compiler for all projects with
   `alr toolchain --select --disable-assistant` and choosing the LLVM GNAT.

2. **System-installed GNAT LLVM.** Install GNAT LLVM on `$PATH`, then force the
   Ada toolchain in the root `.gpr` so `gprbuild` doesn't fall back to the
   GCC GNAT:

   ```gpr
   for Toolchain_Name ("Ada") use "GNAT_LLVM";
   ```

   You can confirm which compiler built a given `.ali` file by its first line
   (`GNAT` vs `GNAT-LLVM`).

Notes:

- GNAT LLVM and GCC GNAT are not guaranteed ABI-compatible; compile all Ada in
  a project with the same compiler.
- GNAT LLVM's `-fstack-check` support is partial and some features
  (`Scalar_Storage_Order`, `Convention C++`) differ from GCC GNAT.
- SPARK proof results are compiler-independent, so `covex prove` and the
  DAL assessment are unaffected by the choice.

## Credits

- **[setup-alire](https://github.com/alire-project/setup-alire)** GitHub Action (used in CI)
- **[CycloneDX](https://github.com/CycloneDX/specification)** SBOM specification (CycloneDX 1.5 JSON output)
- **[SPDX](https://spdx.dev)** Software Package Data Exchange specification (SPDX 2.3 JSON output)

## License

Apache-2.0 -- see [LICENSE](LICENSE) for details.
