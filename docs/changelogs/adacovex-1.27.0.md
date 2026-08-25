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
non-approved alternatives, and an example sentence.

### C3: STE100 rewrite audit of docs and API reference

Audited the STE100-rewritten user documentation and the generated API
reference for dropped jargon. All important technical terms survived the
rewrite (Alire, gnatprove, GNAT, manifest, SBOM, CycloneDX, SPDX, DAL,
ASIL, HLR, LLR, verification conditions, pragma, aspect, contract,
subprogram, and friends). One garbled sentence in `docs/architecture.md`
was corrected.

### C4: Documentation index pages for docs and every docs subdirectory

Added `docs/index.md` (the top-level documentation landing page) and
index pages for the subdirectories that lacked one: `docs/proof/index.md`
(proof records), `docs/compliance/index.md` (VERIFICATION.md, TRACE.md,
and the HLR/LLR indexes), and `docs/badges/index.md` (the SVG badge set).
Every index states that the documentation uses British English and
ASD-STE100 Simplified Technical English and points at the
`docs/ste100-technical-names.md` dictionary. The generated API reference
index (`docs/api-docs/index.md`) now opens with a "How to read this
reference" section written for end users, contributors, and maintainers;
it links the CLI reference, the standards pages, the contributing guide,
the architecture notes, the proof ledger, the changelogs, and the STE100
dictionary. The API-docs reader guide lives in `tools/rst2md.py` so
`make doc` regenerates it instead of overwriting a hand-edited file. The
`tools/doc-links.map` and the AGENTS.md documentation block now list the
new index pages.

### C5: SBOM system-tool scan rewritten as a single-pass word scan

`Discover_System_Dev_Deps` matched every line against every system tool
with a per-tool substring loop (60 tools x line length). It dominates the
whole warm assessment pipeline: profiling showed 76% of warm-path CPU in
`Line_Refers_To` / `Match_At`. The replacement walks each line once,
extracts maximal `[a-z0-9_-]` words, and compares each word against the
tool table by length first. Match semantics are identical and the cmp is
per-word, so `make` still matches in `make build`, `Makefile` still does
not match (capital M), and `python` still does not match in `python3`.
Warm self-assessment dropped from ~1021 ms to ~63 ms (16x) on the
benchmark machine.

### C6: Tool-output directories excluded from both tree walks

The SBOM dev-dependency walk and the source scan walked every directory
except the blacklist. A `gnatprove/` output directory (thousands of
files after a proof run) and `__pycache__`, `node_modules`, `.headroom`,
and `.lccst` directories were therefore enumerated and cleaned on every
run. All five names are now skipped by both walks; the remaining syscall
noise on warm runs is glibc hwcaps startup probing, not adacovex code.

### C7: Cache eviction batched

`Put_Cached` ran `Evict_If_Needed` after every store; `Evict_If_Needed`
walks the whole cache tree (`readdir` + `stat` per entry). A cold run
that stores one blob per source file therefore walked the cache once per
file. Eviction now runs every 32 stores, so a bounded overshoot of at
most 31 entries is the steady state and a cold run walks the tree once or
twice. This is part of the cold-run improvement (~1.4 s to ~0.55 s).

### C8: `CPUs.Get_Temp_Directory` and SPARK Mode Off exceptions

1.26.0 restricted `SPARK_Mode (Off)` to three documented exceptions. Each
was re-verified against gnatprove 16.1.0 with minimal scratch units:

- A `SPARK_Mode => On` unit instantiating non-formal
  `Ada.Containers.Vectors` is rejected by flow analysis: it says the
  instantiation is "not allowed in SPARK (due to entity declared with
  SPARK_Mode Off)". The `Adacovex.Types.Implementation` and
  `Adacovex.Complexity` container packages are therefore the two
  irreducible exceptions, and the Makefile `spark-off-check` gate now
  allows exactly those two.
- `Ada.Environment_Variables` reads were never SPARK-blocked. A
  `SPARK_Mode => On` function calling `Exists` / `Value` proves clean,
  with `[assumed-global-null]` warnings because the runtime has no
  Global contracts. `CPUs.Get_Temp_Directory` therefore returned to
  `SPARK_Mode => On` with `Global => null` (spec and body), and its
  docstring in `docs/` was corrected. The full proof now reports 724
  VCs, 0 unproved, 0 justified (Platinum), with the ledger listing the
  six `[assumed-global-null]` warnings.

The evidence and the skipped-units audit are recorded in
`docs/proof/16.1.0-ledger.md` (the 16.1.0 ledger).

## Fixes

- `docs/architecture.md`: corrected the garbled STE100 rewrite sentence.
- `docs/llm-usage.md` and `docs/developer-guide.md`: updated the
  SPARK_Mode-Off exception list from three packages to two.

## Test Suite

968 tests passing across 14 categories.

## Proof Results

Platinum, 724/724 VCs proved under gnatprove 16.1.0. 0 unproved, 0
justified. `CPUs.Get_Temp_Directory` carries six `[assumed-global-null]`
warnings (the GNAT runtime has no Global contracts for
`Ada.Environment_Variables`); warnings are not VCs and the gate stays
0 / 0.

## Traceability

No new HLRs. Coverage:

  - `HLR-PROVE` -- C1 temp-capture file fix in the `prove` subcommand.
  - `HLR-SBOM` -- C5 single-pass system-tool reference scan, C6
    tool-output directory exclusions in the dev-dependency walk.
  - `HLR-CACHE` -- C7 batched cache eviction.
  - `HLR-CPU` -- C8 `Get_Temp_Directory` SPARK_Mode On and the
    container-exception verification.
  - `HLR-ARCH` -- C4 documentation index pages and API-docs reader guide,
    C2/C3 STE100 dictionary and audit.

See `docs/index.md`, `docs/cli-reference.md`, `docs/ste100-technical-names.md`,
`docs/proof/index.md`, `docs/compliance/index.md`, `docs/badges/index.md`.