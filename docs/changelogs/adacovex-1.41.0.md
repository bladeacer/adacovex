# adacovex 1.41.0

Date: _2026-09-03_

Version bumped 1.40.0 -> 1.41.0.

## Changes

### C1: The result-cache stamp map fixes a silent fast-path miss

The result-cache file-stamp fast path never fired: the lookup compared the
stored fixed-size name buffer against the real path, so the lengths never
matched and every file was re-read and re-hashed on every run. The map is
now open-addressed on a 32-bit FNV-1a hash of the path, so a hit probes one
or two slots instead of scanning the whole map. Lookups touch the compact
scalar arrays (hash, size, length) first and read the 2048-byte name buffer
only when all three scalars match a candidate. The layout is cache-line
friendly: the hot scalar arrays stay together and the cold name buffer sits
apart.

The change adds `Stamp_Hits` / `Stamp_Misses` counters so a silent
fast-path regression is visible in tests and diagnostics instead of hiding
behind a warm wall-clock number. A new Result-cache test category (21
tests) pins the stamp-map behaviour: hits, misses, size-changed files, and
map churn all round-trip through the public hash API.

### C2: A gnatprove-friendly IR exploration lands as a lean proved slice

The [IR exploration](../contributing/ir.md) asks whether adacovex can
synthesise the bounded, contract-carrying specs that make foreign code
provable. The exploration question is documented, and a **lean slice** of
the answer ships: `Synthesize_Bounded_Function` lowers one `P:Type`
parameter pair onto a bounded IR scalar and emits the half-range `Pre`
guard as generated text. The guard is the exact shape gnatprove already
discharges for `Target_Profiles.Checked_Add32` and the `IR_Bounds` fixture.

The first prototype handled comma-separated parameter lists in three
passes and cost about 110 extra VCs in `ir_synthesiser`. The single-pair
form needs no comma-splitting pass; it slices the pair once into named
constants and emits the spec in straight line. The shipped slice and its
helpers add about 57 VCs to the synthesiser unit, and every check proves.
The multi-pair design stays recorded in the design doc with its measured
VC budget, so a future change can pick it up without re-deriving the
lessons.

### C3: CPU-core detection memoises its result per process

The prove and status paths called `Detect_Core_Count` repeatedly, and every
call re-read `/proc/cpuinfo`. The first successful detection is now cached
for the process, so a run reads the machine topology once. The fallback of
1 is deliberately not memoised: a transient probe failure must not poison
later calls in the same run.

### C4: Python virtual environments leave the source walks

A `.venv` directory holds an installed copy of the packages a target's
`requirements*.txt` declares, often thousands of files. The SBOM and source
walks no longer descend into `.venv`: the requirements file is the source
of truth for the Python dependency graph, and enumerating the installed
copy wasted reads and spawns. The complexity check already excluded `.venv`
since 1.40.0; the parser walks now match it.

### C5: Self-assessment gates and counts sync to the 1213-test suite

The acceptance-gate `--require-tests` in `tools/run.py` pinned the suite at
1033 while the native suite had grown to 1213; CI and the docs already
carried the current count. The gate now matches the suite, so `make prove`,
`make run-self`, and the release flow enforce the real current size. The
proof ledger, verification tables, and manifest descriptions were refreshed
to the measured totals in the same pass.

## Fixes

### H1: IR synthesiser proof runs emit contextual re-analysis info notes

gnatprove printed "analyzing call to Is_Signed_IR in context" (and the
matching no-contextual-analysis note for `Is_IR_Type`) at every call site
of the string-equality helpers. The helpers had no contracts, so gnatprove
re-proved their equality chains contextually per caller. Adding
`Global => null` makes gnatprove analyse each chain once as a unit; the
notes are gone and the equality VCs no longer repeat per call site.

## Test Suite

The native suite grows to 1213 tests across 17 categories: a new Result
cache category (21 tests) covers the stamp map and the cache public API,
and the IR synthesis category grows from 27 to 33 tests for the lean
single-pair slice. All 1213 tests pass.

## Proof Results

Platinum, 0 unproved, 0 justified, 791 VCs (791 proved) under gnatprove
16.1.0 across 56 analysed units. The totals grow from 725 at 1.40.0: the IR
slice and its helpers add about 57 VCs, the two new `Global` contracts add
their flow checks, and the new cache test category sits in I/O units that
gnatprove skips. The cold full-cache-miss `make prove` rises from about
39.0 s to 42.8 s on the measurement machine, proportionally to the VC
count; an idle run with unchanged inputs still short-circuits in about
2.5 s without spawning gnatprove.

## Traceability

- No new HLRs. The release changes performance internals, the IR
  synthesiser, and documentation only; the existing tags below cover it.
- `HLR-CACHE` -- C1 the stamp-map redesign and the Result-cache test
  category.
- `HLR-IR` -- C2 the lean bounded-function slice, H1 the `Global`
  contracts, and the IR design doc.
- `HLR-CPU` -- C3 the memoised core-count detection.
- `HLR-SCAN` / `HLR-MANIFEST` -- C4 the `.venv` walk exclusions.
- `HLR-DOC` -- C5 the gate and documentation count sync, and this
  changelog.
