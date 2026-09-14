# adacovex 1.49.0

Date: _2026-09-14_

Version bumped 1.48.0 -> 1.49.0.

## Changes

### C1: Phase-based `make prove` timing table

The `make prove` timing table on
[docs/contributing/perf-prove-timing.md](../contributing/perf-prove-timing.md)
now keeps one column per **phase** instead of one per release.  A phase is a
range of versions whose implementation methodology is largely similar: the
table carries 1.40.0-1.41.0, 1.42.0-1.44.0, and 1.45.0-1.47.0.  Each phase
has one representative version (1.41.0, 1.44.0, and 1.47.0) that supplies
the phase's complete metric set, so a column is never assembled from the
best value of each row across different versions.  The page is split into a
phase-rule section plus pipeline, prove, and warm-syscall tables, it marks
the 1.48.0 phase as open, and it carries per-phase reading notes.

### C2: AGENTS.md proof-timing phase rule

`AGENTS.md` now lists `docs/contributing/perf-prove-timing.md` among the
documents every change must keep current, and states the phase rule that
governs the table.  A new version folds into the open phase while the
methodology holds; a methodology shift closes the phase and opens a new one.
Each phase keeps exactly one representative version, and the metrics carry
that version's complete set.  The Verification section points at the
per-phase table beside the performance page.

### C3: Performance docs split into a hub and sub-pages

`docs/contributing/perf.md` was a 250-line page that mixed the benchmark
categories, the methodology, the sample output, the serve-API figures, the
binary size, and the interpretation.  It is now a hub: the benchmark
category reference, the expected numbers, the phase rule, CI, and the
regression triage.  The how-to, the benchmark machine, the sample output,
the single-shot recipe, the binary size, the probe cache, and the serve-API
load test moved to the new
[Benchmarking adacovex](../contributing/perf-benchmarks.md) page.  The hub
cross-links the phase rule on the [prove-timing
page](../contributing/perf-prove-timing.md).

### C4: STE100 dictionary split into a hub and six lexicons

`docs/contributing/ste100-technical-names.md` was 817 lines, the largest
page in the tree.  It is now a hub with the categories, the required fields,
the key rules, and the entry template, and six lexicon pages carry the
entries: the [Ada language
constructs](../contributing/ste100-ada-terms.md), the [proof and compliance
terms](../contributing/ste100-proof-terms.md), the [tooling and workflow
terms](../contributing/ste100-tooling-terms.md), the [hardware and system
entities](../contributing/ste100-entities.md), the [tools and
files](../contributing/ste100-identifiers.md), and the [reports and
concepts](../contributing/ste100-concepts.md).  Every entry keeps its exact
text and field order; only the heading level changed.

### C5: Proof ledger split into the ledger and the audit

`docs/proof/16.1.0-ledger.md` was 276 lines.  The skipped-units audit, the
irreducible `SPARK_Mode (Off)` exceptions, and the formal-containers
experiment moved to the new [proof-debt
audit](../proof/16.1.0-ledger-audit.md) page.  The ledger keeps the
baseline, the per-package fixes, and the verification commands, and links
the audit page.

### C6: Documentation, docstring, unit-test, and proving gap audit

The release audited the four coverage surfaces.  It found no docstring gap
(179 of 179 subprograms documented) and no proving gap (880 VCs, 0 unproved,
0 justified, Platinum), and every user page now sits under the 250-line cap
except the one historical changelog that carries a line-cap opt-out marker.
It found five unit-test gaps: `Adacovex.Dir_Cache`, `Adacovex.Opt_Outs`,
`Adacovex.Diff`, `Adacovex.Prove`, and `Adacovex.Renderers.ANSI` have no
dedicated test category.  The first three are exercised only indirectly
through the scanner, cache, SBOM, and end-to-end suites; the record here is
the follow-up work list.

## Fixes

### H1: Stale VC count in the proof index

`docs/proof/index.md` quoted 724 VCs, the count from the 1.28.0 era, while
the ledger and the live self-assessment report 880.  The index now reads 880
and links both the ledger and the new audit page, so the proof records agree.

## Test Suite

The native suite is unchanged: 1404 tests across 17 categories pass.  This
is a documentation release, so no Ada source changed except the generated
version constant.  The stdlib suite for the dev tools (`tools/tests.py`)
stays at 59 tests.

## Proof Results

Platinum, 0 unproved, 0 justified, 880 VCs (880 proved) under gnatprove
16.1.0 across 58 analysed units.  The release adds no proof surface: only
the generated version constant changed in `src/`, and it carries no proof
obligations.  No proof metric regressed.

## Traceability

- No new HLRs. The release restructures the user documentation, records the
  proof-timing phase policy, and audits the coverage surfaces; the existing
  `HLR-ARCH` tag covers it.
- `HLR-ARCH` -- C1 the per-phase timing tables, C2 the AGENTS.md phase
  rule, C3 the perf-page split, C4 the STE100 lexicon split, C5 the proof
  ledger split, C6 the gap audit, and H1 the stale VC-count fix.
