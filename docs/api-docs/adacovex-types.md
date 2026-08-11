# Adacovex.Types

Host machine word size in bits, auto-detected from the Ada runtime
(8, 16, 32, or 64).  Fixed-size path/line buffers scale with it so
builds on narrower hosts use proportionally smaller limits.

> **Note:** All items in this package are public.

## Types

### type Component_Kind

```ada
type Component_Kind is (Root_Component, Dependency_Component);
```

### type Component_Scope

```ada
type Component_Scope is
(Scope_Base, Scope_Dev, Scope_Transitive, Scope_Vendored);
```

### type DAL_Level

```ada
type DAL_Level is (DAL_A, DAL_B, DAL_C, DAL_D, DAL_E);
```

### type DAL_Status

```ada
type DAL_Status is (Achieved, Unmet);
```

### type Desc_Field

```ada
subtype Desc_Field is String (1 .. Max_Desc_Str);
```

### type Docstring_Metrics

```ada
type Docstring_Metrics is record
Total_Subprograms   : Natural := 0;
Documented_Subprogs : Natural := 0;
Total_Parameters    : Natural := 0;
Documented_Params   : Natural := 0;
Total_Returns       : Natural := 0;
Documented_Returns  : Natural := 0;
Coverage_Pct        : Natural := 0;
end record;
```

### type HLR_Tag_Entry

```ada
type HLR_Tag_Entry is record
Tag : String (1 .. Max_Id_Str);
Len : Natural := 0;
end record;
```

### type Name_Field

```ada
subtype Name_Field is String (1 .. Max_Filename);
```

### type Path_Field

```ada
subtype Path_Field is String (1 .. Max_Path);
```

### type Proof_Summary

```ada
type Proof_Summary is record
Total_VCs          : Natural := 0;
Proved_VCs         : Natural := 0;
Flow_Checks        : Natural := 0;
Flow_Proved        : Natural := 0;
Init_Checks        : Natural := 0;
Init_Proved        : Natural := 0;
Runtime_Checks     : Natural := 0;
Runtime_Proved     : Natural := 0;
Assertions         : Natural := 0;
Assert_Proved      : Natural := 0;
Functional_Ct      : Natural := 0;
Functional_Proved  : Natural := 0;
Termination_Ct     : Natural := 0;
Termination_Proved : Natural := 0;
Justified          : Natural := 0;
Unproved           : Natural := 0;
Level              : SPARK_Level := Stone;
Units_Analyzed     : Natural := 0;
Units_Skipped      : Natural := 0;
end record;
```

### type SBOM_Format_Kind

```ada
type SBOM_Format_Kind is (CycloneDX_JSON, SPDX_JSON, Markdown);
```

### type SPARK_Level

```ada
type SPARK_Level is (Stone, Bronze, Silver, Gold, Platinum);
```

### type Subprogram_Info

```ada
type Subprogram_Info is record
Name          : Desc_Field;
Name_Len      : Natural := 0;
Line_Number   : Natural := 0;
Has_Docstring : Boolean := False;
Doc_Param_Ct  : Natural := 0;
Has_Return    : Boolean := False;
Doc_Return    : Boolean := False;
end record;
```

### type Test_Metrics

```ada
type Test_Metrics is record
Category   : Desc_Field;
Cat_Len    : Natural := 0;
Test_Count : Natural := 0;
Status     : Test_Status := Pass;
end record;
```

### type Test_Status

```ada
type Test_Status is (Pass, Fail);
```

## Functions

### function To_DAL (S : Standard.String) return Adacovex.Types.DAL_Level `[Global]`

| Parameter | Description |
|-----------|-------------|
| `S` |  |

### function To_String (L : Adacovex.Types.DAL_Level) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `L` |  |

### function To_String (S : Adacovex.Types.DAL_Status) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `S` |  |

### function To_String (L : Adacovex.Types.SPARK_Level) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `L` |  |

### function To_String (S : Adacovex.Types.Test_Status) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `S` |  |
