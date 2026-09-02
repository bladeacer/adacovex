# Adacovex.IR_Synthesiser

Longest synthesised declaration line.

> **Note:** All items in this package are public.

## Functions

### function IR_Type_Name (Name : Standard.String; Cfg : Adacovex.Target_Profiles.Target_Config) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Cfg` | Host/target word-size configuration. |
| `Name` | Foreign type name (case-sensitive). |

**Returns:** "IR_Int32" for "int32_t", "IR_UInt64" for "size_t" on a 64-bit

### function Lower_Type_Name (Name : Standard.String; Cfg : Adacovex.Target_Profiles.Target_Config) return Standard.String `[Pre]` `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Cfg` | Host/target word-size configuration. |
| `Name` | Foreign type name (case-sensitive). |

**Returns:** "type int32_t is new [`Adacovex.Target_Profiles.IR_Int32`](adacovex-target_profiles.md#type-ir_int32);",

### function Synthesize_Bounded_Function (Name : Standard.String; Param_List : Standard.String; Return_Type : Standard.String) return Standard.String `[Pre]` `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Name` | Subprogram name (an Ada identifier). |
| `Param_List` | Comma-separated "P:Type" pairs, no spaces.  Type |
| `Return_Type` | IR_* name of the result; "" emits a procedure. |

**Returns:** The synthesised spec text (a function or procedure spec with

### function Synthesize_Package (Pkg_Name : Standard.String; Type_Names : Standard.String; Cfg : Adacovex.Target_Profiles.Target_Config) return Standard.String `[Pre]` `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Cfg` | Host/target word-size configuration. |
| `Pkg_Name` | Name of the synthesised package. |
| `Type_Names` | Comma-separated foreign type names. |

**Returns:** The synthesised package text.
