# Docstring Annotation Specification

## Supported Tags

Tags are placed immediately before the subprogram declaration (canonical Ada
convention). Placement is also supported after the declaration for backward
compatibility. No blank lines between tags and declaration.

| Tag | Format | Purpose |
|-----|--------|---------|
| `@param` | `--  @param Name  Description.` | Subprogram formal parameter |
| `@return` | `--  @return Description.` | Function return value |
| `@field` | `--  @field Description.` | Record component |
| `@formal` | `--  @formal Name  Description.` | Generic formal parameter |

## Conventions

- Prefix: `--  ` (two dashes + two spaces) for all doc lines.
- Summary first, then tag lines, then declaration -- no blank lines.
- Descriptions capitalized, end with period.
- Two spaces between tag name and description (alignment padding).

## Examples

```ada
-- Returns the sum of two numbers.
-- @param A  First operand.
-- @param B  Second operand.
-- @return  Sum of A and B.
function Add (A, B : Integer) return Integer;
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

## Coverage

Docstring coverage measures: documented subprograms / total subprograms.
A subprogram is "documented" if it has at least one docstring annotation tag
or a summary comment immediately preceding it.

Coverage is displayed in terminal reports and SVG badges.
