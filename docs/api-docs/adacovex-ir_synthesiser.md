# Adacovex.IR_Synthesiser

Longest synthesised declaration line.

> **Note:** All items in this package are public.

## Functions

### function IR_Type_Name (Name : Standard.String; Cfg : Adacovex.Target_Profiles.Target_Config) return Standard.String `[Post]` `[Global]`

> Returns the bounded IR type name a foreign type name lowers onto.

| Parameter | Description |
|-----------|-------------|
| `Cfg` | Host/target word-size configuration. |
| `Name` | Foreign type name (case-sensitive). |

**Returns:** "IR_Int32" for "int32_t", "IR_UInt64" for "size_t" on a 64-bit target; an empty string when the name is not recognised.

### function Lower_Type_Name (Name : Standard.String; Cfg : Adacovex.Target_Profiles.Target_Config) return Standard.String `[Pre]` `[Post]` `[Global]`

> Synthesize a bounded Ada type declaration for a foreign type name.

| Parameter | Description |
|-----------|-------------|
| `Cfg` | Host/target word-size configuration. |
| `Name` | Foreign type name (case-sensitive). |

**Returns:** "type int32_t is new [`Adacovex.Target_Profiles.IR_Int32`](adacovex-target_profiles.md#type-ir_int32);", or an empty string when the name is not recognised.

### function Synthesize_Bounded_Function (Name : Standard.String; Param_List : Standard.String; Return_Type : Standard.String) return Standard.String `[Pre]` `[Post]` `[Global]`

> Synthesises a contract-carrying bounded-function spec from a foreign-style signature. This is the multi-pair form of a gnatprove-friendly IR: it lowers every comma-separated "P:Type" parameter pair onto a bounded IR scalar type and joins the signed pairs' half-range Pre guards with "and then" into one contract chain, the guard shape gnatprove discharges for the checked arithmetic (the same guard as Adacovex.Target_Profiles.Checked_Add32 / the Adacovex.IR_Bounds fixture). Unsigned (modular) parameters carry no guard. Lowered code carries its contracts in the generated text, so a proof run checks only bounded-scalar arithmetic instead of foreign semantics. The three-pass design and the full exploration are documented in docs/contributing/ir.md.

| Parameter | Description |
|-----------|-------------|
| `Name` | Subprogram name (an Ada identifier). |
| `Param_List` | Comma-separated "P:Type" pairs, no spaces, at most 32 pairs. Each Type is an IR_* name (IR_Int32, IR_UInt64, ...). An empty list emits the nullary spec. |
| `Return_Type` | IR_* name of the result; "" emits a procedure. |

**Returns:** The synthesised spec text (a function or procedure spec with an optional Pre contract), or "" when Name is empty, any pair is malformed (no ':', embedded whitespace, or a type that is not a bounded IR type name), or the list holds more than 32 pairs.

### function Synthesize_Package (Pkg_Name : Standard.String; Type_Names : Standard.String; Cfg : Adacovex.Target_Profiles.Target_Config) return Standard.String `[Pre]` `[Post]` `[Global]`

> Synthesises a package skeleton that holds the lowered declarations for each comma-separated foreign type name.

| Parameter | Description |
|-----------|-------------|
| `Cfg` | Host/target word-size configuration. |
| `Pkg_Name` | Name of the synthesised package. |
| `Type_Names` | Comma-separated foreign type names. |

**Returns:** The synthesised package text.
