# Adacovex.Parsers.Source

Ada source-file scanner.
Walks a project directory tree, reads every .ads file, extracts
subprogram declarations, HLR tags, and docstring annotations.
HLR-SCAN: Source scanning

Supported docstring annotations (placed immediately before a
subprogram declaration, no intervening blank lines):
@param Name  Description. -- Document a formal parameter
@return Description. -- Document a function return value
@field Description. -- Document a record component
@formal Name  Description. -- Document a generic formal

Standard tag aliases are accepted (``@parameter`` == ``@param``,
``@returns`` == ``@return``), and the summary tags ``@brief`` / ``@summary``
mark a subprogram as documented.

Conventions (following Ada_CRDT style):
Prefix:  --   (two dashes + two spaces)
Summary: Capitalized sentence ending with a period.
Alignment: Two spaces between tag name and description text.
Placement: Summary lines first, then tag lines, then declaration.

Other standard comment styles are also recognised as docstrings:
--  one-line summary (single space, ``-- ``)
--  one-line summary (two spaces, ``--  ``)
--  one-line summary (tab separator)
A bare ``--`` or ``---`` divider is not a docstring. Docstrings can
appear before or after the declaration.

Google style (Doxygen-free Python convention):
--  Args:
--      X (int):  First operand.
--  Returns:
--      The sum.
An "Args:" header opens a parameter block: deeper-indented comment lines
inside it count as parameter entries. "Returns:" marks a documented
return value.

Sphinx style (reStructuredText field lists):
--  :param X:  First operand.
--  :returns: The sum.
":param"/":parameter" count as parameters, ":return"/":returns" mark a
documented return value, and ":type"/":rtype" mark the subprogram as
documented.

**See also:** [Docstring Spec](adacovex-docstring-spec.md) | [Architecture -- Patch System](../contributing/architecture-verification.md#patch-system)

> **Note:** All items in this package are public.

## Functions

### function Compute_Docstring_Metrics (Packages : Adacovex.Types.Implementation.Package_Vectors.Vector) return Adacovex.Types.Docstring_Metrics `[Global]`

> Compute aggregate docstring-coverage metrics from scanned packages. Tallies documented vs. undocumented subprograms, parameters, and return values across all scanned packages.

| Parameter | Description |
|-----------|-------------|
| `Packages` | Vector of scanned packages. |

**Returns:** Aggregate docstring-coverage metrics.

## Procedures

### procedure Apply_Patches (Target_Dir : Standard.String; Packages : Adacovex.Types.Implementation.Package_Vectors.Vector)

> Apply docstring patches to scanned packages. For each package, checks for a patch file at ``<Target_Dir>/.adacovex/patches/<relative-path>`` and merges its docstring info into the original package's subprograms.

| Parameter | Description |
|-----------|-------------|
| `Packages` | In/out vector of scanned packages to patch. |
| `Target_Dir` | Root directory used for patch path resolution. |

### procedure Scan_Ads_File (File_Path : Standard.String; Pkg : Adacovex.Types.Implementation.Package_Info; Success : Standard.Boolean) `[Pre]` `[Post]`

> Scan a single .ads file, extracting subprogram info and HLR tags. File_Path must name a readable .ads file. On success, Pkg is populated with subprogram declarations, docstring annotations, and HLR tag entries.

| Parameter | Description |
|-----------|-------------|
| `File_Path` | Path to .ads file. |
| `Pkg` | Output package info. |
| `Success` | True if file was successfully parsed. |

### procedure Scan_Project (Target_Dir : Standard.String; Skip_List : Standard.String; Packages : Adacovex.Types.Implementation.Package_Vectors.Vector; Skipped_Ct : Standard.Natural)

> Recursively scan all .ads files under Target_Dir. Walk the directory tree rooted at Target_Dir. Parse every .ads file found. Skip directories whose simple name appears in Skip_List (comma-separated). Append found packages to the vector. Files whose physical lines exceed Types.Max_Line, or whose paths exceed Types.Max_Path, are reported to standard error. They are counted in Skipped_Ct. They do not produce partial results.

| Parameter | Description |
|-----------|-------------|
| `Packages` | Output vector of parsed packages (appended to). |
| `Skip_List` | Comma-separated directory names to skip (e.g. ".git,obj"). |
| `Skipped_Ct` | Number of .ads files skipped (line/path overflow). |
| `Target_Dir` | Root directory to scan recursively. |

### procedure Scan_Project_Cached (Target_Dir : Standard.String; Skip_List : Standard.String; Packages : Adacovex.Types.Implementation.Package_Vectors.Vector; Skipped_Ct : Standard.Natural; Hits : Standard.Natural; Misses : Standard.Natural; Use_Cache : Standard.Boolean)

> Like Scan_Project, but each .ads file is keyed in the on-disk result cache by its content hash (SHA-256). Unchanged files are served from the cache without re-scanning. Changed files are rescanned and the cache entry is refreshed. Hits/Misses report how many files were served from or written to the cache.

| Parameter | Description |
|-----------|-------------|
| `Hits` | Number of files served from the cache. |
| `Misses` | Number of files rescanned and re-cached. |
| `Packages` | Output vector of parsed packages (appended to). |
| `Skip_List` | Comma-separated directory names to skip. |
| `Skipped_Ct` | Number of .ads files skipped (line/path overflow). |
| `Target_Dir` | Root directory to scan recursively. |
| `Use_Cache` | When False the cache is bypassed and every file is rescanned (reported as a miss); caller controls this from --no-cache. |
