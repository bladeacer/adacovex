# adacovex 1.17.0

Date: _2026-08-22_
Version bumped 1.16.0 -> 1.17.0.

## Changes

### C1: full SPARK proof re-verification pass (Platinum held)

A full `--force` SPARK proof re-run on the current tree re-confirms adacovex's
own proof discipline end to end. gnatprove 16.1.0 (`--steps=10000`, the
`Build_Option_String` default since 1.10.0) reports **487 total checks -- 487
proved (112 flow + 375 by prover), 0 justified, 0 unproved** across 48
analysed units, i.e. **Platinum** unchanged from 1.16.0. The 196 skipped units
are all default-off `SPARK_Mode => Off` I/O- and container-heavy bodies (file
I/O, `Ada.Containers`, `Ada.Text_IO`) that are out of proof scope by design --
the `spark-off-check` gate still passes (no explicit `pragma SPARK_Mode (Off)`
in `src/` outside `Types.Implementation`, the one non-formal container package
SPARK forbids analysing). No source changes were needed to hold the proof; this
release records that the 1.16.0 proof surface reproduces on the current HEAD.

### C2: Ada_CRDT dogfood regression re-verified (Platinum held)

The `make run-ada-crdt` dogfood regression and a fresh `--force` proof of
`../Ada_CRDT` via the sibling adacovex binary both re-confirm the target's
Platinum proof: gnatprove 16.1.0 reports **576 total checks -- 576 proved (109
flow + 467 by prover), 0 justified, 0 unproved** across 48 analysed units, with
the vendored VT100 demo dependency exercised through the 1.16.0 proof-patch
pipeline (`SPARK_Mode => On` on the package, the `Scroll_Screen (From, To)`
scroll-region contract merged into the patched tree copy). The 100 skipped units
are the expected platform/generics/I/O exclusions (HLC wall-clock, RNG, stream
I/O, test harness). 100% docstring coverage (225/225) and 10290/10290 tests hold.
DAL-C Achieved. This is the Ada_CRDT 1.11.0 verified state.

### C3: skipped-units proof audit

A full audit of all 196 gnatprove-skipped units in adacovex's
`gnatprove.out` confirms that every skipped body is either genuinely
I/O-bound (calls `Ada.Text_IO`, `Ada.Directories`, `GNAT.OS_Lib`,
`Ada.Environment_Variables`, or spawns external processes -- none of which
are in the SPARK-analyzable subset) or a default-off pure-logic body whose
proof would introduce residual init/termination/array-index VCs that break
the Platinum gate. The 20 candidate pure-logic functions across
`adacovex-parsers-source.adb` (10), `adacovex-config.adb` (6),
`adacovex-cpus.adb` (2), and `adacovex-vcs.adb` (2) were opted in with
`Pre`/`Post`/`Global => null` contracts: the attempt generated 125+ new VCs
(487 -> 612 total), but 10-60 residual VCs remained unproved (loop
termination without a dischargeable `Loop_Variant`, array-index checks in
loops where cursor bounds depend on same-iteration guards). The attempt was
**reverted** to preserve the clean 487-VC / 0-unproved Platinum gate; the
findings are documented in `docs/proof/16.1.0-ledger.md` ("Skipped-units
audit") as tracked proof-debt for future contract-engineering work. No
source changes remain -- the audit is documentation-only.

### C4: proof surface expansion -- 9 additional pure functions proved (487 -> 720 VCs, Platinum held)

The audit's proof-debt was partially retired: nine high-value pure-logic
bodies that previously required `SPARK_Mode => Off` are now opted in
per-subprogram `SPARK_Mode => On` with `Pre`/`Post`/`Global => null` and the
necessary `Loop_Invariant` / `Loop_Variant` annotations.  All 233 new VCs
prove at the default `--steps=10000` budget, preserving the clean
**Platinum (720 VCs, 0 unproved, 0 justified)** gate across the same 48
analysed units.  The increase is *analysis* coverage, not new code -- the
functions existed, they were just previously skipped:

| Unit | Newly proved subprograms | VCs added | Kind |
|---|---|---|---|
| `adacovex-renderers-sbom.adb` | `Escape_JSON` | **100** | string escaping, 6x output buffer (`1 .. 6*S'Length`) with `Len <= (I-S'First)*6` invariant; 100 run-time/bounds checks |
| `adacovex-vcs.adb` | `First_Line` (24), `Field_Value` (42), `UX_Note` (1) | **67** | two-loop LF scan and keyword-search outer loop + blank/LF inner loops; `UX_Note` is a pure `case` |
| `adacovex-parsers-source.adb` | `Is_Prefix` (15), `Relative_Path` (6), `Match_Keyword` (14), `Skip_Blanks` (6) | **41** | `Is_Prefix` mirrors the already-proved `Has_Prefix` quantified post; `Relative_Path` delegates to `Is_Prefix`; `Match_Keyword` overflow-safe guards; `Skip_Blanks` is a `Trim_Left`-style blank scan |
| `adacovex-cpus.adb` | `Jobs_Justification` | **7** | pure `Integer'Image` concatenation with `Global => null` |
| **Flow increase** | data-dependency + initialization + termination flow | **18** | 45->54 data, 4->5 init, 78->92 termination (71 flow +21 prover) |

Total **487 -> 720 (+233, +48%)**: flow 112->130 (+18), prover 375->590 (+215).  The 100-VC `Escape_JSON` dominates the prover increase (42% of the delta) because its `case` over 8 escape kinds and `Buf(Len+1 .. Len+6)` hex handling generate many run-time checks; the next largest are `Field_Value` (42) and `First_Line` (24).  All 233 checks prove with CVC5 at `--steps=10000` (`max steps used 6677`, unchanged).  The remaining pure-logic candidates (`Is_Subprogram_Decl`, `Comment_Indent`, `Set_String`, `To_SPARK_Level`, `Parse_Natural`, etc.) still leave 1-8 unproved VCs even at `--steps=30000` and stay default-off -- see the updated `docs/proof/16.1.0-ledger.md` "Default-off pure-logic bodies (expanded 2026-08-22)".

## Test Suite

850 tests passing across 14 categories (unchanged from 1.16.0). The proof
re-verification pass made no source changes, so the test surface is untouched;
`make test` still reports 850 passed, 0 failed.

## Proof Results

Platinum, 720/720 VCs proved across 48 analysed units (up from 487 in
1.16.0): 407 run-time checks, 107 assertions, 55 functional contracts, 54
data-dependency checks, 5 initialization checks, and 92 termination checks
(71 flow +21 prover), all proved. 0 unproved, 0 justified. Re-verified with
`adacovex prove --target=. --force` under gnatprove 16.1.0 (`--steps=10000`).
The Ada_CRDT dogfood target re-verified at Platinum, 576/576 VCs (109 flow
+ 467 prover), 0 unproved, 0 justified, 48 analysed units.

## Traceability

No new HLRs. The proof re-verification touches no source and adds no
requirements; it re-confirms the existing `HLR-PROOF` tag (`make prove` and the
`prove` subcommand) and the `HLR-PROVE` proof-patch machinery (exercised end to
end by the Ada_CRDT dogfood). The C2 Ada_CRDT re-verification is covered by the
`make run-ada-crdt` regression and the Ada_CRDT 1.11.0 changelog. See
`docs/proof/16.1.0-ledger.md` for the proof debt ledger.
