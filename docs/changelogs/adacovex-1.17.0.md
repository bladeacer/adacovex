# adacovex 1.17.0

Date: _2026-08-22_
Version bumped 1.16.0 -> 1.17.0.

## Changes

### C1: full SPARK proof re-verification pass (Platinum held)

A full `--force` SPARK proof re-run on the current tree re-confirms adacovex's
own proof discipline end to end. gnatprove 16.1.0 (`--steps=10000`, the
`Build_Option_String` default since 1.10.0) reports **487 total checks -- 487
proved (112 flow + 375 by prover), 0 justified, 0 unproved** across 48
analyzed units, i.e. **Platinum** unchanged from 1.16.0. The 196 skipped units
are all default-off `SPARK_Mode => Off` I/O- and container-heavy bodies (file
I/O, `Ada.Containers`, `Ada.Text_IO`) that are out of proof scope by design --
the `spark-off-check` gate still passes (no explicit `pragma SPARK_Mode (Off)`
in `src/` outside `Types.Implementation`, the one non-formal container package
SPARK forbids analyzing). No source changes were needed to hold the proof; this
release records that the 1.16.0 proof surface reproduces on the current HEAD.

### C2: Ada_CRDT dogfood regression re-verified (Platinum held)

The `make run-ada-crdt` dogfood regression and a fresh `--force` proof of
`../Ada_CRDT` via the sibling adacovex binary both re-confirm the target's
Platinum proof: gnatprove 16.1.0 reports **576 total checks -- 576 proved (109
flow + 467 by prover), 0 justified, 0 unproved** across 48 analyzed units, with
the vendored VT100 demo dependency exercised through the 1.16.0 proof-patch
pipeline (`SPARK_Mode => On` on the package, the `Scroll_Screen (From, To)`
scroll-region contract merged into the patched tree copy). The 100 skipped units
are the expected platform/generics/I/O exclusions (HLC wall-clock, RNG, stream
I/O, test harness). 100% docstring coverage (225/225) and 10290/10290 tests hold.
DAL-C Achieved. This is the Ada_CRDT 1.11.0 verified state.

## Test Suite

850 tests passing across 14 categories (unchanged from 1.16.0). The proof
re-verification pass made no source changes, so the test surface is untouched;
`make test` still reports 850 passed, 0 failed.

## Proof Results

Platinum, 487/487 VCs proved across 48 analyzed units (unchanged from 1.16.0):
230 run-time checks, 78 assertions, 52 functional contracts, 45
data-dependency checks, 4 initialization checks, and 78 termination checks, all
proved. 0 unproved, 0 justified. Re-verified with `adacovex prove --target=.
--force` under gnatprove 16.1.0 (`--steps=10000`). The Ada_CRDT dogfood target
re-verified at Platinum, 576/576 VCs (109 flow + 467 prover), 0 unproved, 0
justified, 34 analyzed units.

## Traceability

No new HLRs. The proof re-verification touches no source and adds no
requirements; it re-confirms the existing `HLR-PROOF` tag (`make prove` and the
`prove` subcommand) and the `HLR-PROVE` proof-patch machinery (exercised end to
end by the Ada_CRDT dogfood). The C2 Ada_CRDT re-verification is covered by the
`make run-ada-crdt` regression and the Ada_CRDT 1.11.0 changelog. See
`docs/proof/16.1.0-ledger.md` for the proof debt ledger.
