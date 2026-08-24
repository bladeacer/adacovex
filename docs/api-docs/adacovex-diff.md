# Adacovex.Diff

Differential assessment for --compare-base.
It assesses a target project at a base revision.  The base revision is a
branch, commit, rev, or tag in git, mercurial, subversion, fossil, or
jj (see Adacovex.VCS).  It also assesses the current working tree.  It
then reports a side-by-side delta of docstring coverage, SPARK proof
level, test results, HLR traceability, and DO-178C DAL status.  The
report helps you catch local regressions before you push.
HLR-DIFF: Differential assessment

**See also:** [VCS support](../vcs.md)

> **Note:** All items in this package are public.

## Types

### type Assessment_Result

```ada
type Assessment_Result is record
Packages     : Natural := 0;
Subprograms  : Natural := 0;
Documented   : Natural := 0;
Coverage_Pct : Natural := 0;
HLR_Total    : Natural := 0;
HLR_Found    : Natural := 0;
Orphan_Tags  : Boolean := False;
Has_Proof    : Boolean := False;
Total_VCs    : Natural := 0;
Proved_VCs   : Natural := 0;
SPARK_Level  : Types.SPARK_Level := Types.Stone;
Has_Tests    : Boolean := False;
Tests_Passed : Natural := 0;
Tests_Failed : Natural := 0;
DAL_Status   : Types.DAL_Status := Types.Unmet;
Skipped      : Natural := 0;
end record;
```

### type Coverage_Result

```ada
type Coverage_Result is record
Documented : Natural := 0;
Total      : Natural := 0;
Pct        : Natural := 0;
Skipped    : Natural := 0;
end record;
```

## Functions

### function Assess (Target_Dir : Standard.String; DAL_Target : Adacovex.Types.DAL_Level; Use_Cache : Standard.Boolean) return Adacovex.Diff.Assessment_Result

| Parameter | Description |
|-----------|-------------|
| `DAL_Target` | DAL level to assess against. |
| `Target_Dir` | Project root directory to assess. |
| `Use_Cache` | When True the .ads scan and the HLR.md/LLR.md |

**Returns:** Aggregate metrics for the target directory.

### function Assess_Coverage (Target_Dir : Standard.String; Use_Cache : Standard.Boolean) return Adacovex.Diff.Coverage_Result

| Parameter | Description |
|-----------|-------------|
| `Target_Dir` | Project root directory. |
| `Use_Cache` | When True the .ads scan comes from the on-disk result |

**Returns:** Coverage snapshot (documented/total/percentage).

### function Is_Repo (Target_Dir : Standard.String) return Standard.Boolean

| Parameter | Description |
|-----------|-------------|
| `Target_Dir` | Directory to check. |

**Returns:** True if Target_Dir is inside a supported VCS repository.

### function Repo_Kind_Name (Target_Dir : Standard.String) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `Target_Dir` | Directory to check. |

**Returns:** Lowercase VCS name ("" when none is detected).

### function Report_Coverage_Delta (Base : Adacovex.Diff.Coverage_Result; Cur : Adacovex.Diff.Coverage_Result; Base_Ref : Standard.String; Use_Color : Standard.Boolean) return Standard.Boolean

| Parameter | Description |
|-----------|-------------|
| `Base` | Coverage of the base ref. |
| `Base_Ref` | Human-readable name of the base ref. |
| `Cur` | Coverage of the current working tree. |
| `Use_Color` | Enable ANSI colour output (default False). |

**Returns:** True if the current coverage regressed versus the base.

### function Report_Delta (Base : Adacovex.Diff.Assessment_Result; Cur : Adacovex.Diff.Assessment_Result; Base_Ref : Standard.String; Use_Color : Standard.Boolean) return Standard.Boolean

| Parameter | Description |
|-----------|-------------|
| `Base` | Assessment of the base ref. |
| `Base_Ref` | Human-readable name of the base ref shown in the report. |
| `Cur` | Assessment of the current working tree. |
| `Use_Color` | Enable ANSI colour output (default False). |

**Returns:** True if the current state regressed versus the base.

### function UX_Note (Target_Dir : Standard.String) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `Target_Dir` | Directory to check. |

**Returns:** Recommendation text ("" when no note is needed).

## Procedures

### procedure Make_Worktree (Target_Dir : Standard.String; Base_Ref : Standard.String; Tmp_Path : Standard.String; Tmp_Len : Standard.Natural; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Base_Ref` | Branch/commit/rev/tag to check out. |
| `Success` | True if the snapshot was created.  False on failure. |
| `Target_Dir` | Root of the target repository. |
| `Tmp_Len` | Length of the snapshot path on success. |
| `Tmp_Path` | Output buffer receiving the snapshot path. |

### procedure Remove_Worktree (Target_Dir : Standard.String; Tmp_Path : Standard.String)

| Parameter | Description |
|-----------|-------------|
| `Target_Dir` | Root of the target repository. |
| `Tmp_Path` | Path of the snapshot to remove. |
