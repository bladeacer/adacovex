# Adacovex.IR_Synthesiser

Longest synthesized declaration line.

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

### function Synthesize_Package (Pkg_Name : Standard.String; Type_Names : Standard.String; Cfg : Adacovex.Target_Profiles.Target_Config) return Standard.String `[Pre]` `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Cfg` | Host/target word-size configuration. |
| `Pkg_Name` | Name of the synthesized package. |
| `Type_Names` | Comma-separated foreign type names. |

**Returns:** The synthesized package text.
