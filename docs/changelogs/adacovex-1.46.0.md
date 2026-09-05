# adacovex 1.46.0

Date: _2026-09-05_

Version bumped 1.45.0 -> 1.46.0.

## Changes

### C1: Complexity gate scans Markdown

`make complexity-check` and the `complexity` subcommand now cover Markdown
files by default. The gate previously ran with `--excludes=md,rst`, so the
docs tree contributed nothing to the per-file LOC and codebase-percentage
caps. The gate now scans every supported language including Markdown
(`--excludes=rst --skip-path=docs/api-docs` in the Makefile): a
hand-written page that outgrows its share of the codebase now fails the
gate like any other source file. The generated API reference stays
excluded (it is produced by `make doc`, never hand-authored), and
reStructuredText stays excluded for the same reason.

### C2: `complexity --skip-path` per-path exclusion

`adacovex complexity --skip-path=PATH` excludes any file whose full path
contains the given fragment. The flag is repeatable and comma-tolerant, and
it only works with the complexity subcommand (like `--excludes`). It is
the escape hatch for generated or vendored trees committed next to
hand-written source -- for example `--skip-path=docs/api-docs` -- where an
extension-based exclusion would be too broad.

### C3: Per-file opt-out markers (`no-covex-*`)

Any source, documentation, or data file can opt out of an analysis gate
with a marker in its leading comment block (the run of blank and comment
lines at the top; the first non-comment line ends it):

- `no-covex-complexity-scan` excludes the file from the complexity/LOC gate;
- `no-covex-docstrings` excludes it from the docstring-coverage metrics and
  the `--require-docstrings` gate;
- `no-covex-spark-proof` excludes the file's unit from the gnatprove run of
  `adacovex prove` (its checks no longer count against the proof metrics);
- `no-covex-analysis` is the umbrella form that sets all three.

The marker is a comment line in the file's own syntax (`--`, `#`, `//`,
`<!--`, ...), so the same marker text works in Ada, Markdown, Python,
Rust, and every other scanned language. Matching is case-insensitive.
The markers are honoured by a new zero-dependency helper unit
(`Adacovex.Opt_Outs`) shared by the complexity checker, the Ada source
scanner, and the prove runner.

### C4: Proof opt-outs run gnatprove with `-u`

When a root-project unit carries `no-covex-spark-proof`, `adacovex prove`
lists every project unit except the opted-out ones after gnatprove's `-u`
switch, so the excluded unit is not analysed and its checks never appear in
`gnatprove.out`. The marker belongs on the unit's `.ads` spec; the body is
excluded with it. Membership is derived from the root `.gpr`'s literal
`Source_Dirs` (gnatprove rejects `-u` paths outside the project); a project
whose `Source_Dirs` use variables or concatenation is proved whole with a
warning. The marker lives in file content, which is part of the prove input
hash, so the result cache always reflects the current opt-out set.

### C5: `prove --args` raw gnatprove passthrough

`adacovex prove --args="..."` forwards extra raw GNATprove flags verbatim:
the value is space-split into individual gnatprove arguments appended after
the option list the prove subcommand builds (jobs, steps, unrolling, ...).
Repeats accumulate. The action input `prove-args` drives the same flag in
CI, and the docs/usage/ci-cd.md `### Inputs` table documents it.

### C6: SIMD and optimisation review

`docs/contributing/perf.md` records a 1.46.0 review of SIMD and other
low-level optimisation candidates. The measurements show the pipeline is
I/O- and cache-bound, not compute-bound (a cold self-assessment is ~76 ms,
a warm one ~36 ms on an unoptimised local build), and a `prove` run is
dominated by the gnatprove solver floor. No SIMD or assembly is added; the
per-byte scanning loops are the only candidates and they gain little from
auto-vectorisation on short lines. The documented speed path stays the
existing one: `-O2` release builds, the shared directory-snapshot memo,
and the content-hashed result cache.

## Test Suite

The native suite grows from 1229 to 1235 tests across 17 categories, all
passing. CLI-config tests pin the new flag contracts: `--skip-path`
requires the complexity subcommand and accumulates comma-separated, and
`--args` requires the prove subcommand and accumulates space-joined raw
gnatprove flags.

## Proof Results

Platinum, 0 unproved, 0 justified, 876 VCs (876 proved) under gnatprove
16.1.0 across 57 analysed units. The new opt-out detection unit, the
scanner flag fields, and the config/prove plumbing live in default-mode
code (the same rule as the parsers and the I/O-heavy bodies), so no new VC
surface is introduced and no justified VCs appear.

## Traceability

- No new HLRs. The release adds opt-out markers, gate exclusions, and a
  raw flag passthrough; the existing tags below cover it.
- `HLR-CLI` -- C2 `--skip-path`, C5 `--args` (Known_Flags, Parse_Args,
  usage, and topic help).
- `HLR-SCAN` -- C3 the `Adacovex.Opt_Outs` marker detector and the
  docstring opt-out in the source scanner (C3/C4).
- `HLR-PROVE` -- C4 the `-u` proof opt-outs and C5 the `--args`
  passthrough in the prove runner.
- `HLR-COMPLEXITY` -- C1 Markdown scanning, C2 `--skip-path`, C3 the
  complexity opt-out marker.
- `HLR-METRICS` -- C3 the `no-covex-docstrings` exclusion from the
  docstring-coverage metrics.
- `HLR-ARCH` -- C6 the SIMD/optimisation review documentation and the
  AGENTS.md/docs refresh.
