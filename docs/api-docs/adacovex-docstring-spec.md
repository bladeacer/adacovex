# Docstring Annotation Specification

## Supported Tags

Tags are placed immediately before the subprogram declaration (canonical Ada
convention). Placement is also supported after the declaration for backward
compatibility. No blank lines between tags and declaration.

| Tag | Format | Purpose |
|-----|--------|---------|
| `@param` | `--  @param Name  Description.` | Subprogram formal parameter |
| `@parameter` | `--  @parameter Name  Description.` | Alias of `@param` |
| `@return` | `--  @return Description.` | Function return value |
| `@returns` | `--  @returns Description.` | Alias of `@return` |
| `@field` | `--  @field Description.` | Record component |
| `@formal` | `--  @formal Name  Description.` | Generic formal parameter |
| `@brief` | `--  @brief Summary.` | Short summary; marks a subprogram documented |
| `@summary` | `--  @summary Description.` | Summary; marks a subprogram documented |

## Conventions

- Prefix: `--  ` (two dashes + two spaces) for all doc lines. The single-space
  `-- ` and tab-separated (`--<TAB>`) comment styles are also recognised, so
  generated or third-party code using those conventions counts toward coverage.
  A bare `--` or `---` (divider) line is **not** a docstring.
- Summary first, then tag lines, then declaration -- no blank lines.
- Descriptions capitalized, end with period.
- Two spaces between tag name and description (alignment padding).
- A plain summary line (`--  Does a thing.`) is sufficient to mark a subprogram
  as documented; tags are not required for no-param procedures.

## Examples

```ada
-- Returns the sum of two numbers.
-- @param A  First operand.
-- @param B  Second operand.
-- @return  Sum of A and B.
function Add (A, B : Integer) return Integer;
```

`@parameter` / `@returns` aliases and the common single-space style are
equivalent:

```ada
-- Increments the counter.
-- @parameter Amount  Amount to add (alias of @param).
-- @returns The new value (alias of @return).
function Incr (Amount : Natural) return Natural;
```

```ada
-- A clock timestamp with node ID.
-- @field Node    Replica identifier.
-- @field Time    Logical timestamp value.
type Clock_Time is record
   Node : Replica_Id;
   Time : Natural;
end record;
```

```ada
-- Generic priority queue.
-- @formal Element_Type  Queue element type.
-- @formal Max_Size      Maximum number of elements.
package Priority_Queue is
   ...
end Priority_Queue;
```

## Google / Sphinx styles

The scanner also recognises the two most common non-Ada docstring conventions,
so the same subprogram can be documented in Ada, Google, or Sphinx style.

### Google style

A `Args:` or `Args: ...` header opens a parameter block: deeper-indented
following comment lines count as parameters. A `Returns:` header marks the
return-value description.

```ada
-- Do something useful.
--
-- Args:
--   X:  The first argument.
--
-- Returns:
--   The result.
function Foo (X : Integer) return Integer;
```

### Sphinx style

`:param Name:`, `:parameter Name:`, `:type Name:`, `:return:`, `:returns:`,
and `:rtype:` fields are all recognised.

```ada
-- Do something else.
--
-- :param X: The argument.
-- :returns: The result.
function Bar (X : Integer) return Integer;
```

## Coverage

Docstring coverage measures: documented subprograms / total subprograms.
A subprogram is "documented" if it has at least one docstring annotation tag,
a `@brief` / `@summary` tag, or a summary comment line (any recognised prefix)
immediately preceding or following it.

Coverage is displayed in terminal reports and SVG badges.

## HLR traceability tags

HLR (High-Level Requirement) tags use the format `-- HLR-XXXX` on their own
comment line:

```ada
--  HLR-SCAN: Source scanning
```

Multiple HLR tags can appear on one line:

```ada
--  HLR-ARCH: Version constant  HLR-ARCH: Package hierarchy
```

Tag IDs map to the requirement index in `docs/compliance/HLR.md`; the scanner matches
in-source tags against that index for the DO-178C traceability assessment.

## See also

- [Target projects](../usage/target-projects.md) -- what a target must provide, and
  how strict mode counts vendored code
- [Architecture -- Patch System](../contributing/architecture-verification.md#patch-system) -- overlay
  docstrings on vendored code without modifying the originals
- [DAL Levels](adacovex-dal-levels.md) -- how HLR tags feed the traceability
  criterion of the compliance assessment
