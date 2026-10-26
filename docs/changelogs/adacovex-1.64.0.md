# adacovex 1.64.0

Date: _2026-10-25_

Version bumped 1.63.0 -> 1.64.0.

## Changes

### C1: SPARK Platinum requires a complete formal specification and full proof coverage

The SPARK-level classifier granted **Platinum** to any project that had at
least one proved functional contract, or that proved all of its flow, run-time,
and assertion checks but had no functional contracts to prove. That misread the
SPARK Platinum definition: Platinum is the highest level and it requires a
complete formal specification of *all* subprogram behaviour, so a project with
no functional contracts has nothing to prove at that level and is not Platinum.

It also treated a fully proved *summary* as a fully proved *program*. A project
that leaves subprograms outside the proof -- skipped units, or units gnatprove
never analysed -- still got Platinum because the summary rows look complete.

`Determine_SPARK_Level` now grants Platinum only when all of these hold:

- there is a functional-contract surface to prove (`Functional_Ct > 0`) and
  every functional contract is proved;
- the SPARK coverage report has been measured and shows full proof coverage:
  every subprogram it assesses is proved (`Subs_Proved = Subs_Total`).

The coverage evidence comes from the existing `spark-coverage` analysis
(`Spark_Coverage.Analyze`, folded into the summary by `Apply_To_Proof`), so the
level and the `--require-coverage` gate read the same numbers. An assessment
that never measures the coverage report never claims Platinum. Unproved VCs
still cap the level at **Silver**, and justified VCs still count neither proved
nor unproved and never downgrade it.

adacovex's own assessment moves from Platinum to **Gold**: all 1054 VCs are
proved, but its coverage report shows 120 of 612 assessed subprograms proved,
because the deliberate `SPARK_Mode (Off)` units stay outside the proof. The
honest-level wording in the architecture, SPARK-levels, proving, and proof
pages now says this plainly, so the SPARK-levels page, the architecture page,
the CLI reference, and the badge, dashboard, and SBOM labels all describe the
same Platinum bar.

## Fixes

### F1: SPARK level is Gold, not Platinum, when there are no functional contracts

A project with no functional contracts had nothing to prove at Platinum, but
the classifier previously promoted it to Platinum whenever all of its other
checks were proved. That over-labelled projects such as pure-flow or
pure-runtime libraries and made the badge, dashboard, and SBOM show Platinum
for code that had no formal subprogram specification at all. The classifier now
returns Gold for that shape (runtime + assertion proved, no functional
contracts), and the SPARK-levels and architecture pages describe Platinum as
requiring a complete formal specification of all subprogram behaviour.

### F2: SPARK level is Gold, not Platinum, without full proof coverage

The summary parser also tracked a per-unit "functional contract coverage" flag
that real `gnatprove.out` records never carry, so it stayed True on every
parsed report and could never stop a Platinum claim. The flag and its dead
`skipped;`-record parsing are gone. The Platinum gate now reads the SPARK
coverage report instead, and a project whose report shows subprograms outside
the proof is Gold however complete its proved rows look. A bare parse of
`gnatprove.out` reaches Gold at most, which is also what
`tools/update-proof-status.py` reports.

## Test Suite

- `parsers-gnatprove`: regression tests cover the full Platinum rule (every
  functional contract proved plus full proof coverage, including justified
  VCs), the unmeasured-coverage case (Gold, never Platinum), the
  partial-coverage case (Gold), the no-functional-contract Gold case, and the
  incomplete-runtime Silver case. The parse-level tests now assert Gold, since
  a summary file alone carries no coverage evidence, and the empty-summary
  cases assert Stone. The existing Platinum, Gold, Silver, Bronze, and Stone
  level tests remain.

## Proof Results

- gnatprove 16.1.0: SPARK Gold, 1054 VCs, 0 unproved, 0 justified, 120/612
  subprograms proved by the coverage report (see
  `docs/proof/16.1.0-ledger.md`). Platinum is not claimed: full proof coverage
  is not met.

## Traceability

- `parsers-gnatprove.Determine_SPARK_Level` -- the exact same rules the
  classifier, the badge, the dashboard, and the SBOM read from
  (`docs/contributing/architecture-verification.md`);
- `parsers-gnatprove.Parse_Prove_Out` -- the summary parser whose rows feed
  the classifier (`docs/api-docs/adacovex-parsers-gnatprove.md`);
- `spark-coverage.Analyze` -- the per-unit subprogram coverage the Platinum
  gate now requires (`docs/api-docs/adacovex-spark-coverage.md`);
- `spark-coverage.Apply_To_Proof` -- folds that rollup into the proof summary
  and re-derives the level.

