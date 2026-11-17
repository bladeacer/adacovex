# Adacovex.Ansi

Shared ANSI colour helper for adacovex stdout.

adacovex colours its terminal output to make the important lines stand
out. Colour is disabled automatically when the output would not take it:
inside CI (``CI``), under ``NO_COLOR``, or with ``TERM=dumb``. This keeps CI
logs plain and machine-readable. adacovex is NO_COLOR-clean and never
emits escape codes when the environment opts out.
HLR-ANSI: Terminal colour support

> **Note:** All items in this package are public.

## Functions

### function Blue (S : Standard.String) return Standard.String

> Wrap S in the blue SGR sequence when colour is enabled.

| Parameter | Description |
|-----------|-------------|
| `S` | Text to colour. |

**Returns:** S wrapped in the blue SGR sequence, or S unchanged.

### function Bold (S : Standard.String) return Standard.String

> Bold S when colour is enabled.

| Parameter | Description |
|-----------|-------------|
| `S` | Text to embolden. |

**Returns:** S wrapped in the bold SGR sequence, or S unchanged.

### function Colour_Allowed (CI_Set : Standard.Boolean; No_Color_Set : Standard.Boolean; Term_Dumb : Standard.Boolean) return Standard.Boolean

> Decide whether colour is allowed for a run from the environment signals. Colour is allowed unless a CI variable is set, NO_COLOR is set, or TERM is "dumb" (or empty). This is the pure, testable core of Init; it never touches the environment itself.

| Parameter | Description |
|-----------|-------------|
| `CI_Set` | True when a CI variable is present in the environment. |
| `No_Color_Set` | True when NO_COLOR is present in the environment. |
| `Term_Dumb` | True when TERM is "dumb" (or set to an empty value). |

**Returns:** True when colour is allowed for this run.

### function Dim (S : Standard.String) return Standard.String

> Dim S when colour is enabled.

| Parameter | Description |
|-----------|-------------|
| `S` | Text to dim. |

**Returns:** S wrapped in the dim SGR sequence, or S unchanged.

### function Green (S : Standard.String) return Standard.String

> Wrap S in the green SGR sequence when colour is enabled.

| Parameter | Description |
|-----------|-------------|
| `S` | Text to colour. |

**Returns:** S wrapped in the green SGR sequence, or S unchanged.

### function Red (S : Standard.String) return Standard.String

> Wrap S in the requested ANSI SGR sequence when colour is enabled, returning S unchanged otherwise.

| Parameter | Description |
|-----------|-------------|
| `S` | Text to colour. |

**Returns:** S wrapped in the red SGR sequence, or S unchanged.

### function Yellow (S : Standard.String) return Standard.String

> Wrap S in the yellow SGR sequence when colour is enabled.

| Parameter | Description |
|-----------|-------------|
| `S` | Text to colour. |

**Returns:** S wrapped in the yellow SGR sequence, or S unchanged.

## Procedures

### procedure Init

> Resolve colour support once from the environment: enabled unless NO_COLOR is set, a CI variable is set, or TERM is "dumb". Idempotent.
