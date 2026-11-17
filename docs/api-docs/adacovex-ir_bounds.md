# Adacovex.IR_Bounds

Lowered 32-bit signed type (synthesised declaration).

> **Note:** All items in this package are public.

## Types

### type int32_t

```ada
type int32_t is new Adacovex.Target_Profiles.IR_Int32;
```

> Lowered 32-bit signed type (synthesised declaration).

### type int64_t

```ada
type int64_t is new Adacovex.Target_Profiles.IR_Int64;
```

> Lowered 64-bit signed type (synthesised declaration).

## Functions

### function Add32 (A : Adacovex.IR_Bounds.int32_t; B : Adacovex.IR_Bounds.int32_t) return Adacovex.IR_Bounds.int32_t `[Pre]`

> Bounds-checked addition on the lowered 32-bit type. The inner-half precondition makes the overflow check provably safe.

| Parameter | Description |
|-----------|-------------|
| `A` | First operand. |
| `B` | Second operand. |

**Returns:** The sum of A and B.

### function Add64 (A : Adacovex.IR_Bounds.int64_t; B : Adacovex.IR_Bounds.int64_t) return Adacovex.IR_Bounds.int64_t `[Pre]`

> Bounds-checked addition on the lowered 64-bit type. It is the 64-bit equivalent of Add32.

| Parameter | Description |
|-----------|-------------|
| `A` | First operand. |
| `B` | Second operand. |

**Returns:** The sum of A and B.
