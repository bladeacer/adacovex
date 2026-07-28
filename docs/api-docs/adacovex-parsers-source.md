# Adacovex.Parsers.Source

Scan a single .ads file, extracting subprogram info and HLR tags.
File_Path must name a readable .ads file. On success, Pkg is populated
with subprogram declarations, docstring annotations, and HLR tag entries.
@param File_Path  Path to .ads file.
@param Pkg  Output package info.
@param Success  True if file was successfully parsed.

> **Note:** All items in this package are public.

## Functions

### function Compute_Docstring_Metrics (Packages : Adacovex.Types.Package_Array; Pkg_Count : Standard.Natural) return Adacovex.Types.Docstring_Metrics `[Pre]` `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Packages` | Array of scanned packages. |
| `Pkg_Count` | Number of packages in array. |

**Returns:** Aggregate docstring-coverage metrics.

## Procedures

### procedure Scan_Ads_File (File_Path : Standard.String; Pkg : Adacovex.Types.Package_Info; Success : Standard.Boolean) `[Pre]` `[Post]`

| Parameter | Description |
|-----------|-------------|
| `File_Path` |  |
| `Pkg` |  |
| `Success` |  |

### procedure Scan_Project (Target_Dir : Standard.String; Packages : Adacovex.Types.Package_Array; Pkg_Count : Standard.Natural) `[Pre]` `[Post]`

| Parameter | Description |
|-----------|-------------|
| `Packages` | Output array of parsed packages. |
| `Pkg_Count` | Number of packages found. |
| `Target_Dir` | Root directory to scan recursively. |
