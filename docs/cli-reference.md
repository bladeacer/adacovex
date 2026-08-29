# adacovex CLI Reference

This page is the quick reference. It shows usage, the full flag table, and a
short note per flag. Feature-specific detail is in dedicated pages (linked
from each section):

- the [web dashboard](dashboard.md)
- the [`sbom` subcommand](sbom.md)
- [VCS support](vcs.md)
- the [platforms/`status`](platforms.md#status-subcommand) and
  [installation](installation.md) pages
- [Architecture](architecture.md) for design detail such as result caching and
  the patch system

## Usage

```
adacovex [options]
adacovex sbom [--format=cyclonedx-json|spdx-json|md] [--out=PATH]
           [--standard=NAME|--dal=LEVEL|--asil=LEVEL|--class=LEVEL]
adacovex prove [--target=PATH] [prove options]
adacovex status [--target=PATH]
adacovex man [--check|--force] [--dir=PATH]
adacovex completion [bash|fish|zsh|pwsh]
```

## Flags

| Flag | Default | Mode | Description |
|------|---------|------|-------------|
| `--target=PATH` | `.` (CWD) | both | Target project root directory |
| `--manifest=PATH` | auto-detected | both | Override project manifest path |
| `--dal=LEVEL` | `C` | both | DO-178C DAL level (A-E, also the shared rigour tier) |
| `--asil=LEVEL` | - | both | ISO 26262 level: `A`\|`B`\|`C`\|`D`\|`QM` |
| `--class=LEVEL` | - | both | IEC 62304 safety class: `A`\|`B`\|`C` |
| `--standard=NAME` | `do178c` | both | `do178c`\|`iso26262`\|`iec62304`\|`all` |
| `--serve` | off | both | Start HTTP dashboard server (standard-aware, light/dark/system themes) |
| `--serve-workers=N` | `4` | serve | HTTP server task-pool worker count |
| `--theme=NAME` | `system` | serve | Dashboard theme: `light`\|`dark`\|`system` |
| `--port=N` | `8080` | serve | Dashboard server port |
| `--tz=ZONE` / `--timezone=ZONE` | OS timezone | both | Display timezone (IANA name or UTC/GMT offset) |
| `--excludes=EXT,EXT` | empty | complexity | Skip comma-separated file extensions |
| `--emit-svg=PATH` | `<target>/docs/badges` | both | Output directory for SVG badges |
| `--no-svg` | off | both | Suppress SVG badge output |
| `--emit-markdown=PATH` | off | both | Output directory for Markdown reports |
| `--emit-metrics=PATH` | off | both | Write a JSON export of metrics + dependency graph to PATH |
| `--completion[=SHELL]` | - | - | Print shell completion script (bash/fish/zsh/pwsh, auto-detected) and exit |
| `--skip-dir=NAME` | `demo,deps,examples` | relaxed | Directory name to skip (repeatable) |
| `--relaxed` | off | both | Disable strict mode (skip dirs, no patches) |
| `--compare-base=REF` | off | both | Differential mode vs a base rev (git/hg/svn/fossil/jj) |
| `--coverage-delta=REF` | off | both | Docstring-coverage gate vs a base rev (git/hg/svn/fossil/jj) |
| `--cache` | on | both | Enable on-disk result caching |
| `--no-cache` | off | both | Disable result caching (always re-scan/re-parse/re-prove) |
| `--cache-dir=PATH` | `~/.adacovex/cache/<ver>/<schema>` | both | Cache directory for analysis results |
| `--cache-max=N` | `4096` | both | Max cache entries before oldest-first eviction |
| `--no-sbom` | off | both | Skip the automatic SBOM written at the end of every assessment |
| `--sbom-format=FMT` | `cyclonedx-json` | both | Format of the automatic SBOM: `cyclonedx-json`\|`spdx-json`\|`md` |
| `--require-spark=LVL` | off | both | Fail loudly (exit 1) if SPARK level < LVL (Stone..Platinum) |
| `--require-docstrings=PCT` | off | both | Fail loudly if docstring coverage < PCT% (0-100) |
| `--require-tests=N` | off | both | Fail loudly if passing test count < N |
| `--require-proof=PCT` | off | both | Fail loudly if proved-VC coverage < PCT% (0-100) |
| `--verbose` | off | both | Verbose diagnostics |
| `--version` | - | - | Print the bundled version and exit |
| `man` | - | - | Install the man page into the local man database |
| `man --check` | - | - | Exit 0 if the installed man page matches the binary version, 1 otherwise |
| `man --force` | - | - | Reinstall the man page even when it already matches (repair) |
| `man --dir=PATH` | `~/.local/share/man` | - | Install the man page under `PATH/man1` instead |
| `--help` | - | both | Print usage and exit |

`prove`-mode flags are also accepted by the main command. They are validated
only in prove mode. The flags are: `--jobs`/`-j`, `--level`, `--timeout`,
`--steps`, `--memlimit`, `--force`, `--no-loop-unrolling`, `--no-inlining`,
`--suppress-warnings`, `--quiet`. See
[The `prove` subcommand](#the-prove-subcommand).

## Flag details

### `--target=PATH`

Project to analyse. Relative paths are resolved against the current working
directory to an absolute path. The path determines the root directory for
source scanning, manifest detection, SVG badge output, and patch file
resolution. Default: the current working directory.

### `--manifest=PATH`

Override the project manifest file. Auto-detected from
`<target>/alire-dev.toml` or `<target>/alire.toml` (dev first). The manifest
path is shown in stderr output and used by `adacovex sbom` to resolve the root
project metadata for the dependency graph.

### `--dal=LEVEL`

DO-178C DAL level (and the shared rigour tier): `A`, `B`, `C`, `D`, or `E`
(case-insensitive). It determines the minimum SPARK proof level required and
the specific criteria checked. This tier is shared across standards.
`--dal=C` is DAL-C under DO-178C, ASIL B under ISO 26262, and safety Class A
under IEC 62304. See [DAL levels](api-docs/adacovex-dal-levels.md) and
[Standards](standards.md).

### `--asil=LEVEL`

ISO 26262 Automotive Safety Integrity Level: `A`, `B`, `C`, `D`, or `QM`
(case-insensitive). It sets the standard to `iso26262` and maps the ASIL level
to the shared rigour tier (ASIL D -> DAL A, ASIL C -> DAL B, ASIL B -> DAL C,
ASIL A -> DAL D, QM -> DAL E). As a result, `--asil=B` is the clearest spelling
of "assess this project at ASIL B". See
[ASIL Levels](api-docs/adacovex-asil-levels.md).

### `--class=LEVEL`

IEC 62304 software safety class: `A`, `B`, or `C` (case-insensitive). It sets
the standard to `iec62304` and maps the class to the shared rigour tier
(Class C -> DAL A, Class B -> DAL B, Class A -> DAL C). As a result,
`--class=A` is the clearest spelling of "assess this project at safety Class
A". See [Safety Classes](api-docs/adacovex-class-levels.md).

### `--standard=NAME`

Select the compliance standard used to label the assessment (default
`do178c`). The evidence checks are identical across standards. Only the
integrity-level names change in the report and badges:

- `do178c` -- DAL A--E (avionics)
- `iso26262` -- ASIL D / C / B / A / QM (automotive)
- `iec62304` -- Class C / B / A / no class (medical-device software)
- `all` -- run one assessment at the shared tier and emit badges/reports for
  every standard (`do178c.svg`, `iso26262.svg`, `iec62304.svg`)

Accepted case-insensitively, with or without the hyphen/space (`ISO-26262`,
`iec62304`, and more). See [Standards](standards.md) for the full tier
mapping.

When both a dedicated level flag (`--asil` / `--class`) and `--standard` are
passed, the dedicated flag sets the standard. `--standard` is ignored for
labelling (last-write-wins per field). The shared tier is always whatever the
level flag (or `--dal`) resolved to.

### `status`

`adacovex status [--target=PATH]` reports toolchain and platform state. It
does not run an assessment. It does not download or deploy anything. It
reports the following:

- whether Alire is installed
- how gnatprove is resolved
- the host CPU count and CI status (and the resulting default `-j`
  parallelism)
- a **VCS report** (which VCS tools are on `$PATH` and which manages the
  target -- see [VCS support](vcs.md))
- mandb availability
- the effective display timezone, the current date/time in it, and how many
  dated release changelogs the target carries

`adacovex status --tz=ZONE` (or `--timezone=ZONE`) overrides the display
timezone for the report. It shows the effective timezone, the current date
and time in that zone, and how many dated release changelogs the target
carries. Exit `0` when a usable gnatprove is detectable without a download.
Exit `1` otherwise; for full detail see
[Platforms -- `status` subcommand](platforms.md#status-subcommand).

`adacovex status --export` prints the report as machine-readable JSON on
stdout; `status --export=PATH` writes it to `PATH`. Scripts and CI can
consume it without parsing prose. `adacovex status --metrics` prints the
same data as compact `key=value` lines, one per line, for shell scripts.
Both flags only work with the `status` subcommand.

### `complexity`

`adacovex complexity [--target=PATH] [--excludes=EXT,EXT]` runs a
cyclomatic-complexity and LOC check across the target's source files in many
languages. `--excludes=EXT,EXT` skips comma-separated file extensions (for
example `md,rst`) and only works with the `complexity` subcommand. It prints
a tokei-style summary (files, lines, code, comments, blanks) plus a per-file
table of `Lines=`, `Code=`, `Comments=`, `Blanks=`, the codebase loc
percentage, and the cyclomatic complexity `cx=`. The gate fails when a file
or function exceeds the thresholds (defaults: 4 000 LOC, 10% of codebase per
file, 120 per function, 600 per file).

Exit `0` when all gates pass. Exit `1` otherwise. This replaces the
previous Python `check-complexity.py` script and is wired into
`make complexity-check`.

### The `prove` subcommand

`adacovex prove --target=PATH` resolves a gnatprove installation and runs it against the target. It then falls through to the normal assessment pipeline. The pipeline parses the freshly generated proof summary. As a result, one command both proves and assesses.

For the full guide to proving and writing SPARK proofs (contracts, VC categories, proof patches for vendored deps), see [Proving and writing proofs](proving.md). gnatprove is resolved in this order: manifest pin > global pin > `$PATH` > cached toolchain > download. The target does not need to declare gnatprove. Full detail: [Architecture -- GNATprove toolchain resolution](architecture.md#gnatprove-toolchain-resolution-prove-subcommand).

The proof summary is written to `<target>/obj/gnatprove/gnatprove.out` (the same location the assessment discovers). The SVG badges are emitted as usual. The result cache serves unchanged targets. `--force` bypasses the cache and forces a full gnatprove reanalysis. When the target carries proof patches (`.adacovex/patches/`), gnatprove runs against a patched tree copy at `<target>/obj/adacovex-proof/`.

Vendored dependencies then participate in the proof without their sources being touched. See [Proving and writing proofs](proving.md#proof-patches-proving-vendored-dependencies) for how to write them, and [Architecture -- Proof patches](architecture.md#proof-patches-spark-contracts-over-vendored-dependencies) for the design.

| Flag | Default | Description |
|------|---------|-------------|
| `--jobs=N`, `-j N` | auto | GNATprove parallelism: auto-detect (max(1, cores-2), all cores in CI), `0` = all cores, `N` = pin N processes |
| `--level=N` | tool default | GNATprove proof effort, 0-4 |
| `--timeout=N` | tool default | Per-check prover timeout in seconds |
| `--steps=N` | `10000` | Max proof steps (reproducible budget, an explicit value overrides the default) |
| `--memlimit=N` | tool default | Prover memory limit in MB |
| `--force` | off | Force full gnatprove reanalysis (`-f`). Also bypasses the result cache |
| `--no-loop-unrolling` | always on | Disable automatic loop unrolling. Loop unrolling is always disabled, so GNATprove never emits the purely-informational `cannot unroll loop (too many loop iterations) [info-unrolling-inlining]` notice. It is proof-neutral for the dogfood targets (720/720 adacovex, 589/589 Ada_CRDT VCs, 0 unproved). Flag kept for compatibility |
| `--no-inlining` | off | Disable contextual analysis inlining |
| `--quiet` | on | Hide GNATprove's benign info messages (the default suppression set, the loop-unrolling/inlining notice blocks) from stdout. It is active by default for local runs. `--verbose` always shows every message and wins over it. CI passes `--verbose`, so CI output stays authoritative. This is the explicit form of the default |
| `--suppress-warnings` | on | Alias of `--quiet` (the default suppression set). Kept for compatibility |
| `--suppress-warnings=SETS` | on | Hide GNATprove info messages whose tags match the comma-separated suppression-set names (for example `--suppress-warnings=unrolling-inlining,xyz`). A set name `S` suppresses blocks tagged `[info-S]` (or bare `[S]`). `--verbose` always shows every message |

`prove` accepts all assessment flags too (`--dal`, `--standard`, the
`--require-*` gates, `--emit-svg`, and more), so CI gates apply to the proof
run directly. `--force` is shared with `man --force` (see below). The
remaining prove flags are validated only in prove mode.

### Automatic SBOM (`--no-sbom` / `--sbom-format`)

Every assessment writes a proof-aware SBOM by default (the pipeline's last
step): `<target>/sbom.json` (CycloneDX 1.5), `<target>/sbom.spdx.json`
(SPDX 2.3), or `<target>/docs/compliance/SBOM.md` depending on
`--sbom-format` (default `cyclonedx-json`). `--no-sbom` skips it entirely.
These are separate from the dedicated [`sbom` subcommand](sbom.md), which
writes a single SBOM at an explicit path and exits.

### `--serve`

A **switch**: when given, adacovex scans and assesses the target, then starts the built-in HTTP/1.1 web dashboard on `--port` (default `8080`) and blocks until interrupted. Passing `--serve` is the only way to start the server; omitting it (the default, `off`) renders and exits without serving. There is no `--no-serve`, because the flag already controls it. It serves an HTML dashboard at `/`, a JSON API at `/api/metrics`, the SVG badges at `/badge/*.svg`, and the bundled offline manual at `/docs`.

The dashboard is standard-aware (it defaults to all standards) and supports light, dark, and system themes.

Full detail, the JSON schema, the theme-resolution order, and embedding tips are in [Web dashboard and JSON API](dashboard.md). Related flags: `--port`, `--serve-workers`, `--theme`.

### `--theme=NAME`

Dashboard colour theme for `--serve`: `system` (default, follows `prefers-color-scheme`), `light`, or `dark` (case-insensitive). It sets the initial dropdown selection in the served page. The header dropdown can switch live afterwards, and **Save settings** persists the choice in `localStorage` (no cookies). Only relevant with `--serve`.

See [dashboard themes](dashboard.md#themes).

### `--port=N`

HTTP server port when `--serve` is used. Must be a valid `Positive` integer.
Only relevant with `--serve`.

### `--serve-workers=N`

HTTP server task-pool worker count when `--serve` is used. Default is `4`.
Raise it to handle more concurrent dashboard requests, or lower it to use
less memory. It must be a valid `Positive` integer and only works with
`--serve`.

### `--tz=ZONE` / `--timezone=ZONE`

Display timezone for the status report.  Accepts a well-known IANA name
(for example `Asia/Singapore`) or a fixed UTC/GMT offset (`UTC+8`, `GMT+8`,
`UTC+08`, `GMT+08`, `UTC+08:30`).  Without it adacovex uses the operating
system's timezone.

A named zone resolves from a built-in table of common IANA names.  A zone
that may observe daylight saving time, or one the table lacks, is probed
against the platform tzdata (`zdump` + `date +%z`) for the DST-correct
current offset, with the table as the fallback when the probe is
unavailable.  Values are matched case-insensitively, and a bad value fails
loudly.

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

### `--emit-metrics=PATH`

After the assessment, it writes a machine-readable JSON export to `PATH`:
`{"metrics": {...}, "dependencies": {...}}`.  `metrics` is the same
object the dashboard JSON API serves at `/api/metrics`.  `dependencies` is
the resolved dependency graph (name, version, scope, parent, purl, kind) at
`/api/deps`.  It is useful for scripting gates, external dashboards, or
archiving assessment results. The composite GitHub Action uploads it as a CI
artifact when `emit-metrics` is set.

### `--emit-markdown=PATH`

Write compliance reports to a directory. Creates two files:

- `VERIFICATION.md` -- full verification report with all metrics
- `TRACE.md` -- HLR traceability matrix (source-to-requirement mapping)

### `--skip-dir=NAME`

Add a directory name to the scanner's skip list (repeatable). Directories whose
simple name matches an entry are not recursed into during source scanning.
Only effective in relaxed mode. In strict mode (default) the skip list is
always empty.

### `--relaxed`

Disable strict mode. Enables the skip list (default `demo,deps,examples` plus
any `--skip-dir` entries) and does NOT apply `.adacovex/patches/`. See
[Strict vs relaxed mode](#strict-vs-relaxed-mode).

### `--compare-base=REF`

Differential mode: snapshot a base revision and print a side-by-side comparison against the current tree (packages, subprograms, docstring %, HLR traced, orphan tags, SPARK level, VCs proved, tests, DAL status). Exit `0` only if there are no regressions AND the current DAL is Achieved. Exit `1` otherwise. Works on **git, Mercurial, Subversion, Fossil, and jj**.

Full detail and the per-VCS snapshot mechanisms are in [VCS support and differential assessment](vcs.md).

### `--coverage-delta=REF`

Lightweight docstring-coverage gate for PR-style CI checks. Scans sources + patches + computes docstring metrics on both a base revision and the current tree (no GNATprove/tests/DAL), prints a compact coverage table plus a machine-parseable `coverage_delta:` line, and cleans up the snapshot. Exit `0` if current docstring coverage is `>=` the base. Exit `1` if coverage regressed.

Mutually exclusive with `--compare-base`. See [VCS support and differential assessment](vcs.md).

### `--version`

Print the bundled version (`adacovex vX. Y. Z`) and exit, without scanning or assessing. The version source depends on the **installation method** (`ADACOVEX_VERSION` for release builds, `alire-dev.toml` for source checkouts, `alire.toml` for dependency-managed installs).

The same constant drives the man page, the SBOM tool version, and the result-cache namespace. As a result, they cannot drift. Full detail: [Installation -- version source](installation.md#version-source-per-installation-method).

### `completion`

`adacovex completion [SHELL]` (also `adacovex --completion[=SHELL]`) prints
a static shell-completion script to stdout and exits.  `SHELL` is one of
`bash`, `fish`, `zsh`, `pwsh`, when omitted it is auto-detected from
`$SHELL`, falling back to bash for unknown or empty shells.  Typical setup:

```bash
eval "$(adacovex completion)"        # bash (default)
source <(adacovex completion zsh)    # zsh
adacovex completion fish | source    # fish
adacovex completion pwsh | Invoke-Expression   # PowerShell
```

The scripts complete the subcommands and every long flag from the binary's
own flag table, so the completion set cannot drift from the CLI. The flag
list embeds at generation time. Re-run `adacovex completion` after upgrading
adacovex (a shell prompt hook that regenerates on version change works well).

### `man`

The `man` subcommand installs the adacovex man page into the **local man
database** (Linux/WSL, no root required) and refreshes the index with `mandb`
when present. `adacovex man --check` exits 0 when the installed page matches
the binary. It exits 1 otherwise (a shell prompt hook can auto-update as a
result). `--dir=PATH` overrides the install root. Full detail, exit codes,
and the prompt-hook recipe are in
[Installation -- keeping the man page in sync](installation.md#keeping-the-man-page-in-sync).

### VCS support

**A version control system is not required for base adacovex functionality**
(scanning, proof analysis, test parsing, compliance assessment, SBOM generation, dashboards, caching). A VCS is only needed for the differential modes (`--compare-base` / `--coverage-delta`). Those modes snapshot a base revision across **git, Mercurial, Subversion, Fossil, and jj** without touching the working tree. Detection is marker-file based (`.git` / `.jj` / `.hg` / `.svn` / `.fslckout` / `_FOSSIL_`) with a command-probe fallback.

Full detail, the snapshot mechanism per VCS, and the Subversion/Fossil UX notes are in [VCS support and differential assessment](vcs.md).

### CI threshold gates (`--require-*`)

The four `--require-*` flags add explicit minimum-bar checks on top of the DAL
criteria. They are off by default. When set, the assessment fails loudly
(exit code `1`, with an explicit `CI GATE:` reason printed to the report) if the
target does not meet the required level:

```bash
adacovex --target=. --require-spark=Platinum --require-docstrings=100 \
         --require-tests=1173 --require-proof=100
```

- `require-spark` compares the honest assessed SPARK level (Stone..Platinum).
- `require-docstrings` and `require-proof` take a percentage (0-100).
- `require-tests` takes a count of passing tests.

CI that pins a gnatprove version (manifest or global `adacovex.toml` pin)
must set these to the values that version actually achieves. A stricter
prover can legitimately leave more VCs unproved. As a result, gate on the
results of the prover you pin.

### Result caching (`--cache` / `--no-cache` / `--cache-dir` / `--cache-max`)

adacovex persists parsed analysis results on disk, so unchanged inputs are not re-scanned, re-parsed, or re-proved. Every entry is keyed by a namespace prefix plus the SHA-256 of the artifact(s) it was derived from. An unchanged manifest/lockfile/.gpr set serves the cached dependency graph. Unchanged HLR.md/LLR.md serve the cached requirement parses. `--no-cache` bypasses it entirely. `--cache-dir` relocates it. `--cache-max` (default `4096`) caps entries before oldest-first eviction.

The ANSI report shows a `result cache: X hit(s), Y miss(es), Z evicted` line per run. Full design (schema namespace, eviction, overflow safety, `--target` normalization) is in [Architecture -- Result caching](architecture.md#result-caching).

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
| Patch files | Applied from `.adacovex/patches/` (docstrings always, SPARK proof aspects in prove mode) | Not applied |
| Use case | Full compliance audit | Quick assessment of production code |

Patch files can carry more than docstrings. A patch with `SPARK_Mode` /
`Pre` / `Post` / `Global` aspects is a **proof patch** that adds SPARK
contracts to vendored code in prove mode (spec patches `.ads`, and body
patches `.adb` opt the vendored body into the proof). Why they exist, how
to write them, worked examples, and pitfalls are in
[Proving and writing proofs -- proof patches](proving.md#proof-patches-proving-vendored-dependencies).

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success (DAL achieved, all checks pass, `--version`, man page installed/up-to-date) |
| `1` | Compliance failure (DAL unmet, tests failing, a `--require-*` CI gate unmet, differential regression, `man --check` finding a newer version available or none installed, and more) |

## Terminal colour

adacovex colours its terminal output (red for failures, green for passes,
bold for headings) so the important lines stand out.  Colour is enabled by
default on a normal terminal.  It is suppressed automatically when the
output would not take it:

- `NO_COLOR` is set (the cross-tool opt-out convention);
- a CI variable is set (GitHub Actions, GitLab CI, and more), so CI logs
  stay plain and machine-readable;
- `TERM` is `dumb` (or set to an empty value).

## The `sbom` subcommand

`adacovex sbom` resolves the target project's dependency graph from its Alire
manifest, `alire/alire.lock`, and the root `.gpr` `with` clauses, then writes
a proof-aware software bill of materials in CycloneDX 1.5 JSON or SPDX 2.3
JSON. It is **standard-aware** (it defaults to all standards), honours
`SOURCE_DATE_EPOCH` for byte-for-byte deterministic output, and is mutually
exclusive with `--compare-base` / `--coverage-delta`. Full detail (usage,
properties, determinism, exit codes) is in
[The `sbom` subcommand](sbom.md).

## Examples

```bash
# Self-assessment (strict mode, 100% docs required)
adacovex --target=.

# ISO 26262 assessment at ASIL B (dedicated flag)
adacovex --target=. --asil=B

# IEC 62304 assessment at safety Class A (dedicated flag)
adacovex --target=. --class=A

# ISO 26262 assessment at rigour tier C (ASIL B) via --standard
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
