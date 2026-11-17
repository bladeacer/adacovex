# Adacovex.Target_Profiles

Signed two's-complement fixed-width integer types. Each carries an
explicit Size. IR values map one-to-one onto target machine types.
Signed 8-bit integer, lowered from int8_t and similar names.

> **Note:** All items in this package are public.

## Types

### type IR_Int16

```ada
type IR_Int16 is range -2**15 .. 2**15 - 1 with Size => 16;
```

> Signed 32-bit integer, lowered from int32_t and similar names.

### type IR_Int32

```ada
type IR_Int32 is range -2**31 .. 2**31 - 1 with Size => 32;
```

> Signed 64-bit integer, lowered from int64_t and similar names.

### type IR_Int64

```ada
type IR_Int64 is range -2**63 .. 2**63 - 1 with Size => 64;
```

> Signed 64-bit integer, lowered from int64_t and similar names.

### type IR_Int8

```ada
type IR_Int8 is range -2**7 .. 2**7 - 1 with Size => 8;
```

> Signed 16-bit integer, lowered from int16_t and similar names.

### type IR_UInt16

```ada
type IR_UInt16 is mod 2**16;
```

> Unsigned 32-bit integer, lowered from uint32_t, size_t, and similar

### type IR_UInt32

```ada
type IR_UInt32 is mod 2**32;
```

> Unsigned 64-bit integer, lowered from uint64_t, usize, and similar

### type IR_UInt64

```ada
type IR_UInt64 is mod 2**64;
```

> Unsigned 64-bit integer, lowered from uint64_t, usize, and similar names.

### type IR_UInt8

```ada
type IR_UInt8 is mod 2**8;
```

> Unsigned 16-bit integer, lowered from uint16_t and similar names.

### type Target_Config

```ada
type Target_Config is record
Host_Bits    : Word_Size := Bits_64;
Target_Bits  : Word_Size := Bits_64;
Pointer_Bits : Word_Size := Bits_64;
end record;
```

> Host vs. target machine model: Host_Bits    -- Word size of the machine on which adacovex itself -- executes. Target_Bits  -- Word size of the target being synthesised. Pointer_Bits -- Target pointer width (it drives size_t / usize).

### type Word_Size

```ada
type Word_Size is (Bits_8, Bits_16, Bits_32, Bits_64);
```

> A machine word size, in bits.

## Functions

### function Checked_Add32 (A : Adacovex.Target_Profiles.IR_Int32; B : Adacovex.Target_Profiles.IR_Int32) return Adacovex.Target_Profiles.IR_Int32 `[Pre]`

> Bounds-checked 32-bit addition. Restricting both operands to the inner half of the range guarantees the sum is representable. gnatprove discharges the overflow check and proves absence of integer overflow.

| Parameter | Description |
|-----------|-------------|
| `A` | First operand. |
| `B` | Second operand. |

**Returns:** The sum of A and B.

### function Checked_Add64 (A : Adacovex.Target_Profiles.IR_Int64; B : Adacovex.Target_Profiles.IR_Int64) return Adacovex.Target_Profiles.IR_Int64 `[Pre]`

> Bounds-checked 64-bit addition, analogous to Checked_Add32.

| Parameter | Description |
|-----------|-------------|
| `A` | First operand. |
| `B` | Second operand. |

**Returns:** The sum of A and B.

### function Host_Word_Size return Adacovex.Target_Profiles.Word_Size `[Global]`

> Auto-detects the host machine word size from the Ada runtime (System.Word_Size: 8, 16, 32, or 64 bits). Callers use it to populate Target_Config.Host_Bits for the machine on which adacovex executes.

**Returns:** Bits_8 .. Bits_64 matching the host word size.
