# adacovex 1.10.0

Date: _2026-08-15_
Version bumped 1.9.0 -> 1.10.0.

## Changes

### C1: Multi-standard compliance abstraction (ISO 26262 / IEC 62304)

One assessment can now satisfy DO-178C, ISO 26262, and IEC 62304 at the same
time. A new `docs/standards.md` page maps the three standards' integrity levels
(DAL A--E, ASIL A--D/QM, and safety classes A--C) onto a shared rigor tier
with the same four evidence checks adacovex already computes: HLR
traceability, no orphan tags, passing tests, and a minimum SPARK level.

Implemented via a `Compliance_Standard` type (`DO_178C`, `ISO_26262`,
`IEC_62304`) with `To_String` / `To_Standard` conversions, a
`Standard_Level_Name` level re-labelling function, and a `--standard=NAME` CLI
flag (default `do178c`) that reuses `--dal=LEVEL` as the shared rigor tier. A
new `Assess_Standard` procedure runs the same evidence checks as `Assess_DAL`
and records the standard, so the ANSI report and SVG badge print "ASIL B" /
"Class A" instead of "DAL-C".

### C2: Metric-sync tooling for test counts and SPARK level

Hardcoded test counts and SPARK-level gates now have a script to keep them in
sync, matching the existing proof-status script for VC counts. A new
`tools/update-test-count.py` parses `docs/test_result.md`, rewrites the
anchored test-count phrases across AGENTS.md, README.md, Makefile, the CI
workflows, and `agents-tree.map`, then regenerates the AGENTS.md source tree.
`tools/update-proof-status.py` additionally rewrites the `--require-spark` /
`require-spark` CI gates in the Makefile, workflows, and docs.

### C3: Source scanner recognizes OOP modifiers and word boundaries

The scanner's `Is_Subprogram_Decl` now understands `overriding` and
`not overriding` subprogram declarations in addition to plain, generic, and
function forms, and tab-indented declarations are handled.

### C4: Root CONTRIBUTING.md

The contribution guide moved to a root-level `CONTRIBUTING.md` so GitHub
renders its contributing link; the changelog format and unit-test catalog live
there.

### C5: `adacovex status` subcommand

A new `adacovex status` subcommand reports the toolchain + platform state
without running an assessment and without downloading or deploying anything:
whether Alire (`alr`) is installed, whether gnatprove is dependency-managed
(target manifest pin) or detectable (global pin, on `$PATH`, or cached in
`~/.adacovex/toolchain`), the host logical-CPU count and CI status, and the
resulting default GNATprove parallelism. It also prints the release-note that
the CI binary is Linux x86-64 only.

### C6: Platform-support documentation

A new `docs/platforms.md` page documents the supported platforms (Linux as
primary, macOS/FreeBSD/Windows from source), the CPU core-count detection
order (`/proc/cpuinfo`, `sysctl`, `nproc`, `NUMBER_OF_PROCESSORS`, PowerShell),
CI detection, prove parallelism resolution, and the Linux-only release binary.

## Fixes

### H1: Scanner false positives on identifier prefixes

`Is_Subprogram_Decl` matched `procedure` / `function` as a bare prefix, so a
line such as `functionality : Integer := 0;` was counted as a subprogram
declaration. Keyword matching now requires a word boundary, so identifiers
that merely begin with a keyword no longer inflate subprogram and docstring
counts.

### H2: Subprogram names merged with `return`

The name extractor stripped all blanks, so a parameterless function like
`function Value return Integer;` recorded the name `Valuereturn`. Name
extraction now works on the raw line and stops at the keyword boundary,
producing `Value`.

## Test Suite

395 tests (was 372). The source-scanner category gained four checks covering
word-boundary rejection of keyword-prefixed identifiers and `overriding` /
`not overriding` declaration parsing; the types category gained 18 checks for
the compliance-standard conversions and `Standard_Level_Name` mapping; the DAL
category gained four checks for `Assess_Standard`; and the CLI-config category
gained a check for the `Standard_Target` default.

## Proof Results

Platinum, 369/369 VCs proved across 38 analyzed units (was 343 at 1.9.0). The
new compliance-standard layer (`Compliance_Standard`, `To_Standard`,
`Standard_Level_Name`, `To_String`) added 26 SPARK VCs, all discharged. The
`prove` subcommand's default proof budget was raised from `--steps=5000` to
`--steps=10000` because 5000 sat on the solver's non-determinism boundary for
the enlarged unit; an explicit `--steps=...` still overrides it. Changed
scanner files remain non-SPARK (`Adacovex.Parsers.Source`).

## Traceability

No new HLRs. Source scanning remains covered by the existing `-- HLR-SCAN`
tag in `src/parsers/adacovex-parsers-source.ads`; the new standard-aware
assessment reuses the existing `HLR-COMPLIANCE` / `HLR-DAL-A..E` tags.
