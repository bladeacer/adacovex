# Adacovex.Parsers.DO178C

Parser for DO-178C requirements documents.
Reads HLR.md and LLR.md markdown files, extracts HLR/LLR identifiers
and descriptions, and matches HLR tags found in source code.
HLR-COMPLIANCE: HLR/LLR parsing

**See also:** [DAL Levels](adacovex-dal-levels.md) | [Docstring Spec -- HLR tags](adacovex-docstring-spec.md#hlr-traceability-tags)

> **Note:** All items in this package are public.

## Types

### type HLR_Info

```ada
type HLR_Info is record
Id     : String (1 .. Types.Max_Id_Str);
Id_Len : Natural := 0;
Desc   : String (1 .. Types.Max_Desc_Str);
D_Len  : Natural := 0;
end record;
```

### type LLR_Info

```ada
type LLR_Info is record
Id      : String (1 .. Types.Max_Id_Str);
Id_Len  : Natural := 0;
HLR_Ref : String (1 .. Types.Max_Id_Str);
HLR_Len : Natural := 0;
Desc    : String (1 .. Types.Max_Desc_Str);
D_Len   : Natural := 0;
end record;
```

## Functions

### function Find_HLR_In_Source (HLR_Id : Standard.String; Packages : Adacovex.Types.Implementation.Package_Vectors.Vector) return Standard.Boolean `[Global]`

| Parameter | Description |
|-----------|-------------|
| `HLR_Id` | HLR identifier to search for. |
| `Packages` | Vector of scanned packages. |

**Returns:** True if HLR_Id appears as a source-code tag in any package.

## Procedures

### procedure Parse_HLR_MD (File_Path : Standard.String; HLRs : Adacovex.Parsers.DO178C.HLR_Vectors.Vector; Success : Standard.Boolean; Use_Cache : Standard.Boolean) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `File_Path` | Path to HLR.md markdown file. |
| `HLRs` | Output vector of HLR entries (appended to). |
| `Success` | True if file was parsed successfully. |
| `Use_Cache` | When True, serve/store the result in the on-disk |

### procedure Parse_LLR_MD (File_Path : Standard.String; LLRs : Adacovex.Parsers.DO178C.LLR_Vectors.Vector; Success : Standard.Boolean; Use_Cache : Standard.Boolean) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `File_Path` | Path to LLR.md markdown file. |
| `LLRs` | Output vector of LLR entries (appended to). |
| `Success` | True if file was parsed successfully. |
| `Use_Cache` | When True, serve/store the result in the on-disk |
