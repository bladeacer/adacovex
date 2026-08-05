# adacovex 1.6.0

Date: _2026-08-05_

Version bumped 1.5.0 -> 1.6.0.

## Changes

### C1: Full SPARK proof coverage (Platinum, 0 unproved)

The whole SPARK-on codebase is now fully machine-proved. Previously only the
bounded IR types (`Checked_Add32/64`, `IR_Bounds.Add32/64`) carried complete
proofs; every other SPARK unit was analyzed but not fully discharged. Now
**all 490 VCs prove** with `--prover=z3 --timeout=20`, including the run-time
range checks, assertions, functional contracts, and loop termination:

- **Renderers**: `I2S` (fixed `10**Pos` overflow by replacing exponentiation
  with a constant `Pow10` power table, loop invariants carrying the digit
  count and value bound, `Buf` initialized), `Pad2` and `Escape_JSON`
  (uninitialized-buffer fixes via `(others => ' ')`), and `ISO_From_Epoch`
  (chained `&` concatenation upper-bound proofs replaced by a bounded
  `Field`-copy buffer procedure). Postconditions now document the result
  lengths (`I2S'Result'Length in 1 .. 10`, `Pad2'Result'Length in 1 .. 11`).
- **Parsers**: `Trim`, `Trim_Left`, `Number_After`, and `Number_Before_Word`
  gained `Pre => S'First >= 1 and S'Last < Natural'Last` preconditions plus
  strengthened loop invariants (carried array-index bounds and the digit-run
  range `for all Q in DStart .. K => S (Q) in '0' .. '9'`).
- **IR synthesiser**: `Bits`, `IR_Type_Name` (`Post => 'Result'Length <= 9`),
  `Lower_Type_Name`, and `Synthesize_Package` (buffer bounds, `Sub`/`Result`
  initialization, and `J >= I` for the outer-loop variant) all proved.
- **Termination**: every `while` loop across the codebase now carries an
  explicit `Loop_Variant` (increasing or decreasing bound), so the implicit
  `Always_Terminates` aspects discharge -- no loop is left as potentially
  non-terminating.

The self-assessment is now: 26 packages, 58 subprograms, 100% docstrings,
**Platinum (490/490 VCs, 0 unproved)**, 290/290 tests, DAL-C Achieved.

### C2: Host word-size auto-detection

Fixed-size buffers and the IR host model are now derived from the actual host
word size instead of being hard-coded to 64-bit assumptions:

- `Adacovex.Types.Host_Word_Bits : constant := System.Word_Size`; the
  `Max_Path` / `Max_Line` path and line buffers scale with it
  (`64 * Host_Word_Bits` = 4096, `4096 * Host_Word_Bits` = 262144 on a 64-bit
  host), so builds on narrower hosts use proportionally smaller limits. The
  semantic limits (`Max_Id_Str`, `Max_Desc_Str`, `Max_Filename`) stay fixed.
- `Adacovex.Target_Profiles.Host_Word_Size` auto-detects the host word size
  (8/16/32/64) from the Ada runtime for `Target_Config.Host_Bits`, with the
  dead-branch warning resolved by a `case System.Word_Size` structure.
- Test suite extended: 6 new checks (Types conversion + IR host-word-size
  detection). The suite is now **290 tests**.

## Fixes

### H1: Changelog link in the release workflow

`.github/workflows/release.yml` built the changelog permalink from the raw tag
name (`v1.6.0`), producing a broken `/docs/changelogs/adacovex-v1.6.0.md`
URL. The link now strips the leading `v` (`${VERSION#v}`) so it points at
`docs/changelogs/adacovex-1.6.0.md`.

The same release step now also:

- **Links the build-provenance attestation** in the release notes. The
  `actions/attest-build-provenance@v2` step is captured (`id: attest`) and its
  `attestation-url` output is included as a *Build Provenance Attestation*
  entry, so consumers can jump straight from the release to the signed
  SLSA provenance bundle.
- **Fixes the *Git Changelog* compare link** to use the tag form
  `compare/v1.5.0...v1.6.0` (previous version keeps its `v` prefix), matching
  GitHub's tag-to-tag compare URL convention instead of the version-only form
  produced by stripping the `v`.

## Notes

- Test suite extended: IR synthesis 26 -> **27** checks; new word-size checks.
  The suite is now **290 tests** (passing).
- Self-assessment metrics: 26 packages, 58 subprograms, 100% docstrings,
  Platinum (490/490 VCs), 290 tests, DAL-C Achieved.

## Proof Results

Self-assessment: **Platinum** (490/490 VCs proved, 0 unproved, AoRTE-free).
Every SPARK-on unit is fully discharged -- run-time checks 353/353,
assertions 56/56, functional contracts 13/13, termination 34/34, flow
55/55. Proof invocation: `gnatprove -P adacovex.gpr --prover=z3 --timeout=20`.

## Traceability

No new HLRs. Existing tags continue to cover the changed packages:
`-- HLR-SCAN` on `Adacovex.Parsers.Source`, `-- HLR-TEST` on
`Adacovex.Parsers.Tests`, `-- HLR-PROVE` / `-- HLR-METRICS` on
`Adacovex.Types`, `-- HLR-IR` on `Adacovex.Target_Profiles` and
`Adacovex.IR_Synthesiser`, `-- HLR-SBOM` on `Adacovex.Renderers.SBOM`.
