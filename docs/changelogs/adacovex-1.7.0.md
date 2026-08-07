# adacovex 1.7.0

Date: _2026-08-07_

Version bumped 1.6.0 -> 1.7.0.

## Changes

### C1: Explicit overflow handling -- no silent partial parses

A physical line longer than `Max_Line` (262144 bytes on 64-bit) was previously
silently truncated by the source scanner: the tail of the line was drained and
discarded, and the remaining (partial) line was parsed as if it were the whole
line. GNATprove, test-result, HLR/LLR, and manifest parsers had a related bug
-- a full buffer was drained for the *next* physical line, misreading the
following content. Both behaviors could silently produce wrong metrics.

All parsers now share an overflow-aware `Read_Line` helper on the
`Adacovex.Parsers` parent package:

- **Exact detection.** A line that fills the buffer exactly (end-of-line
  reached) parses normally. A line that genuinely exceeds the buffer is
  detected via `End_Of_Line`, drained, and reported to stderr as
  `Error: <path>:<line>: line exceeds Max_Line buffer (<N> bytes)`.
- **Explicit failure, never partial output.** The scanner stops parsing the
  offending file (no partial AST), and the GNATprove / test-result / HLR/LLR
  parsers clear their output and fail. The manifest, lockfile, and GPR
  parsers abort dependency-graph resolution.
- **DAL is forced Unmet.** `Scan_Project` returns a new `Skipped_Ct`; when any
  source file is skipped, the assessment appends `"N source file(s) skipped:
  line exceeds Max_Line"` to the DAL failure reasons, sets the status to
  `Unmet`, and exits 1 -- no compliance claim can be made for unread code.
- **Paths over `Max_Path` are reported and skipped** instead of raising
  `Constraint_Error`; `Push_Dir` warns on over-long directory paths rather
  than silently dropping them.
- **Differential modes.** `--compare-base` and `--coverage-delta` gain a
  `Skipped` field; a current tree with skipped sources is always a
  regression, and the diff reports `sources skipped`.
- **Auto-SBOM exit-code fix.** The automatic SBOM emission no longer resets
  the assessment exit code to 0 on success (it now never touches `Exit_St`),
  so a DAL failure is reported correctly even when an SBOM is written.

### C2: Proof scope and justification policy (docs + reporting)

- **Proof scope is the target's own units.** GNATprove `Units_Analyzed` and
  `Units_Skipped` were parsed but never surfaced; they now appear in the ANSI
  report and in `VERIFICATION.md`. Skipped units (standard library / vendor
  code that GNATprove does not analyze) are explicitly out of proof scope, not
  a proof failure.
- **Justifications never downgrade the level.** A `Total` row's `Justified`
  count is counted neither as proved nor as unproved
  (`Proved = Total - Justified - Unproved`), and only unproved VCs cap the
  SPARK level. Pinned by new unit tests.
- **Gold is the minimum compliance baseline; Platinum is the ideal.** The
  `Min_SPARK_For` thresholds are unchanged (A=Gold, B=Silver, C=Bronze,
  D/E=Stone); the API docs that previously claimed A=Platinum / B=Gold were
  corrected to match the code, and the proof-scope / justification policy is
  documented as an architecture decision.

## Test Suite

Suite extended from 295 to **320 tests**: source scanner (68 -> 76, incl.
over-Max_Line rejection, exact-buffer-fit acceptance, and `Skipped_Ct`),
GNATprove parser (38 -> 52, incl. justified-VCs-keep-Platinum, units
analyzed/skipped parsing, and overflow rejection), and test-result parser
(40 -> 43, incl. overflow rejection). All 320 pass.

## Proof Results

Self-assessment remains **Platinum** (all VCs proved, 0 unproved, AoRTE-free).
The new `Adacovex.Parsers.Read_Line` helper body is a non-SPARK unit (as are
all parser bodies); no proof metrics regress.

## Traceability

No new HLRs. Existing tags continue to cover the changed packages:
`-- HLR-SCAN` on `Adacovex.Parsers.Source`, `-- HLR-PROOF` on
`Adacovex.Parsers.GNATprove`, `-- HLR-TEST` on `Adacovex.Parsers.Tests`,
`-- HLR-COMPLIANCE` on `Adacovex.Types` and `Adacovex.Compliance.DAL`,
`-- HLR-DIFF` on `Adacovex.Diff`, `-- HLR-RENDER-ANSI` on
`Adacovex.Renderers.ANSI`, and `-- HLR-SBOM` on `Adacovex.Renderers.SBOM`.
