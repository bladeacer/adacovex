# Adacovex.Diff

Differential assessment for --compare-base.
Assesses a target project at a git base ref (branch or commit) and at its
current working tree, then reports a side-by-side delta of docstring
coverage, SPARK proof level, test results, HLR traceability, and DO-178C
DAL status so local regressions can be caught before pushing.
HLR-DIFF: Differential assessment

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

### function Assess (Target_Dir : Standard.String; DAL_Target : Adacovex.Types.DAL_Level) return Adacovex.Diff.Assessment_Result

| Parameter | Description |
|-----------|-------------|
| `DAL_Target` | DAL level to assess against. |
| `Target_Dir` | Project root directory to assess. |

**Returns:** Aggregate metrics for the target directory.

### function Assess_Coverage (Target_Dir : Standard.String) return Adacovex.Diff.Coverage_Result

| Parameter | Description |
|-----------|-------------|
| `Target_Dir` | Project root directory. |

**Returns:** Coverage snapshot (documented/total/percentage).

### function Is_Git_Repo (Target_Dir : Standard.String) return Standard.Boolean

| Parameter | Description |
|-----------|-------------|
| `Target_Dir` | Directory to check. |

**Returns:** True if Target_Dir is inside a git work tree.

### function Report_Coverage_Delta (Base : Adacovex.Diff.Coverage_Result; Cur : Adacovex.Diff.Coverage_Result; Base_Ref : Standard.String; Use_Color : Standard.Boolean) return Standard.Boolean

| Parameter | Description |
|-----------|-------------|
| `Base` | Coverage of the base ref. |
| `Base_Ref` | Human-readable name of the base ref. |
| `Cur` | Coverage of the current working tree. |
| `Use_Color` | Enable ANSI color output (default False). |

**Returns:** True if the current coverage regressed versus the base.

### function Report_Delta (Base : Adacovex.Diff.Assessment_Result; Cur : Adacovex.Diff.Assessment_Result; Base_Ref : Standard.String; Use_Color : Standard.Boolean) return Standard.Boolean

| Parameter | Description |
|-----------|-------------|
| `Base` | Assessment of the base ref. |
| `Base_Ref` | Human-readable name of the base ref shown in the report. |
| `Cur` | Assessment of the current working tree. |
| `Use_Color` | Enable ANSI color output (default False). |

**Returns:** True if the current state regressed versus the base.

## Procedures

### procedure Make_Worktree (Target_Dir : Standard.String; Base_Ref : Standard.String; Tmp_Path : Standard.String; Tmp_Len : Standard.Natural; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Base_Ref` | Git branch or commit to check out. |
| `Success` | True if the worktree was created; False on git failure. |
| `Target_Dir` | Root of the target git repository. |
| `Tmp_Len` | Length of the worktree path on success. |
| `Tmp_Path` | Output buffer receiving the worktree path. |

### procedure Remove_Worktree (Target_Dir : Standard.String; Tmp_Path : Standard.String)

| Parameter | Description |
|-----------|-------------|
| `Target_Dir` | Root of the target git repository. |
| `Tmp_Path` | Path of the worktree to remove. |
