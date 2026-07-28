# Adacovex.Parsers.DO178C

Parser for DO-178C requirements documents.
Reads HLR.md and LLR.md markdown files, extracts HLR/LLR identifiers
and descriptions, and matches HLR tags found in source code.
HLR-COMPLIANCE: HLR/LLR parsing

> **Note:** All items in this package are public.

## Types

### type HLR_Array

```ada
type HLR_Array is array (1 .. Types.Max_Hlrs) of HLR_Info;
```

### type HLR_Info

```ada
type HLR_Info is record
Id     : String (1 .. Types.Max_Id_Str);
Id_Len : Natural := 0;
Desc   : String (1 .. Types.Max_Desc_Str);
D_Len  : Natural := 0;
end record;
```

### type LLR_Array

```ada
type LLR_Array is array (1 .. Types.Max_Llrs) of LLR_Info;
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

### function Find_HLR_In_Source (HLR_Id : Standard.String; Packages : Adacovex.Types.Package_Array; Pkg_Count : Standard.Natural) return Standard.Boolean `[Pre]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `HLR_Id` | HLR identifier to search for. |
| `Packages` | Array of scanned packages. |
| `Pkg_Count` | Number of packages in array. |

**Returns:** True if HLR_Id appears as a source-code tag in any package.

## Procedures

### procedure Parse_HLR_MD (File_Path : Standard.String; HLRs : Adacovex.Parsers.DO178C.HLR_Array; HLR_Count : Standard.Natural; Success : Standard.Boolean) `[Pre]` `[Post]`

| Parameter | Description |
|-----------|-------------|
| `File_Path` | Path to HLR.md markdown file. |
| `HLR_Count` | Number of HLRs found. |
| `HLRs` | Output array of HLR entries. |
| `Success` | True if file was parsed successfully. |

### procedure Parse_LLR_MD (File_Path : Standard.String; LLRs : Adacovex.Parsers.DO178C.LLR_Array; LLR_Count : Standard.Natural; Success : Standard.Boolean) `[Pre]` `[Post]`

| Parameter | Description |
|-----------|-------------|
| `File_Path` | Path to LLR.md markdown file. |
| `LLR_Count` | Number of LLRs found. |
| `LLRs` | Output array of LLR entries. |
| `Success` | True if file was parsed successfully. |
