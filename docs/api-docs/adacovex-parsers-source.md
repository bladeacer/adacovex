# Adacovex.Parsers.Source

Ada source-file scanner.
Walks a project directory tree, reads every .ads file, extracts
subprogram declarations, HLR tags, and docstring annotations.
HLR-SCAN: Source scanning

Supported docstring annotations (placed immediately before a
subprogram declaration, no intervening blank lines):
@param Name  Description.       -- Document a formal parameter
@return Description.            -- Document a function return value
@field Description.             -- Document a record component
@formal Name  Description.      -- Document a generic formal

Conventions (following Ada_CRDT style):
Prefix:  --   (two dashes + two spaces)
Summary: Capitalized sentence ending with a period.
Alignment: Two spaces between tag name and description text.
Placement: Summary lines first, then tag lines, then declaration.

> **Note:** All items in this package are public.

## Functions

### function Compute_Docstring_Metrics (Packages : Adacovex.Types.Package_Vectors.Vector) return Adacovex.Types.Docstring_Metrics `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Packages` | Vector of scanned packages. |

**Returns:** Aggregate docstring-coverage metrics.

## Procedures

### procedure Apply_Patches (Target_Dir : Standard.String; Packages : Adacovex.Types.Package_Vectors.Vector)

| Parameter | Description |
|-----------|-------------|
| `Packages` | In/out vector of scanned packages to patch. |
| `Target_Dir` | Root directory used for patch path resolution. |

### procedure Scan_Ads_File (File_Path : Standard.String; Pkg : Adacovex.Types.Package_Info; Success : Standard.Boolean) `[Pre]` `[Post]`

| Parameter | Description |
|-----------|-------------|
| `File_Path` |  |
| `Pkg` |  |
| `Success` |  |

### procedure Scan_Project (Target_Dir : Standard.String; Skip_List : Standard.String; Packages : Adacovex.Types.Package_Vectors.Vector)

| Parameter | Description |
|-----------|-------------|
| `Packages` | Output vector of parsed packages (appended to). |
| `Skip_List` | Comma-separated directory names to skip (e.g. ".git,obj"). |
| `Target_Dir` | Root directory to scan recursively. |
