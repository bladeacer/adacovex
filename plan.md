# Plan: SPARK Platinum needs full proof coverage (1.64.0)

## Context

The SPARK-level classifier granted Platinum to any project whose functional
contracts were all proved, even when the SPARK coverage report showed
subprograms outside the proof. A user reported that adacovex labelled a
Gold-level project (cobs) as Platinum for exactly that reason.

## Change

`Determine_SPARK_Level` now grants Platinum only when:

- there is a functional-contract surface to prove (`Functional_Ct > 0`) and
  every functional contract is proved;
- the SPARK coverage report has been measured and shows full proof coverage
  (`Subs_Proved = Subs_Total`).

The evidence comes from the existing `spark-coverage` analysis
(`Spark_Coverage.Analyze`), folded into the proof summary by
`Spark_Coverage.Apply_To_Proof`. A summary parsed from `gnatprove.out` alone
reaches Gold at most.

adacovex's own assessment is now Gold: 1054/1054 VCs proved, but the coverage
report shows 121/613 subprograms proved because the deliberate
`SPARK_Mode (Off)` units stay outside the proof. DAL-C / ASIL B / Class A are
still Achieved.

## Files changed

- `src/core/adacovex-types.ads` -- `Proof_Coverage` record, `Coverage` field on
  `Proof_Summary`; the dead `Functional_Contract_Coverage` flag is removed
- `src/parsers/adacovex-parsers-gnatprove.ads/.adb` -- the Platinum rule and
  `Apply_Coverage`
- `src/core/adacovex-spark_coverage.ads/.adb` -- `Apply_To_Proof`
- `src/adacovex_main.adb` -- measure the coverage rollup once and reuse it for
  `--serve`; the SBOM path applies it too
- `src/core/adacovex-diff.adb` -- both sides of a differential report
- `src/tests/adacovex_prove_tests.adb` -- coverage cases
- docs, changelog, workflows, `tools/run.py`, `tools/update-proof-status.py`

## Verification

- `just test`: 2040 passed, 0 failed.
- `just prove`: 1054 checks proved, Gold, DAL-C / ASIL B / Class A Achieved.
- `just check`: all 29 gates pass.
