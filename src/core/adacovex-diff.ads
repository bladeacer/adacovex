with Adacovex.Types;

--  Differential assessment for --compare-base.
--  Assesses a target project at a git base ref (branch or commit) and at its
--  current working tree, then reports a side-by-side delta of docstring
--  coverage, SPARK proof level, test results, HLR traceability, and DO-178C
--  DAL status so local regressions can be caught before pushing.
--  HLR-DIFF: Differential assessment

package Adacovex.Diff is

   --  Compact snapshot of one full assessment run.
   --  Aggregates the metrics needed to compare a base ref against the current
   --  working tree. Has_Proof and Has_Tests indicate whether GNATprove output
   --  and test results were available for the target (they are build
   --  artifacts that may be absent from a freshly checked out base).
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
   end record;

   --  Run the full assessment pipeline against a target directory.
   --  Scans .ads sources, parses GNATprove output and test results, and
   --  assesses DO-178C DAL compliance. Missing proof or test artifacts are
   --  reported via Has_Proof/Has_Tests = False rather than as an error.
   --  @param Target_Dir  Project root directory to assess.
   --  @param DAL_Target  DAL level to assess against.
   --  @return Aggregate metrics for the target directory.
   function Assess
     (Target_Dir : String; DAL_Target : Types.DAL_Level) return Assessment_Result;

   --  Check that a directory is a git repository work tree.
   --  Runs `git -C Target_Dir rev-parse --is-inside-work-tree`.
   --  @param Target_Dir  Directory to check.
   --  @return True if Target_Dir is inside a git work tree.
   function Is_Git_Repo (Target_Dir : String) return Boolean;

   --  Create a detached git worktree of Base_Ref for the target repository.
   --  Runs `git -C Target_Dir worktree add --detach Tmp_Path Base_Ref` where
   --  Tmp_Path is a unique path under the system temporary directory.
   --  @param Target_Dir  Root of the target git repository.
   --  @param Base_Ref  Git branch or commit to check out.
   --  @param Tmp_Path  Output buffer receiving the worktree path.
   --  @param Tmp_Len  Length of the worktree path on success.
   --  @param Success  True if the worktree was created; False on git failure.
   procedure Make_Worktree
     (Target_Dir : String;
      Base_Ref   : String;
      Tmp_Path   : out String;
      Tmp_Len    : out Natural;
      Success    : out Boolean);

   --  Remove a worktree created by Make_Worktree.
   --  Runs `git -C Target_Dir worktree remove --force Tmp_Path`. Best effort;
   --  failures are ignored (e.g. cleaning up a path that was never registered).
   --  @param Target_Dir  Root of the target git repository.
   --  @param Tmp_Path  Path of the worktree to remove.
   procedure Remove_Worktree (Target_Dir : String; Tmp_Path : String);

   --  Print a side-by-side delta report of the two assessments.
   --  Also reports whether the current state regressed versus the base.
   --  Regression means docstring coverage dropped, HLR traceability was lost,
   --  orphan tags were introduced, or (when both states have comparable data)
   --  proved VCs decreased, test failures increased, or the DAL status
   --  regressed from Achieved to Unmet.
   --  @param Base  Assessment of the base ref.
   --  @param Cur  Assessment of the current working tree.
   --  @param Base_Ref  Human-readable name of the base ref shown in the report.
   --  @param Use_Color  Enable ANSI color output (default False).
   --  @return True if the current state regressed versus the base.
   function Report_Delta
     (Base      : Assessment_Result;
      Cur       : Assessment_Result;
      Base_Ref  : String;
      Use_Color : Boolean := False) return Boolean;

end Adacovex.Diff;
