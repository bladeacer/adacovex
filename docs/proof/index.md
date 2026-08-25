# Proof Records

This directory holds the record of every SPARK proof run for adacovex.

## Reading the ledger

The [gnatprove 16.1.0 ledger](16.1.0-ledger.md) documents the current
verified surface:

- the VC counts (currently 724 VCs, 0 unproved, 0 justified, Platinum);
- the audit of the skipped units and the reason each stays SPARK_Mode Off;
- the empirical evidence that the non-formal `Ada.Containers`
  instantiations in `Adacovex.Types.Implementation` and
  `Adacovex.Complexity` are the only irreducible SPARK_Mode (Off)
  packages;
- the `[assumed-global-null]` warnings that the SPARK_Mode On
  `Adacovex.CPUs.Get_Temp_Directory` carries.

## How to verify the numbers

Run `make prove` at any time.  It runs gnatprove through the `prove`
subcommand and enforces the Platinum gate: 0 unproved VCs and 0 justified
VCs.  `make proof-status` then syncs the measured counts into the docs.

The full proving workflow, including proof patches over vendored
dependencies, lives in [Proving and writing proofs](../proving.md).

Documentation in this directory uses British English and ASD-STE100
Simplified Technical English.  See the [STE100 Technical Names
dictionary](../ste100-technical-names.md) for the approved terms about
proof, verification condition, and SPARK.