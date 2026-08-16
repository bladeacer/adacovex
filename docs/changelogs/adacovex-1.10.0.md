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

### C7: Dedicated per-standard level flags and `--standard=all`

The shared `--dal=LEVEL` tier is complemented by dedicated level flags that
spell each standard's integrity level in its own naming: `--asil=LEVEL`
(`A|B|C|D|QM`, ISO 26262) and `--class=LEVEL` (`A|B|C`, IEC 62304). Each sets
both the compliance standard and the shared tier, so `--asil=B` is the
unambiguous spelling of "assess at ASIL B" (tier C) and `--class=A` of
"assess at safety Class A". `--standard=all` runs one assessment at the shared
tier and emits badges for every standard (`do178c.svg`, `iso26262.svg`,
`iec62304.svg`) plus a per-standard breakdown in the ANSI report, HTML
dashboard, JSON API, and Markdown report, without re-scanning or re-proving.
The CLI parser's argument loop was extracted into a testable `Parse_Args`
entry point (a plain argument vector, no `Ada.Command_Line` access) so the
last-write-wins precedence across `--dal` / `--asil` / `--class` /
`--standard` is covered by unit tests.

### C8: Standard-aware SBOM and renderers

The proof-aware SBOM now records the assessment standard and its native level
label alongside the shared tier: the root component carries
`adacovex:standard` (`DO-178C` / `ISO 26262` / `IEC 62304`) and
`adacovex:level` (`DAL-C` / `ASIL B` / `Class A`), in addition to the existing
`adacovex:proof_level` and `adacovex:dal_target` properties (CycloneDX
properties, SPDX `attributionTexts`, and the Markdown table). The HTML
dashboard, JSON API, and Markdown `VERIFICATION.md` now print the
standard-specific level label and the `--standard=all` per-standard
breakdown; the ANSI report and SVG badges already did.

### C9: Per-standard reference pages

Each standard now has a dedicated reference page mirroring the existing
DO-178C one: `docs/api-docs/adacovex-asil-levels.md` (ISO 26262 ASIL A--D/QM
level definitions, criteria, and tier mapping) and
`docs/api-docs/adacovex-class-levels.md` (IEC 62304 safety classes A--C).
Both are linked from the README documentation table, the CLI reference, and
`docs/standards.md`.

### C10: SBOM emits every standard under `--standard=all`

The proof-aware SBOM is now fully standard-aware end to end. A single
standard writes `adacovex:standard` / `adacovex:level` for just that standard
(`--asil=B` -> `ISO 26262` / `ASIL B`; `--class=A` -> `IEC 62304` /
`Class A`). Under `--standard=all` the same two properties carry the joined
values for every standard -- `adacovex:standard = DO-178C, ISO 26262,
IEC 62304` and `adacovex:level = DAL-C / ASIL B / Class A` -- across
CycloneDX, SPDX `attributionTexts`, and the Markdown table, while
`adacovex:dal_target` keeps the shared tier. Two new helpers
(`All_Standards_Property`, `All_Levels_Property`) drive the joined output,
and `Standard_Level_Name` now posts its tight 1..8 length bound.

### C11: CI feature parity with the multi-standard set

The composite action gained `standard` / `asil` / `class` inputs (threaded
through to the assessment as `--standard` / `--asil` / `--class`, with
`--dal` still the shared tier) and now parses the compliance status from the
standard-specific label (`DAL-X`, `ASIL X`, `QM`, or `Class X`) instead of
only `DAL-X`. `ci.yml` now runs three jobs: an `--standard=all`
self-assessment, the native test suite and a push-only `make coverage-gate`
release-tag docstring gate. `pr-check.yml` and `release.yml` also pass
`standard: all`, so PRs gate coverage across standards and releases emit all
three compliance badges.

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

501 tests (was 395). The types category gained 23 checks for the dedicated
level parsers (`To_ASIL`, `Is_Valid_ASIL`, `To_Class`, `Is_Valid_Class`) and
`Standard_Slug`; the CLI-config category gained 31 checks (the `Standard_All`
default plus 30 flag-precedence checks driven through the new `Parse_Args`
entry point); the SVG category gained six checks for the
standard-parameterized `Render_Compliance_Badge`; the SBOM category gained 29
checks (18 for the single-standard standard/level properties plus 11 for the
all-standards joined properties); and a new HTML/Markdown renderer category
(17 checks) covers standard-aware dashboard, JSON, and Markdown output.
Total categories: 10 (was 9).

## Proof Results

Platinum, 401/401 VCs proved across 39 analyzed units (was 343 at 1.9.0). The
compliance-standard layer (`Compliance_Standard`, `To_Standard`,
`Standard_Level_Name`, `Standard_Slug`, `To_ASIL`, `To_Class`) and the SBOM
`Level_Property` / `All_Standards_Property` helpers added 58 SPARK VCs, all
discharged. The `prove` subcommand's
default proof budget was raised from `--steps=5000` to `--steps=10000` because
5000 sat on the solver's non-determinism boundary for the enlarged unit; an
explicit `--steps=...` still overrides it. Changed scanner files remain
non-SPARK (`Adacovex.Parsers.Source`).

## Traceability

No new HLRs. Source scanning remains covered by the existing `-- HLR-SCAN`
tag in `src/parsers/adacovex-parsers-source.ads`; the new standard-aware
assessment and renderers reuse the existing `HLR-COMPLIANCE` /
`HLR-DAL-A..E` / `HLR-SBOM` / `HLR-RENDER-*` tags.
