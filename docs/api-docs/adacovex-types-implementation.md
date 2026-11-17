# Adacovex.Types.Implementation

Non-SPARK container types. SPARK forbids instantiating the
non-formal Ada.Containers in SPARK_Mode On code: gnatprove rejects
such instantiations ("not allowed in SPARK (due to entity declared
with SPARK_Mode Off)"; see docs/proof/16.1.0-ledger.md). This
package and Adacovex.Complexity are the only two SPARK_Mode (Off)
packages in the codebase, both for the same reason.

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

> The values the SVG badges render: the SPARK level, the test summary, the compliance assessment, and which badges to emit.

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
Language        : Desc_Field;
Language_Len    : Natural := 0;
Website         : Path_Field;
Website_Len     : Natural := 0;
Kind            : Component_Kind := Dependency_Component;
Parent          : Natural := 0;
From_GPR        : Boolean := False;
Scope           : Component_Scope := Scope_Transitive;
Scope_Flags     : Dependency_Scope_Flags;
end record;
```

> A single component of a software bill of materials (SBOM). The root project occupies index 1. Dependency components reference their parent by vector index (0 = direct dependency of the root).

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

> The compliance verdict for one standard and one target level, with the evidence that produced it and the reasons any criterion failed.

### type Package_Info

```ada
type Package_Info is record
Name        : Name_Field;
Name_Len    : Natural := 0;
File_Path   : Path_Field;
Path_Len    : Natural := 0;
Subprograms : Subprogram_Vectors.Vector;
HLR_Tags    : HLR_Tag_Vectors.Vector;
Docstrings_Opt_Out : Boolean := False;
end record;
```

> One scanned Ada package: its name and path, the subprograms it declares, and the HLR tags its files mention.

### type Spark_Coverage_Group

```ada
type Spark_Coverage_Group is record
Key               : Path_Field;
Key_Len           : Natural := 0;
Stmts_Total       : Natural := 0;
Stmts_Proved      : Natural := 0;
Stmts_Not_Covered : Natural := 0;
Subs_Total        : Natural := 0;
Subs_Proved       : Natural := 0;
Checks_Total      : Natural := 0;
Checks_Proved     : Natural := 0;
Warnings          : Natural := 0;
Off_Irreducible   : Natural := 0;
Off_IO_Bound      : Natural := 0;
Off_Work_Queue    : Natural := 0;
Not_Covered_Subs  : Natural := 0;
Unit_Ct           : Natural := 0;
end record;
```

> SPARK coverage rolled up over a group of units (one file, one folder, or one Ada package). Every count is a sum, so a group percentage is always a ratio of sums and never a mean of its children.

### type Spark_Coverage_Totals

```ada
type Spark_Coverage_Totals is record
Stmts_Total       : Natural := 0;
Stmts_Proved      : Natural := 0;
Stmts_Not_Covered : Natural := 0;
Subs_Total        : Natural := 0;
Subs_Proved       : Natural := 0;
Checks_Total      : Natural := 0;
Checks_Proved     : Natural := 0;
Warnings          : Natural := 0;
Off_Irreducible   : Natural := 0;
Off_IO_Bound      : Natural := 0;
Off_Work_Queue    : Natural := 0;
Not_Covered_Subs  : Natural := 0;
Unit_Ct           : Natural := 0;
end record;
```

> The whole-tree rollup: the group with the empty key.

### type Spark_Coverage_Unit

```ada
type Spark_Coverage_Unit is record
Name              : Name_Field;
Name_Len          : Natural := 0;
Folder            : Path_Field;
Folder_Len        : Natural := 0;
File              : Path_Field;
File_Len          : Natural := 0;
Stmts_Total       : Natural := 0;
Stmts_Proved      : Natural := 0;
Stmts_Not_Covered : Natural := 0;
Subs_Total        : Natural := 0;
Subs_Proved       : Natural := 0;
Checks_Total      : Natural := 0;
Checks_Proved     : Natural := 0;
Warnings          : Natural := 0;
Not_Covered_Subs  : Natural := 0;
Off_Irreducible   : Natural := 0;
Off_IO_Bound      : Natural := 0;
Off_Work_Queue    : Natural := 0;
Body_Subs         : Natural := 0;
In_Proof_Run      : Boolean := False;
end record;
```

> SPARK coverage of one Ada source unit (one package, keyed by the base name of its source files). Three metrics are recorded per unit, each with its own numerator and denominator: Stmts_Total / Stmts_Proved   statement coverage (executable statements in the unit's body) Subs_Total / Subs_Proved     subprogram coverage (subprograms gnatprove considered in the unit) Checks_Total / Checks_Proved VC coverage (checks the prover reported, passed or not) A unit gnatprove never reported on holds the zero values, so the Not_Covered count is always derived (see Adacovex.Spark_Coverage) and never a stored total that can drift from its parts.

### type Spark_Entity_Rec

```ada
type Spark_Entity_Rec is record
Name     : Name_Field;
Name_Len : Natural := 0;
Class    : Spark_Off_Class := Off_None;
end record;
```

> One named SPARK entity as gnatprove reports it: the qualified Ada name, and (for a skipped entity) the off class this report derived for it. A proved entity is recorded with Off_None.

### type Spark_Skip_Rec

```ada
type Spark_Skip_Rec is record
Name     : Name_Field;
Name_Len : Natural := 0;
File     : Name_Field;
File_Len : Natural := 0;
Line     : Natural := 0;
end record;
```

> One skipped entity as gnatprove reports it: its qualified Ada name, the source file that declares it, and the line the declaration starts on. The line is the entity's first line, so consecutive skip lines in the same file bound the source range that belongs to each unproved subprogram.

### type Test_Summary

```ada
type Test_Summary is record
Categories   : Test_Metrics_Vectors.Vector;
Total_Passed : Natural := 0;
Total_Failed : Natural := 0;
end record;
```

> Every test category with its pass and fail counts, and the totals over all categories.
