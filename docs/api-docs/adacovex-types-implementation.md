# Adacovex.Types.Implementation

All domain types used across the adacovex tool chain. Package and subprogram collections use Ada.Containers.Vectors (unbounded, up to Natural'Last ~ 2.1B). Fixed-size buffers (Max_Path, Max_Line, Max_Desc_Str, etc.) are bounded at compile time with generous production-suitable limits (Max_Path=4096, Max_Line=262144 on a 64-bit host). Max_Path and Max_Line scale with the host word size (System.Word_Size) so builds on narrower hosts use proportionally smaller limits; Max_Line is large enough to read single-line declarations from heavily generated Ada sources without silently draining them. HLR-METRICS: Docstring_Metrics type HLR-PROOF: Proof_Summary type HLR-TEST: Test_Summary type HLR-COMPLIANCE: DAL_Assessment type HLR-DAL-A: DAL_Level (DAL_A) HLR-DAL-B: DAL_Level (DAL_B) HLR-DAL-C: DAL_Level (DAL_C) HLR-DAL-D: DAL_Level (DAL_D) HLR-DAL-E: DAL_Level (DAL_E) HLR-SBOM: SBOM component and format types

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

### type Component_Info

```ada
type Component_Info is record
Ref             : Path_Field;
Ref_Len         : Natural := 0;
Name            : Desc_Field;
Name_Len        : Natural := 0;
Version         : Desc_Field;
Version_Len     : Natural := 0;
License         : Desc_Field;
License_Len     : Natural := 0;
PURL            : Path_Field;
PURL_Len        : Natural := 0;
Description     : Path_Field;
Description_Len : Natural := 0;
Kind            : Component_Kind := Dependency_Component;
Parent          : Natural := 0;
From_GPR        : Boolean := False;
Scope           : Component_Scope := Scope_Transitive;
end record;
```

### type DAL_Assessment

```ada
type DAL_Assessment is record
Target_DAL             : DAL_Level := DAL_C;
Standard               : Compliance_Standard := DO_178C;
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

### type Test_Summary

```ada
type Test_Summary is record
Categories   : Test_Metrics_Vectors.Vector;
Total_Passed : Natural := 0;
Total_Failed : Natural := 0;
end record;
```
