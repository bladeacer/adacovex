# CLI flag details: assessment flags and subcommands

This page details the assessment flags (`--target`, `--dal`, `--standard`, and the rest), the `status` and `complexity` subcommands, the `prove` subcommand, and the per-file opt-out markers. The flag summary table, exit codes, the `sbom` subcommand, and worked examples are on the [CLI reference](cli-reference.md); the output, serving, differential, and gate flags are on [CLI flag details: output and CI options](cli-reference-options.md).

## Flag details

### `--target=PATH`

Shorthand: `-t PATH` (or `-t=PATH`). Project to analyse. Relative paths
resolve against the current working directory. A leading `~` expands to your
home directory first; the shell never expands a tilde inside `--target=...`
(after `=` or in a quoted argument), and `~user` stays unchanged.

The path roots source scanning, manifest detection, SVG badge output, and
patch file resolution. Default: the current working directory.

### `--manifest=PATH`

Shorthand: `-m PATH`. Override the project manifest file. Auto-detected from
`<target>/alire-dev.toml` or `<target>/alire.toml` (dev first). The manifest
path is shown in stderr output and used by `adacovex sbom` to resolve the root
project metadata for the dependency graph.

### `--dal=LEVEL`

DO-178C DAL level (and the shared rigour tier): `A`, `B`, `C`, `D`, or `E`
(case-insensitive). It sets the minimum SPARK proof level and the criteria
checked; the tier is shared across standards.
`--dal=C` is DAL-C under DO-178C, ASIL B under ISO 26262, and safety Class A
under IEC 62304. See [DAL levels](../api-docs/adacovex-dal-levels.md) and
[Standards](standards.md).

### `--asil=LEVEL`

ISO 26262 Automotive Safety Integrity Level: `A`, `B`, `C`, `D`, or `QM`
(case-insensitive). It sets the standard to `iso26262` and maps the ASIL level
to the shared rigour tier (ASIL D -> DAL A, ASIL C -> DAL B, ASIL B -> DAL C,
ASIL A -> DAL D, QM -> DAL E). See
[ASIL Levels](../api-docs/adacovex-asil-levels.md).

### `--class=LEVEL`

IEC 62304 software safety class: `A`, `B`, or `C` (case-insensitive). It sets
the standard to `iec62304` and maps the class to the shared rigour tier
(Class C -> DAL A, Class B -> DAL B, Class A -> DAL C). See
[Safety Classes](../api-docs/adacovex-class-levels.md).

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

`--standard` also accepts a **combined standard + tier token**. The token
names the standard together with the rigour tier, so one flag replaces two:

- `dal-A`..`dal-E` -- DO-178C at that DAL tier
- `asil-A`..`asil-D`, `asil-QM` -- ISO 26262 at that ASIL
- `class-A`..`class-C` -- IEC 62304 at that class

The token is case-insensitive, and `-` and `_` are interchangeable
(`--standard=asil-b` == `--standard=ASIL_B` == `--asil=B`). An unknown value
is rejected loudly. `-l` is never a compliance tier: it is the GNATprove
proof level, so standard selection always stays on `--standard` and its
level companions.

When both a dedicated level flag (`--asil` / `--class`) and `--standard` are
passed, the dedicated flag sets the standard. `--standard` is ignored for
labelling (last-write-wins per field). The shared tier is always whatever the
level flag (or `--dal`) resolved to.

### `status`

`adacovex status [--target=PATH]` reports toolchain and platform state. It
runs no assessment and downloads or deploys nothing. It reports the following:

- whether Alire is installed
- the installation method of the running binary (`source-checkout`,
  `alire-global`, `on-path`) and its path
- how gnatprove is resolved
- the host CPU count and CI status (and the resulting default `-j`
  parallelism)
- a **VCS report** (which VCS tools are on `$PATH` and which manages the
  target -- see [VCS support](vcs.md))
- mandb availability
- the effective display timezone, the current date/time in it, and how many
  dated release changelogs the target carries

`adacovex status --tz=ZONE` (or `--timezone=ZONE`) overrides the display
timezone for the report. Exit `0` when a usable gnatprove is detectable
without a download.
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
languages, Markdown and reStructuredText included by default. `--excludes=EXT,EXT`
skips comma-separated file extensions (for example `--excludes=md,rst`) and only
works with the `complexity` subcommand. `--skip-path=PATH` skips any file
whose full path contains the given fragment and is repeatable; it is useful
for generated trees committed next to hand-written source (for example
`--skip-path=docs/api-docs`). It prints
a tokei-style summary (files, lines, code, comments, blanks) plus a per-file
table of `Lines=`, `Code=`, `Comments=`, `Blanks=`, the codebase loc
percentage, and the cyclomatic complexity `cx=`.

The gate fails when a file or function exceeds the thresholds (defaults:
4 000 LOC, 10% of codebase per file, 120 per function, 600 per file).

Exit `0` when all gates pass, `1` otherwise. Maintainers wire the same gate
into CI as `adacovex complexity --excludes=...`; the workflow is in the
[developer guide](../contributing/developer-guide.md).

### `spark-coverage`

`adacovex spark-coverage [--target=PATH]` reports SPARK proof coverage for
the target: statement, subprogram, and VC coverage as three separate metrics,
grouped by file, folder, or Ada package (`--group=file|folder|package`),
with the off breakdown (irreducible / I/O-bound / work queue) as separate
rows. It never runs the prover, so run `adacovex prove` first.
`--spark-format=json`
prints the machine-readable report. `--min-coverage=PCT` hides group rows
below a verified percentage from the display.

CI gate: `--require-coverage=PCT --gate-metric=statements|subprograms|vcs`
exits `1` when the named metric's proved share falls below the threshold
and names the metric, its numerator, its denominator, and the achieved
value. Exit `0` otherwise. The same gate ships in the GitHub Action as the
`require-coverage` / `gate-metric` inputs. A missing proof artefact set is a
loud `1`, never a silent `0`.

The two files come from a completed proof run: the summary
`obj/gnatprove/gnatprove.out` and its sibling
`obj/gnatprove/gnatprove.sarif`. The SARIF file (Static Analysis Results
Interchange Format, an [OASIS standard](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html))
holds one JSON result per reported check: the file, the line, the check
kind, and the message. Any SARIF consumer opens it without adacovex: an
editor plugin such as the SARIF Viewer extension for VS Code shows every
finding with clickable locations, and GitHub code scanning ingests it
through its `upload-sarif` action. `adacovex prove` writes and caches the
pair together, and the writing side is on
[Proving and writing proofs -- the SARIF report](../contributing/proving.md#the-sarif-report).

### The `prove` subcommand

`adacovex prove --target=PATH` resolves a gnatprove installation and runs it against the target. It then falls through to the normal assessment pipeline, which parses the fresh proof summary, so one command both proves and assesses.

For the full guide to proving and writing SPARK proofs (contracts, VC categories, proof patches for vendored deps), see [Proving and writing proofs](../contributing/proving.md). gnatprove is resolved in this order: manifest pin > global pin > `$PATH` > cached toolchain > download. The target does not need to declare gnatprove. Full detail: [Architecture -- GNATprove toolchain resolution](../contributing/architecture-dependencies.md#gnatprove-toolchain-resolution-prove-subcommand).

The summary is written to `<target>/obj/gnatprove/gnatprove.out` and the per-check report to its `gnatprove.sarif` sibling, the same locations the assessment and the `spark-coverage` report discover; the SVG badges are emitted as usual. The result cache stores both artefacts and restores both, so a warm run over a wiped `obj/gnatprove/` leaves the same pair a real run would; `--force` bypasses the cache and forces a full gnatprove reanalysis. When the target carries proof patches (`.adacovex/patches/`), gnatprove runs against a patched tree copy at `<target>/obj/adacovex-proof/`, and both artefacts are copied back to `<target>/obj/gnatprove/`.

Vendored dependencies then participate in the proof without their sources being touched. See [Proving and writing proofs](../contributing/proving-patches.md#proof-patches-proving-vendored-dependencies) for how to write them, and [Architecture -- Proof patches](../contributing/architecture-verification.md#proof-patches-spark-contracts-over-vendored-dependencies) for the design.

| Flag | Default | Description |
|------|---------|-------------|
| `--jobs=N`, `-j N` | auto | GNATprove parallelism: auto-detect (max(1, cores-2), all cores in CI), `0` = all cores, `N` = pin N processes |
| `--level=N`, `-l N` | tool default | GNATprove proof effort, 0-4 (never a compliance tier) |
| `--timeout=N` | tool default | Per-check prover timeout in seconds |
| `--steps=N` | `10000` | Max proof steps (reproducible budget, an explicit value overrides the default) |
| `--memlimit=N` | tool default | Prover memory limit in MB |
| `--force` | off | Force full gnatprove reanalysis (`-f`). Also bypasses the result cache |
| `--no-loop-unrolling` | always on | Disable automatic loop unrolling. Loop unrolling is always disabled, so GNATprove never emits the purely-informational `cannot unroll loop (too many loop iterations) [info-unrolling-inlining]` notice. It is proof-neutral for the dogfood targets (720/720 adacovex, 589/589 Ada_CRDT VCs, 0 unproved). Flag kept for compatibility |
| `--no-inlining` | off | Disable contextual analysis inlining |
| `--args=FLAGS` | empty | Extra raw GNATprove flags passed through verbatim. The value is space-split into individual gnatprove arguments appended after the options above (for example `--args="--prover=cvc5 --timeout=5"`) |
| `--quiet` | on | Hide GNATprove's benign info messages (the default suppression set, the loop-unrolling/inlining notice blocks) from stdout. It is active by default for local runs. `--verbose` always shows every message and wins over it. CI passes `--verbose`, so CI output stays authoritative. This is the explicit form of the default |
| `--suppress-warnings` | on | Alias of `--quiet` (the default suppression set). Kept for compatibility |
| `--suppress-warnings=SETS` | on | Hide GNATprove info messages whose tags match the comma-separated suppression-set names (for example `--suppress-warnings=unrolling-inlining,xyz`). A set name `S` suppresses blocks tagged `[info-S]` (or bare `[S]`). `--verbose` always shows every message |

`prove` accepts all assessment flags too (`--dal`, `--standard`, the
`--require-*` gates, `--emit-svg`, and more), so CI gates apply to the proof
run directly. `--force` is shared with `man --force` (see below); the
remaining prove flags validate only in prove mode.

### Per-file opt-out markers

A source, documentation, or data file can opt out of one adacovex analysis
gate with a marker in its **leading comment block** (the run of blank and
comment lines at the top of the file; the first non-comment line ends it):

| Marker | Effect |
|--------|--------|
| `no-covex-complexity-scan` | the file is excluded from the complexity/LOC gate |
| `no-covex-docstrings` | the file is excluded from the docstring-coverage metrics and the `--require-docstrings` gate |
| `no-covex-spark-proof` | the file's unit is excluded from the gnatprove run of `prove` (its checks no longer count against the proof metrics) |
| `no-covex-analysis` | all three above |

The marker sits on a comment line and follows the file's own comment
syntax, so the same marker text works in every language:

```ada
--  no-covex-complexity-scan
package Generated is
   ...
```

```markdown
<!-- no-covex-docstrings -->

# Generated reference page
```

Matching is case-insensitive. The `prove` opt-out marker belongs on the
unit's `.ads` spec; the body is excluded with it. The complexity and
prove opt-outs only take effect for files the root project actually scans
or proves, so markers on files outside the project are inert. Use these
sparingly: they are escape hatches for generated or vendored content, not a
substitute for documenting or proving real source.
