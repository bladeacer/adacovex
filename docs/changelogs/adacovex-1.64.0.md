# adacovex 1.64.0

Date: _2026-10-25_

Version bumped 1.63.0 -> 1.64.0.

## Changes

### C1: SPARK Platinum requires a complete formal specification of all subprogram behaviour

The SPARK-level classifier granted **Platinum** to any project that had at
least one proved functional contract, or that proved all of its flow, run-time,
and assertion checks but had no functional contracts to prove. That misread the
SPARK Platinum definition: Platinum is the highest level and it requires a
complete formal specification of *all* subprogram behaviour, so a project with
no functional contracts has nothing to prove at that level and is not Platinum.

`Determine_SPARK_Level` now returns Platinum only when `Functional_Ct > 0` and
every functional contract is proved, and it returns **Gold** for the
previously-mislabelled case (all flow, run-time, and assertion checks proved,
no functional contracts). The classifier still caps the level at **Silver** when
there are unproved VCs, and the existing justified-VC and full-coverage rules are
unchanged.

The honest-level wording in the architecture and SPARK-levels pages now says
this plainly, so the SPARK-levels page, the architecture page, the CLI
reference, and the badge, dashboard, and SBOM labels all describe the same
Platinum bar.

## Fixes

### F1: SPARK Platinum no longer requires Functional_Ct > 0 on the summary alone

The classifier used to grant Platinum when `Functional_Ct > 0` and
`Functional_Proved = Functional_Ct`, and it would otherwise land a project
with all flow, run-time, and assertion checks proved but no functional
contracts at Gold. The same summary shape could then be read as Platinum in
one run and Gold in another whenever a parse or cache miss dropped the
functional row, which made the level depend on output shape rather than on
the proved surface. The classifier now treats the `Functional_Ct > 0` case as
the only Platinum path and treats the zero-functional-contract case as Gold
when runtime and assertion are both complete, which keeps the result stable
across parse paths and cache hits.

### F2: SPARK level is Gold, not Platinum, when there are no functional contracts

A project with no functional contracts had nothing to prove at Platinum, but
the classifier previously promoted it to Platinum whenever all of its other
checks were proved. That over-labelled projects such as pure-flow or
pure-runtime libraries and made the badge, dashboard, and SBOM show Platinum
for code that had no formal subprogram specification at all. The classifier now
returns Gold for that shape (runtime + assertion proved, no functional
contracts), and the SPARK-levels and architecture pages describe Platinum as
requiring a complete formal specification of all subprogram behaviour.

## Test Suite

- `parsers-gnatprove`: regression tests added for the Platinum completeness
  rule (`Functional_Ct > 0` and `Functional_Proved = Functional_Ct`,
  including justified VCs), the no-functional-contract Gold case (`0/0` with
  runtime + assertion proved), the mixed `0/5` Gold case (runtime + assertion
  complete, no functional), and the incomplete-runtime Silver case (no
  functional contracts and runtime not fully proved). The existing Platinum,
  Gold, Silver, Bronze, Stone, justified-VC, and modern-summary tests remain
  unchanged.

## Proof Results

- gnatprove 16.1.0: SPARK Platinum, 1054 VCs, 0 unproved, 0 justified
  (see `docs/proof/16.1.0-ledger.md`).

## Traceability

- `parsers-gnatprove.Determine_SPARK_Level` -- the exact same rules the
  classifier, the badge, the dashboard, and the SBOM read from
  (`docs/contributing/architecture-verification.md`);
- `parsers-gnatprove.Parse_Prove_Out` -- the summary parser whose rows feed
  the classifier (`docs/api-docs/adacovex-parsers-gnatprove.md`);
- `spark-coverage.Analyze` -- the per-unit subprogram coverage that the
  classifier works alongside (`docs/api-docs/adacovex-spark-coverage.md`).

