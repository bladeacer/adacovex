# Adacovex.CPUs

Host CPU / parallelism helpers for adacovex.
Detects the number of logical CPUs across the platforms Alire supports
(Linux, macOS, FreeBSD, and Windows) using only the GNAT runtime, so the
crate stays zero-dependency.  Also resolves the default GNATprove job
count: leave two cores free for system responsiveness on a developer
machine, but use every core inside CI.
HLR-CPU: Cross-platform CPU core detection

**See also:** [Platforms](../platforms.md)

> **Note:** 6 public item(s) shown below; 4 private internal item(s) are in the `private` section.

## Functions

### function Default_Prove_Jobs (Cores : Standard.Natural; In_CI : Standard.Boolean) return Standard.Natural `[Post]` `[Global]` `[SPARK]`

| Parameter | Description |
|-----------|-------------|
| `Cores` | Detected logical CPU count. |
| `In_CI` | Whether the run is inside CI. |

**Returns:** Default job count.

### function Detect_Core_Count return Standard.Natural

**Returns:** Logical CPU count (>= 1).

### function Is_Running_In_CI return Standard.Boolean

**Returns:** True when running inside CI.

### function Jobs_Justification (Configured : Standard.Integer; Cores : Standard.Natural; In_CI : Standard.Boolean) return Standard.String `[Global]` `[SPARK]`

| Parameter | Description |
|-----------|-------------|
| `Configured` | The --jobs integer from the CLI. |
| `Cores` | Detected logical CPU count. |
| `In_CI` | Whether the run is inside CI. |

**Returns:** Justification string (no trailing newline).

### function Resolve_Jobs (Configured : Standard.Integer; In_CI : Standard.Boolean) return Standard.Natural

| Parameter | Description |
|-----------|-------------|
| `Configured` | The --jobs integer from the CLI (-1 = auto). |
| `In_CI` | Whether the run is inside CI. |

**Returns:** Resolved job count (>= 1).

## Procedures

### procedure Run_Capture (Cmd : Standard.String; Out_Line : Standard.String; Out_Len : Standard.Natural; Ok : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Cmd` |  |
| `Ok` |  |
| `Out_Len` |  |
| `Out_Line` |  |

---

## Private Section

- **procedure** `Run_Capture`
- **variable** `Out_Line`
- **variable** `Out_Len`
- **variable** `Ok`
