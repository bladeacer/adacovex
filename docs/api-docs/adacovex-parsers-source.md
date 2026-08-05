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

Standard tag aliases are accepted (``@parameter`` == ``@param``,
``@returns`` == ``@return``), and the summary tags ``@brief`` / ``@summary``
mark a subprogram as documented.

Conventions (following Ada_CRDT style):
Prefix:  --   (two dashes + two spaces)
Summary: Capitalized sentence ending with a period.
Alignment: Two spaces between tag name and description text.
Placement: Summary lines first, then tag lines, then declaration.

Other standard comment styles are also recognized as docstrings:
--  one-line summary (single space, ``-- ``)
--  one-line summary (two spaces, ``--  ``)
--  one-line summary (tab separator)
A bare ``--`` or ``---`` divider is not a docstring.  Docstrings may
appear before or after the declaration.

Google style (Doxygen-free Python convention):
--  Args:
--      X (int):  First operand.
--  Returns:
--      The sum.
An "Args:" header opens a parameter block: deeper-indented comment lines
inside it count as parameter entries.  "Returns:" marks a documented
return value.

Sphinx style (reStructuredText field lists):
--  :param X:  First operand.
--  :returns: The sum.
":param"/":parameter" count as parameters, ":return"/":returns" mark a
documented return value, and ":type"/":rtype" mark the subprogram as
documented.

> **Note:** All items in this package are public.

## Functions

### function Compute_Docstring_Metrics (Packages : Adacovex.Types.Implementation.Package_Vectors.Vector) return Adacovex.Types.Docstring_Metrics `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Packages` | Vector of scanned packages. |

**Returns:** Aggregate docstring-coverage metrics.

## Procedures

### procedure Apply_Patches (Target_Dir : Standard.String; Packages : Adacovex.Types.Implementation.Package_Vectors.Vector)

| Parameter | Description |
|-----------|-------------|
| `Packages` | In/out vector of scanned packages to patch. |
| `Target_Dir` | Root directory used for patch path resolution. |

### procedure Scan_Ads_File (File_Path : Standard.String; Pkg : Adacovex.Types.Implementation.Package_Info; Success : Standard.Boolean) `[Pre]` `[Post]`

| Parameter | Description |
|-----------|-------------|
| `File_Path` |  |
| `Pkg` |  |
| `Success` |  |

### procedure Scan_Project (Target_Dir : Standard.String; Skip_List : Standard.String; Packages : Adacovex.Types.Implementation.Package_Vectors.Vector)

| Parameter | Description |
|-----------|-------------|
| `Packages` | Output vector of parsed packages (appended to). |
| `Skip_List` | Comma-separated directory names to skip (e.g. ".git,obj"). |
| `Target_Dir` | Root directory to scan recursively. |
