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

## Test Suite

## Proof Results

## Traceability
