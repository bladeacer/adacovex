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

> One high-level requirement read from HLR.md: its identifier and its description, each with a length field.

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

> One low-level requirement read from LLR.md: its identifier, the HLR identifier it refines, and its description, each with a length field.

## Functions

### function Find_HLR_In_Source (HLR_Id : Standard.String; Packages : Adacovex.Types.Implementation.Package_Vectors.Vector) return Standard.Boolean `[Global]`

> Check whether an HLR identifier appears as a source-code tag anywhere in the scanned package set. Searches the HLR_Tags array of every scanned package for a match.

| Parameter | Description |
|-----------|-------------|
| `HLR_Id` | HLR identifier to search for. |
| `Packages` | Vector of scanned packages. |

**Returns:** True if HLR_Id appears as a source-code tag in any package.

## Procedures

### procedure Parse_HLR_MD (File_Path : Standard.String; HLRs : Adacovex.Parsers.DO178C.HLR_Vectors.Vector; Success : Standard.Boolean; Use_Cache : Standard.Boolean) `[Pre]`

> Parse an HLR.md file, extracting HLR entries and descriptions. Scans a Markdown file for lines matching "HLR_xxxx: Description", storing entries in the output vector. With Use_Cache the parsed vector is keyed in the on-disk result cache by the file's content hash (SHA-256). An unchanged HLR.md is then served without re-parsing.

| Parameter | Description |
|-----------|-------------|
| `File_Path` | Path to HLR.md markdown file. |
| `HLRs` | Output vector of HLR entries (appended to). |
| `Success` | True if file was parsed successfully. |
| `Use_Cache` | When True, serve/store the result in the on-disk result cache keyed by file content; when False, always re-parse. |

### procedure Parse_LLR_MD (File_Path : Standard.String; LLRs : Adacovex.Parsers.DO178C.LLR_Vectors.Vector; Success : Standard.Boolean; Use_Cache : Standard.Boolean) `[Pre]`

> Parse an LLR.md file, extracting LLR_xxxx entries with HLR references. Scans a Markdown file for lines matching "LLR_xxxx: Description". The HLR_xxxx reference is included. Entries are stored in the output vector. With Use_Cache the parsed vector is keyed in the on-disk result cache by the file's content hash (SHA-256).

| Parameter | Description |
|-----------|-------------|
| `File_Path` | Path to LLR.md markdown file. |
| `LLRs` | Output vector of LLR entries (appended to). |
| `Success` | True if file was parsed successfully. |
| `Use_Cache` | When True, serve/store the result in the on-disk result cache keyed by file content; when False, always re-parse. |
