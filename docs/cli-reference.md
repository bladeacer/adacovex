# adacovex CLI Reference

This page is the quick reference: usage, the full flag table, and a concise
note per flag. Feature-specific detail lives in dedicated pages (linked from
each section): the [web dashboard](dashboard.md), the
[`sbom` subcommand](sbom.md), [VCS support](vcs.md), the
[platforms/`status`](platforms.md#status-subcommand) and
[installation](installation.md) pages, and
[Architecture](architecture.md) for design-level detail such as result
caching and the patch system.

## Usage

```
adacovex [options]
adacovex sbom [--format=cyclonedx-json|spdx-json] [--out=PATH]
           [--standard=NAME|--dal=LEVEL|--asil=LEVEL|--class=LEVEL]
adacovex prove [--target=PATH] [prove options]
adacovex status [--target=PATH]
adacovex man [--check] [--dir=PATH]
```

## Flags

| Flag | Default | Mode | Description |
|------|---------|------|-------------|
| `--target=PATH` | `.` (CWD) | both | Target project root directory |
| `--manifest=PATH` | auto-detected | both | Override project manifest path |
| `--dal=LEVEL` | `C` | both | DO-178C DAL level (A-E; also the shared rigor tier) |
| `--asil=LEVEL` | - | both | ISO 26262 level: `A`\|`B`\|`C`\|`D`\|`QM` |
| `--class=LEVEL` | - | both | IEC 62304 safety class: `A`\|`B`\|`C` |
| `--standard=NAME` | `do178c` | both | `do178c`\|`iso26262`\|`iec62304`\|`all` |
| `--serve` | off | both | Start HTTP dashboard server (standard-aware; light/dark/system themes) |
| `--theme=NAME` | `system` | serve | Dashboard theme: `light`\|`dark`\|`system` |
| `--port=N` | `8080` | serve | Dashboard server port |
| `--emit-svg=PATH` | `<target>/docs/badges` | both | Output directory for SVG badges |
| `--no-svg` | off | both | Suppress SVG badge output |
| `--emit-markdown=PATH` | off | both | Output directory for Markdown reports |
| `--skip-dir=NAME` | `demo,deps,examples` | relaxed | Directory name to skip (repeatable) |
| `--relaxed` | off | both | Disable strict mode (skip dirs, no patches) |
| `--compare-base=REF` | off | both | Differential mode vs a base rev (git/hg/svn/fossil/jj) |
| `--coverage-delta=REF` | off | both | Docstring-coverage gate vs a base rev (git/hg/svn/fossil/jj) |
| `--cache` | on | both | Enable on-disk result caching |
| `--no-cache` | off | both | Disable result caching (always re-scan/re-parse/re-prove) |
| `--cache-dir=PATH` | `~/.adacovex/cache/<ver>/<schema>` | both | Cache directory for analysis results |
| `--cache-max=N` | `4096` | both | Max cache entries before oldest-first eviction |
| `--require-spark=LVL` | off | both | Fail loudly (exit 1) if SPARK level < LVL (Stone..Platinum) |
| `--require-docstrings=PCT` | off | both | Fail loudly if docstring coverage < PCT% (0-100) |
| `--require-tests=N` | off | both | Fail loudly if passing test count < N |
| `--require-proof=PCT` | off | both | Fail loudly if proved-VC coverage < PCT% (0-100) |
| `--verbose` | off | both | Verbose diagnostics |
| `--version` | - | - | Print the bundled version and exit |
| `man` | - | - | Install the man page into the local man database |
| `man --check` | - | - | Exit 0 if the installed man page matches the binary version, 1 otherwise |
| `man --dir=PATH` | `~/.local/share/man` | - | Install the man page under `PATH/man1` instead |
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

DO-178C DAL level (and the shared rigor tier): `A`, `B`, `C`, `D`, or `E`
(case-insensitive). Determines the minimum SPARK proof level required and the
specific criteria checked. This tier is shared across standards -- `--dal=C`
is DAL-C under DO-178C, ASIL B under ISO 26262, and safety Class A under
IEC 62304. See [DAL levels](api-docs/adacovex-dal-levels.md) and
[Standards](standards.md).

### `--asil=LEVEL`

ISO 26262 Automotive Safety Integrity Level: `A`, `B`, `C`, `D`, or `QM`
(case-insensitive). Sets the standard to `iso26262` and maps the ASIL level
to the shared rigor tier (ASIL D -> DAL A, ASIL C -> DAL B, ASIL B -> DAL C,
ASIL A -> DAL D, QM -> DAL E). `--asil=B` is therefore the clearest spelling
of "assess this project at ASIL B". See
[ASIL Levels](api-docs/adacovex-asil-levels.md).

### `--class=LEVEL`

IEC 62304 software safety class: `A`, `B`, or `C` (case-insensitive). Sets
the standard to `iec62304` and maps the class to the shared rigor tier
(Class C -> DAL A, Class B -> DAL B, Class A -> DAL C). `--class=A` is the
clearest spelling of "assess this project at safety Class A". See
[Safety Classes](api-docs/adacovex-class-levels.md).

### `--standard=NAME`

Select the compliance standard used to label the assessment (default
`do178c`). The evidence checks are identical across standards; only the
integrity-level names change in the report and badges:

- `do178c` -- DAL A--E (avionics)
- `iso26262` -- ASIL D / C / B / A / QM (automotive)
- `iec62304` -- Class C / B / A / no class (medical-device software)
- `all` -- run one assessment at the shared tier and emit badges/reports for
  every standard (`do178c.svg`, `iso26262.svg`, `iec62304.svg`)

Accepted case-insensitively, with or without the hyphen/space (`ISO-26262`,
`iec62304`, ...). See [Standards](standards.md) for the full tier mapping.

When both a dedicated level flag (`--asil` / `--class`) and `--standard` are
passed, the dedicated flag sets the standard and `--standard` is ignored for
labelling (last-write-wins per field); the shared tier is always whatever the
level flag (or `--dal`) resolved to.

### `status`

`adacovex status [--target=PATH]` reports toolchain + platform state without
running an assessment and without downloading or deploying anything: whether
Alire is installed, how gnatprove is resolved, the host CPU count and CI
status (and the resulting default `-j` parallelism), a **VCS report** (which
VCS tools are on `$PATH` and which manages the target -- see
[VCS support](vcs.md)), and mandb availability. Exit `0` when a usable
gnatprove is detectable without a download, `1` otherwise. Full detail:
[Platforms -- `status` subcommand](platforms.md#status-subcommand).

### `--serve`

After scanning and assessment, start the built-in HTTP/1.1 web dashboard on
`--port` (default `8080`): an HTML dashboard at `/`, a JSON API at
`/api/metrics`, and the SVG badges at `/badge/*.svg`. The server blocks until
interrupted. The dashboard is standard-aware (defaults to all standards) and
supports light / dark / system themes. Full detail, the JSON schema, the
theme-resolution order, and embedding tips:
[Web dashboard and JSON API](dashboard.md).

### `--theme=NAME`

Dashboard color theme for `--serve`: `system` (default, follows
`prefers-color-scheme`), `light`, or `dark` (case-insensitive). Sets the
initial dropdown selection in the served page; the header dropdown can
switch live afterwards and **Save settings** persists the choice in
`localStorage` (no cookies). Only relevant with `--serve`. See
[dashboard themes](dashboard.md#themes).

### `--port=N`

HTTP server port when `--serve` is used. Must be a valid `Positive` integer.
Only relevant with `--serve`.

### `--emit-svg=PATH`

Write SVG badges to a directory. Default `<target>/docs/badges`
(project-scoped). Creates:

- `spark.svg` -- SPARK assurance level (Stone through Platinum)
- `tests.svg` -- test pass/fail count
- `do178c.svg` / `iso26262.svg` / `iec62304.svg` -- compliance status for the
  selected standard (Achieved / Unmet), or all three with `--standard=all`
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

Differential mode: snapshot a base revision and print a side-by-side
comparison against the current tree (packages, subprograms, docstring %, HLR
traced, orphan tags, SPARK level, VCs proved, tests, DAL status). Exit `0`
only if there are no regressions AND the current DAL is Achieved; `1`
otherwise. Works on **git, Mercurial, Subversion, Fossil, and jj** -- full
detail and the per-VCS snapshot mechanisms:
[VCS support and differential assessment](vcs.md).

### `--coverage-delta=REF`

Lightweight docstring-coverage gate for PR-style CI checks. Scans sources +
patches + computes docstring metrics on both a base revision and the current
tree (no GNATprove/tests/DAL), prints a compact coverage table plus a
machine-parseable `coverage_delta:` line, and cleans up the snapshot. Exit `0`
if current docstring coverage is `>=` the base; `1` if coverage regressed.
Mutually exclusive with `--compare-base`. See
[VCS support and differential assessment](vcs.md).

### `--version`

Print the bundled version (`adacovex vX.Y.Z`) and exit, without scanning or
assessing. The version source depends on the **installation method**
(`ADACOVEX_VERSION` for release builds, `alire-dev.toml` for source
checkouts, `alire.toml` for dependency-managed installs). The same constant
drives the man page, the SBOM tool version, and the result-cache namespace,
so they can never drift. Full detail:
[Installation -- version source](installation.md#version-source-per-installation-method).

### `man`

The `man` subcommand installs the adacovex man page into the **local man
database** (Linux/WSL, no root required) and refreshes the index with `mandb`
when present. `adacovex man --check` exits 0 when the installed page matches
the binary, 1 otherwise (so a shell prompt hook can auto-update); `--dir=PATH`
overrides the install root. Full detail, exit codes, and the prompt-hook
recipe: [Installation -- keeping the man page in sync](installation.md#keeping-the-man-page-in-sync).

### VCS support

**A version control system is not required for base adacovex functionality**
(scanning, proof analysis, test parsing, compliance assessment, SBOM
generation, dashboards, caching). A VCS is only needed for the differential
modes (`--compare-base` / `--coverage-delta`), which snapshot a base revision
across **git, Mercurial, Subversion, Fossil, and jj** without touching the
working tree. Detection is marker-file based (`.git` / `.jj` / `.hg` / `.svn`
/ `.fslckout` / `_FOSSIL_`) with a command-probe fallback. Full detail, the
snapshot mechanism per VCS, and the Subversion/Fossil UX notes:
[VCS support and differential assessment](vcs.md).

### CI threshold gates (`--require-*`)

The four `--require-*` flags add explicit minimum-bar checks on top of the DAL
criteria. They are off by default; when set, the assessment fails loudly
(exit code `1`, with an explicit `CI GATE:` reason printed to the report) if the
target does not meet the required level:

```bash
adacovex --target=. --require-spark=Platinum --require-docstrings=100 \
         --require-tests=666 --require-proof=100
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
re-scanned / re-parsed / re-proved. Every entry is keyed by a namespace prefix
plus the SHA-256 of the artifact(s) it was derived from; an unchanged
manifest/lockfile/.gpr set serves the cached dependency graph, and unchanged
HLR.md/LLR.md serve the cached requirement parses. `--no-cache` bypasses it
entirely, `--cache-dir` relocates it, and `--cache-max` (default `4096`) caps
entries before oldest-first eviction. The ANSI report shows a
`result cache: X hit(s), Y miss(es), Z evicted` line per run. Full design
(schema namespace, eviction, overflow safety, `--target` normalization):
[Architecture -- Result caching](architecture.md#result-caching).

### `--verbose`

Print pipeline step diagnostics to stderr.

### `--help` and contextual `help`

`--help` prints all options, defaults, and examples to stdout, then exits. No
scanning or assessment is performed.

**Contextual help**: the `help` keyword prints flag/subcommand-specific text
instead of the full usage. The topic can be given in either order, with or
without the leading `--`:

```
adacovex help serve        # or: help --serve, --serve help
adacovex help standard     # standard / dal / asil / class
adacovex help sbom         # subcommands: sbom, prove, status, man
adacovex help theme        # every flag has a topic (port, target, ...)
adacovex help              # no topic: full usage
```

The topic is case-insensitive and an `=value` suffix is ignored
(`help --standard=all` == `help standard`). Unknown topics print the full
usage with an "Unknown topic" notice. Contextual help exits `0` and never
scans or assesses.

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
| `0` | Success (DAL achieved, all checks pass, `--version`, man page installed/up-to-date) |
| `1` | Compliance failure (DAL unmet, tests failing, a `--require-*` CI gate unmet, differential regression, `man --check` finding a newer version available or none installed, etc.) |

## NO_COLOR support

adacovex respects the `NO_COLOR` environment variable. If `NO_COLOR` is set,
ANSI color codes are suppressed in terminal output. Color is enabled by default.

## The `sbom` subcommand

`adacovex sbom` resolves the target project's dependency graph from its Alire
manifest, `alire/alire.lock`, and the root `.gpr` `with` clauses, then writes
a proof-aware software bill of materials in CycloneDX 1.5 JSON or SPDX 2.3
JSON. It is **standard-aware** (defaults to all standards), honors
`SOURCE_DATE_EPOCH` for byte-for-byte deterministic output, and is mutually
exclusive with `--compare-base` / `--coverage-delta`. Full detail (usage,
properties, determinism, exit codes):
[The `sbom` subcommand](sbom.md).

## Examples

```bash
# Self-assessment (strict mode, 100% docs required)
adacovex --target=.

# ISO 26262 assessment at ASIL B (dedicated flag)
adacovex --target=. --asil=B

# IEC 62304 assessment at safety Class A (dedicated flag)
adacovex --target=. --class=A

# ISO 26262 assessment at rigor tier C (ASIL B) via --standard
adacovex --target=. --standard=iso26262 --dal=C

# Emit badges for every standard at the shared tier
adacovex --target=. --standard=all

# Report toolchain + platform status
adacovex status --target=.

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

# Proof-aware SBOM (CycloneDX 1.5 JSON; all standards by default)
adacovex sbom --format=cyclonedx-json --target=. --dal=C
# SBOM for a single standard (ISO 26262 at ASIL B)
adacovex sbom --format=cyclonedx-json --target=. --asil=B
# SPDX 2.3 SBOM at IEC 62304 Class A
adacovex sbom --format=spdx-json --target=. --class=A --out=sbom.spdx.json

# Proof-aware SBOM (SPDX 2.3 JSON) at a custom path
adacovex sbom --format=spdx-json --out=docs/compliance/sbom.spdx.json
```
