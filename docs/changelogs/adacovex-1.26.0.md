# adacovex 1.26.0

Date: _2026-08-24_

Version bumped 1.25.0 -> 1.26.0.

## Changes

### C1: perf-bench target wired to Makefile

`tools/perf-bench.py` is now exposed as `make perf-bench`, providing a
dedicated perf/strace profiling target alongside the existing `bench`
hyperfine target.

### C2: SPARK_Mode Off restricted to documented exceptions

Verified that `SPARK_Mode (Off)` and `SPARK_Mode => Off` appear only in the
three documented exception packages: `adacovex-complexity` (non-formal
Ada.Containers), `adacovex-types` (Subprogram_Vectors container), and
`adacovex-cpus.Get_Temp_Directory` (Ada.Environment_Variables).

### C3: Dedicated credits file

Added `docs/CREDITS.md` as the dedicated acknowledgements file. It lists
adacovex credits and points to `docs/THIRD_PARTY_NOTICES.md` for full
third-party license details.

### C4: Requirements table

Added `docs/requirements.md` with a table that categorises dependencies as
Core, Development, or Good to have. Alire-managed dependencies are listed
under their Alire crate names.

### C5: Docs rewritten in ASD-STE100

User documentation now follows ASD-STE100 Simplified Technical English rules:
short sentences, active voice, one instruction per sentence, consistent
terminology, and no AI-slop hedging. See
https://github.com/AminBlg/SimpleEnglish for the skill reference.

### C6: SimpleEnglish skill reference in AGENTS.md

AGENTS.md now references the
[AminBlg/SimpleEnglish](https://github.com/AminBlg/SimpleEnglish) skill for
technical writing guidance.

### C7: British English in inline source comments

British English now also covers inline (non-docstring) source comments
across the Ada sources.  This completes the spelling pass: docstrings
were already converted, and the remaining American spellings (analyse,
colour, normalise, synthesise, licence, honour, centre, and friends)
were updated to match the AGENTS.md technical-writing convention.

### C8: Hardened ASCII and link checks; skills directory excluded

The `ascii-check` makefile target was rewritten to be less brittle: it now
runs a single recursive grep with explicit include and exclude patterns
instead of a nested find loop over extensions, and it no longer relies on
tab escapes inside bracket expressions.  The vendored `skills/` directory
is excluded from the ASCII check (its skill files legitimately carry
non-ASCII punctuation such as em-dashes).  The link checker now also
skips `skills/`, so vendored third-party content is never gated by our
repo checks.

## Fixes

None.

## Test Suite

968 tests passing across 14 categories.

## Proof Results

Platinum, 722/722 VCs proved under gnatprove 16.1.0. 0 unproved, 0 justified.

## Traceability

No new HLRs. Coverage:

   - `HLR-ARCH` -- C1 perf-bench Makefile target, C2 SPARK_Mode Off audit,
     C3 credits file, C4 requirements table, C5/C6 ASD-STE100 docs and
     SimpleEnglish skill reference, C7 British English in inline source
     comments, C8 hardened ASCII/link checks with skills directory
     exclusion.

See `docs/cli-reference.md`, `docs/ci-cd.md`, `docs/architecture.md`.
