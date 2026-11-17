# Adacovex.Parsers.GNATprove

Parse a gnatprove.out file, extracting VC counts per check type.
Reads the GNATprove summary table and populates the Proof_Summary
record with proved/unproved VC counts per category.
@param File_Path  Path to gnatprove.out.
@param Summary  Output proof summary record.
@param Success  True if file was parsed successfully.

> **Note:** All items in this package are public.

## Functions

### function Determine_SPARK_Level (Summary : Adacovex.Types.Proof_Summary) return Adacovex.Types.SPARK_Level `[Post]` `[SPARK]`

> Derive an overall SPARK certification level from proof results. Platinum requires a complete formal specification and full proof coverage: at least one functional contract to prove with every one of them proved, and every subprogram the SPARK coverage report assesses proved. A project that proves its flow, run-time, and assertion checks but has no functional contracts, or that leaves subprograms outside the proof, is Gold at most.

| Parameter | Description |
|-----------|-------------|
| `Summary` | Proof summary with VC counts per category, plus the coverage evidence Apply_Coverage attaches. |

**Returns:** Derived SPARK_Level (Stone through Platinum).

### function Find_Prove_Output (Target_Dir : Standard.String) return Standard.String `[Pre]`

> Return the path of the first existing GNATprove output file under Target_Dir, or "" if none is present. Used by the result cache to key a cached proof summary to the exact artifact analysed.

| Parameter | Description |
|-----------|-------------|
| `Target_Dir` | Root directory to inspect. |

**Returns:** Path to a discovered gnatprove.out, or "".

### function Total_Row_Unproved (Row : Standard.String) return Standard.Natural `[Pre]` `[SPARK]`

> Extract the Unproved column value from one Total summary row. The row is the space-aligned "Total | Flow | Provers | Justified | Unproved" line of the gnatprove.out summary table; columns are runs separated by two or more spaces and the Unproved cell is either "." (all proved) or "N (P%)". The result-cache layer uses this to refuse to serve a stored summary that reports unproved VCs, because gnatprove exits 0 even when solver timeouts leave checks unproved.

| Parameter | Description |
|-----------|-------------|
| `Row` | One Total row line (no trailing newline). |

**Returns:** The unproved-VC count (0 when the cell is "." or missing).

## Procedures

### procedure Apply_Coverage (Summary : Adacovex.Types.Proof_Summary; Measured : Standard.Boolean; Subs_Proved : Standard.Natural; Subs_Total : Standard.Natural; Checks_Proved : Standard.Natural; Checks_Total : Standard.Natural) `[Post]` `[SPARK]`

> Fold the SPARK coverage report's whole-tree rollup into a proof summary and re-derive its level. A summary parsed from gnatprove.out alone counts total VCs but cannot show whether every subprogram was proved, so Platinum is only granted once the assessment pipeline has measured the coverage report (Adacovex.Spark_Coverage.Analyze) and attached it here.

| Parameter | Description |
|-----------|-------------|
| `Checks_Proved` | Checks the prover discharged. |
| `Checks_Total` | Checks the prover reported. |
| `Measured` | True when both proof artefacts were read. |
| `Subs_Proved` | Subprograms the prover proved. |
| `Subs_Total` | Subprograms the prover considered. |
| `Summary` | Proof summary to update. |

### procedure Parse_Prove_From_Project (Target_Dir : Standard.String; Summary : Adacovex.Types.Proof_Summary; Success : Standard.Boolean) `[Pre]`

> Probe for and parse GNATprove output from a project directory. Tries, in order: 1. <Target>/obj/gnatprove/gnatprove.out 2. <Target>/gnatprove.out If none found, Summary is zeroed and Success = False.

| Parameter | Description |
|-----------|-------------|
| `Success` | True if gnatprove.out was found and parsed. |
| `Summary` | Output proof summary record. |
| `Target_Dir` | Project root directory. |

### procedure Parse_Prove_JSON (File_Path : Standard.String; Summary : Adacovex.Types.Proof_Summary; Success : Standard.Boolean) `[Pre]`

> Parse VC summary from a JSON file containing GNATprove results. Expects top-level keys: "total_vcs", "proved_vcs", "unproved_vcs", "flow_deps", "flow_proved", and more. Falls back to Parse_Prove_Out on failure (not yet implemented).

| Parameter | Description |
|-----------|-------------|
| `File_Path` | Path to GNATprove JSON results file. |
| `Success` | True if JSON was parsed successfully. |
| `Summary` | Output proof summary record. |

### procedure Parse_Prove_Out (File_Path : Standard.String; Summary : Adacovex.Types.Proof_Summary; Success : Standard.Boolean) `[Pre]`

> Parse a gnatprove.out file, extracting VC counts per check type. Reads the GNATprove summary table and populates the Proof_Summary record with proved/unproved VC counts per category.

| Parameter | Description |
|-----------|-------------|
| `File_Path` | Path to gnatprove.out. |
| `Success` | True if file was parsed successfully. |
| `Summary` | Output proof summary record. |
