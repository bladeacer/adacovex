# adacovex 1.27.0

Date: _2026-08-24_

Version bumped 1.26.0 -> 1.27.0.

## Changes

### C1: Prove run no longer emits GNAT-TEMP files

The `--suppress-warnings` output capture used
`GNAT.OS_Lib.Create_Temp_File`, which writes a `GNAT-TEMP-XXXXX.TMP` file
into the current directory. An interrupted run left that file in the
project tree, and the `.gitignore` entry `*.tmp` is case-sensitive, so the
`.TMP` suffix showed up in `git status`. The capture file now lives in the
system temp directory (`Adacovex.CPUs.Get_Temp_Directory`) under a
PID-suffixed name, following the existing VCS snapshot convention. A
defensive `.gitignore` entry for `*.TMP` and `GNAT-TEMP-*` was added as
well.

### C2: STE100 Technical Names dictionary

Added `docs/ste100-technical-names.md`, the controlled list of Technical
Names (non-STE words) for the adacovex domain, per ASD-STE100 Section 1
"Words". The dictionary organises entries into the four STE categories
(Hardware and System Entities, Ada Language Constructs, Domain and
Mathematical Terms, Code Identifier Names). Every entry carries the five
required fields: approved word, part of speech, approved meaning,
non-approved alternatives, and an example sentence. The list is grounded in
the source code and the user documentation: it covers the Ada constructs
(package, subprogram, task, pragma, aspect, contract, generic, SPARK), the
domain terms (verification condition, proof, coverage, DAL, ASIL, safety
class, DO-178C, ISO 26262, IEC 62304, SBOM, proof patch, result cache,
differential assessment, VCS, docstring, cyclomatic complexity, LOC, man
page), and the exact identifiers (adacovex, covex, alr, gnatprove,
gnatdoc, gnatformat, SPARK_Mode, alire.lock, gnatprove.out, AUnit,
CycloneDX, SPDX, ANSI, NO_COLOR, VERIFICATION.md, TRACE.md). The page is
wired into the AGENTS.md documentation block and referenced from the
technical-writing section, so new Technical Names are added to the list
before use.

### C3: STE100 rewrite audit of docs and API reference

Audited the STE100-rewritten user documentation and the generated API
reference for dropped jargon. All important technical terms survived the
rewrite (Alire, gnatprove, GNAT, manifest, SBOM, CycloneDX, SPDX, DAL,
ASIL, HLR, LLR, verification conditions, pragma, aspect, contract,
subprogram, and friends). One garbled sentence in `docs/architecture.md`
("meets third-party and generated code where it is") was corrected to
"accepts third-party and generated code as it is".

### C4: AGENTS.md synced with changes since 1.24.0

AGENTS.md now reflects the recent changes: the Makefile targets table
carries the `perf-bench` target, and the documentation block lists
`docs/requirements.md` alongside the STE100 technical names page.

## Fixes

None.

## Test Suite

968 tests passing across 14 categories.

## Proof Results

Platinum, 722/722 VCs proved under gnatprove 16.1.0. 0 unproved, 0 justified.

## Traceability

No new HLRs. Coverage:

   - `HLR-PROVE` -- C1 temp-capture file fix in the `prove` subcommand.
   - `HLR-ARCH` -- C2 STE100 Technical Names dictionary, C3 STE100 rewrite
     audit of docs and API reference, C4 AGENTS.md sync.

See `docs/cli-reference.md`, `docs/ste100-technical-names.md`,
`docs/architecture.md`.
