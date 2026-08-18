# Adacovex.Parsers.GNATprove

Parse a gnatprove.out file, extracting VC counts per check type.
Reads the GNATprove summary table and populates the Proof_Summary
record with proved/unproved VC counts per category.
@param File_Path  Path to gnatprove.out.
@param Summary  Output proof summary record.
@param Success  True if file was parsed successfully.

> **Note:** All items in this package are public.

## Functions

### function Determine_SPARK_Level (Summary : Adacovex.Types.Proof_Summary) return Adacovex.Types.SPARK_Level `[Post]` `[Global]` `[SPARK]`

| Parameter | Description |
|-----------|-------------|
| `Summary` | Proof summary with VC counts per category. |

**Returns:** Derived SPARK_Level (Stone through Platinum).

### function Find_Prove_Output (Target_Dir : Standard.String) return Standard.String `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `Target_Dir` | Root directory to inspect. |

**Returns:** Path to a discovered gnatprove.out, or "".

## Procedures

### procedure Parse_Prove_From_Project (Target_Dir : Standard.String; Summary : Adacovex.Types.Proof_Summary; Success : Standard.Boolean) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `Success` | True if gnatprove.out was found and parsed. |
| `Summary` | Output proof summary record. |
| `Target_Dir` | Project root directory. |

### procedure Parse_Prove_JSON (File_Path : Standard.String; Summary : Adacovex.Types.Proof_Summary; Success : Standard.Boolean) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `File_Path` | Path to GNATprove JSON results file. |
| `Success` | True if JSON was parsed successfully. |
| `Summary` | Output proof summary record. |

### procedure Parse_Prove_Out (File_Path : Standard.String; Summary : Adacovex.Types.Proof_Summary; Success : Standard.Boolean) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `File_Path` | Path to gnatprove.out. |
| `Success` | True if file was parsed successfully. |
| `Summary` | Output proof summary record. |
