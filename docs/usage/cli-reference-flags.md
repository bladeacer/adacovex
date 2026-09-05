# CLI flag details: assessment flags and subcommands

This page details the assessment flags (`--target`, `--dal`, `--standard`, and the rest), the `status` and `complexity` subcommands, the `prove` subcommand, and the per-file opt-out markers.  The flag summary table, exit codes, the `sbom` subcommand, and worked examples are on the [CLI reference](cli-reference.md); the output, serving, differential, and gate flags are on [CLI flag details: output and CI options](cli-reference-options.md).

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
under IEC 62304. See [DAL levels](../api-docs/adacovex-dal-levels.md) and
[Standards](standards.md).

### `--asil=LEVEL`

ISO 26262 Automotive Safety Integrity Level: `A`, `B`, `C`, `D`, or `QM`
(case-insensitive). It sets the standard to `iso26262` and maps the ASIL level
to the shared rigour tier (ASIL D -> DAL A, ASIL C -> DAL B, ASIL B -> DAL C,
ASIL A -> DAL D, QM -> DAL E). As a result, `--asil=B` is the clearest spelling
of "assess this project at ASIL B". See
[ASIL Levels](../api-docs/adacovex-asil-levels.md).

### `--class=LEVEL`

IEC 62304 software safety class: `A`, `B`, or `C` (case-insensitive). It sets
the standard to `iec62304` and maps the class to the shared rigour tier
(Class C -> DAL A, Class B -> DAL B, Class A -> DAL C). As a result,
`--class=A` is the clearest spelling of "assess this project at safety Class
A". See [Safety Classes](../api-docs/adacovex-class-levels.md).

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
languages, Markdown and reStructuredText included by default. `--excludes=EXT,EXT`
skips comma-separated file extensions (for example `--excludes=md,rst`) and only
works with the `complexity` subcommand. `--skip-path=PATH` skips any file
whose full path contains the given fragment and is repeatable; it is useful
for generated trees that are committed next to hand-written source (for example `--skip-path=docs/api-docs`). It prints
a tokei-style summary (files, lines, code, comments, blanks) plus a per-file
table of `Lines=`, `Code=`, `Comments=`, `Blanks=`, the codebase loc
percentage, and the cyclomatic complexity `cx=`.

The gate fails when a file or function exceeds the thresholds (defaults:
4 000 LOC, 10% of codebase per file, 120 per function, 600 per file).

Exit `0` when all gates pass. Exit `1` otherwise. This replaces the
previous Python `check-complexity.py` script. Maintainers wire the same gate
into their CI via `adacovex complexity --excludes=...`; see the
[developer guide](../contributing/developer-guide.md) for the workflow.

### The `prove` subcommand

`adacovex prove --target=PATH` resolves a gnatprove installation and runs it against the target. It then falls through to the normal assessment pipeline. The pipeline parses the freshly generated proof summary. As a result, one command both proves and assesses.

For the full guide to proving and writing SPARK proofs (contracts, VC categories, proof patches for vendored deps), see [Proving and writing proofs](../contributing/proving.md). gnatprove is resolved in this order: manifest pin > global pin > `$PATH` > cached toolchain > download. The target does not need to declare gnatprove. Full detail: [Architecture -- GNATprove toolchain resolution](../contributing/architecture.md#gnatprove-toolchain-resolution-prove-subcommand).

The proof summary is written to `<target>/obj/gnatprove/gnatprove.out` (the same location the assessment discovers). The SVG badges are emitted as usual. The result cache serves unchanged targets. `--force` bypasses the cache and forces a full gnatprove reanalysis. When the target carries proof patches (`.adacovex/patches/`), gnatprove runs against a patched tree copy at `<target>/obj/adacovex-proof/`.

Vendored dependencies then participate in the proof without their sources being touched. See [Proving and writing proofs](../contributing/proving-patches.md#proof-patches-proving-vendored-dependencies) for how to write them, and [Architecture -- Proof patches](../contributing/architecture-verification.md#proof-patches-spark-contracts-over-vendored-dependencies) for the design.

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
| `--args=FLAGS` | empty | Extra raw GNATprove flags passed through verbatim. The value is space-split into individual gnatprove arguments appended after the options above (for example `--args="--prover=cvc5 --timeout=5"`) |
| `--quiet` | on | Hide GNATprove's benign info messages (the default suppression set, the loop-unrolling/inlining notice blocks) from stdout. It is active by default for local runs. `--verbose` always shows every message and wins over it. CI passes `--verbose`, so CI output stays authoritative. This is the explicit form of the default |
| `--suppress-warnings` | on | Alias of `--quiet` (the default suppression set). Kept for compatibility |
| `--suppress-warnings=SETS` | on | Hide GNATprove info messages whose tags match the comma-separated suppression-set names (for example `--suppress-warnings=unrolling-inlining,xyz`). A set name `S` suppresses blocks tagged `[info-S]` (or bare `[S]`). `--verbose` always shows every message |

`prove` accepts all assessment flags too (`--dal`, `--standard`, the
`--require-*` gates, `--emit-svg`, and more), so CI gates apply to the proof
run directly. `--force` is shared with `man --force` (see below). The
remaining prove flags are validated only in prove mode.

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
