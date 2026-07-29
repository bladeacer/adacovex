# Adacovex.Types

All domain types used across the adacovex tool chain.
Package and subprogram collections use Ada.Containers.Vectors
(unbounded, up to Natural'Last ≈ 2.1B). Fixed-size buffers
(Max_Path, Max_Line, Max_Desc_Str, etc.) are bounded at compile time
with generous production-suitable limits (Max_Path=4096, Max_Line=8192).
HLR-METRICS: Docstring_Metrics type
HLR-PROOF: Proof_Summary type
HLR-TEST: Test_Summary type
HLR-COMPLIANCE: DAL_Assessment type
HLR-DAL-A: DAL_Level (DAL_A)
HLR-DAL-B: DAL_Level (DAL_B)
HLR-DAL-C: DAL_Level (DAL_C)
HLR-DAL-D: DAL_Level (DAL_D)
HLR-DAL-E: DAL_Level (DAL_E)

> **Note:** All items in this package are public.

## Types

### type Badge_Config

```ada
type Badge_Config is record
Spark_Lvl   : SPARK_Level := Stone;
Test_Summ   : Test_Summary;
DAL_Assess  : DAL_Assessment;
Show_Spark  : Boolean := True;
Show_Tests  : Boolean := True;
Show_DO178C : Boolean := True;
end record;
```

### type DAL_Assessment

```ada
type DAL_Assessment is record
Target_DAL             : DAL_Level := DAL_C;
Status                 : DAL_Status := Unmet;
HLR_Total              : Natural := 0;
HLR_Found              : Natural := 0;
LLR_Total              : Natural := 0;
LLR_Found              : Natural := 0;
All_Subprograms_Traced : Boolean := False;
Orphan_Tags            : Boolean := False;
Tests_Passing          : Boolean := False;
Min_SPARK_Level_Met    : Boolean := False;
Failed_Reasons         : DAL_Failure_Vectors.Vector;
end record;
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

### type Package_Info

```ada
type Package_Info is record
Name        : Name_Field;
Name_Len    : Natural := 0;
File_Path   : Path_Field;
Path_Len    : Natural := 0;
Subprograms : Subprogram_Vectors.Vector;
HLR_Tags    : HLR_Tag_Vectors.Vector;
end record;
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

### type Test_Summary

```ada
type Test_Summary is record
Categories   : Test_Metrics_Vectors.Vector;
Total_Passed : Natural := 0;
Total_Failed : Natural := 0;
end record;
```

## Functions

### function To_DAL (S : Standard.String) return Adacovex.Types.DAL_Level `[Global]`

| Parameter | Description |
|-----------|-------------|
| `S` | Single-letter DAL code (A-E, case-insensitive). |

**Returns:** Converted DAL_Level (defaults to DAL_C on failure).

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
