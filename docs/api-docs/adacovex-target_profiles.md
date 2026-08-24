# Adacovex.Target_Profiles

Signed two's-complement fixed-width integer types.  Each carries an
explicit Size.  IR values map one-to-one onto target machine types.

> **Note:** All items in this package are public.

## Types

### type IR_Int16

```ada
type IR_Int16 is range -2**15 .. 2**15 - 1 with Size => 16;
```

### type IR_Int32

```ada
type IR_Int32 is range -2**31 .. 2**31 - 1 with Size => 32;
```

### type IR_Int64

```ada
type IR_Int64 is range -2**63 .. 2**63 - 1 with Size => 64;
```

### type IR_Int8

```ada
type IR_Int8 is range -2**7 .. 2**7 - 1 with Size => 8;
```

### type IR_UInt16

```ada
type IR_UInt16 is mod 2**16;
```

### type IR_UInt32

```ada
type IR_UInt32 is mod 2**32;
```

### type IR_UInt64

```ada
type IR_UInt64 is mod 2**64;
```

### type IR_UInt8

```ada
type IR_UInt8 is mod 2**8;
```

### type Target_Config

```ada
type Target_Config is record
Host_Bits    : Word_Size := Bits_64;
Target_Bits  : Word_Size := Bits_64;
Pointer_Bits : Word_Size := Bits_64;
end record;
```

### type Word_Size

```ada
type Word_Size is (Bits_8, Bits_16, Bits_32, Bits_64);
```

## Functions

### function Checked_Add32 (A : Adacovex.Target_Profiles.IR_Int32; B : Adacovex.Target_Profiles.IR_Int32) return Adacovex.Target_Profiles.IR_Int32 `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `A` | First operand. |
| `B` | Second operand. |

**Returns:** The sum of A and B.

### function Checked_Add64 (A : Adacovex.Target_Profiles.IR_Int64; B : Adacovex.Target_Profiles.IR_Int64) return Adacovex.Target_Profiles.IR_Int64 `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `A` | First operand. |
| `B` | Second operand. |

**Returns:** The sum of A and B.

### function Host_Word_Size return Adacovex.Target_Profiles.Word_Size `[Global]`

**Returns:** Bits_8 .. Bits_64 matching the host word size.
