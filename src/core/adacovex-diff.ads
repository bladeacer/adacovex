with Adacovex.Types;

--  Differential assessment for --compare-base.
--  It assesses a target project at a base revision.  The base revision is a
--  branch, commit, rev, or tag in git, mercurial, subversion, fossil, or
--  jj (see Adacovex.VCS).  It also assesses the current working tree.  It
--  then reports a side-by-side delta of docstring coverage, SPARK proof
--  level, test results, HLR traceability, and DO-178C DAL status.  The
--  report helps you catch local regressions before you push.
--  HLR-DIFF: Differential assessment

package Adacovex.Diff is

   --  Compact snapshot of one full assessment run.
   --  It aggregates the metrics needed to compare a base ref against the
   --  current working tree.  Has_Proof and Has_Tests show whether GNATprove
   --  output and test results were available for the target.  They are build
   --  artifacts that can be absent from a freshly checked out base.
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

   --  Docstring-coverage snapshot for one target directory.
   --  The lightweight --coverage-delta gate uses it.  Only source scanning,
   --  patch application, and docstring metrics are computed.  No GNATprove,
   --  test results, or DAL assessment are computed.  The snapshot works on a
   --  base ref that lacks committed build artifacts.
   type Coverage_Result is record
      Documented : Natural := 0;
      Total      : Natural := 0;
      Pct        : Natural := 0;
      Skipped    : Natural := 0;
   end record;

   --  Run the full assessment pipeline against a target directory.
   --  It scans .ads sources.  It parses GNATprove output and test results.
   --  It assesses DO-178C DAL compliance.  Missing proof or test artifacts
   --  are reported through Has_Proof and Has_Tests set to False, not as an
   --  error.
   --  @param Target_Dir  Project root directory to assess.
   --  @param DAL_Target  DAL level to assess against.
   --  @param Use_Cache  When True the .ads scan and the HLR.md/LLR.md
   --    parses are served from the on-disk result cache when unchanged.
   --    When False everything is recomputed (--no-cache).
   --  @return Aggregate metrics for the target directory.
   function Assess
     (Target_Dir : String;
      DAL_Target : Types.DAL_Level;
      Use_Cache  : Boolean := False) return Assessment_Result;

   --  Compute the docstring-coverage snapshot for a target directory.
   --  It runs source scanning, patch application, and docstring metrics only.
   --  @param Target_Dir  Project root directory.
   --  @param Use_Cache  When True the .ads scan comes from the on-disk result
   --    cache if unchanged.  When False, the scan is recomputed.
   --  @return Coverage snapshot (documented/total/percentage).
   function Assess_Coverage
     (Target_Dir : String; Use_Cache : Boolean := False)
      return Coverage_Result;

   --  Check that a directory is managed by a supported VCS (git, mercurial,
   --  subversion, fossil, or jj).  It uses marker-file detection with a
   --  command-tool probe fallback.  See Adacovex.VCS.Detect.
   --  @param Target_Dir  Directory to check.
   --  @return True if Target_Dir is inside a supported VCS repository.
   function Is_Repo (Target_Dir : String) return Boolean;

   --  Human-readable name of the VCS managing Target_Dir ("git",
   --  "mercurial", "subversion", "fossil", "jj", or "" when unknown).
   --  @param Target_Dir  Directory to check.
   --  @return Lowercase VCS name ("" when none is detected).
   function Repo_Kind_Name (Target_Dir : String) return String;

   --  UX guidance for the VCS managing Target_Dir.  It returns "" for a fully
   --  supported VCS.  For a legacy VCS with poor snapshot UX (subversion,
   --  fossil) it returns a note that recommends conversion to git or a
   --  git-compatible VCS.
   --  @param Target_Dir  Directory to check.
   --  @return Recommendation text ("" when no note is needed).
   function UX_Note (Target_Dir : String) return String;

   --  Snapshot Base_Ref of the target repository into a temporary directory
   --  (Tmp_Path, /tmp/adacovex-diff-<pid>) without touching the working tree.
   --  It dispatches per VCS:
   --    * git:     worktree add
   --    * hg:      archive
   --    * svn:     export
   --    * fossil:  open on a copied DB
   --    * jj:      a git worktree against its store
   --  @param Target_Dir  Root of the target repository.
   --  @param Base_Ref  Branch/commit/rev/tag to check out.
   --  @param Tmp_Path  Output buffer receiving the snapshot path.
   --  @param Tmp_Len  Length of the snapshot path on success.
   --  @param Success  True if the snapshot was created.  False on failure.
   procedure Make_Worktree
     (Target_Dir : String;
      Base_Ref   : String;
      Tmp_Path   : out String;
      Tmp_Len    : out Natural;
      Success    : out Boolean);

   --  Remove a snapshot created by Make_Worktree.
   --  It deregisters VCS worktrees (git/jj) and deletes the directory.  It is
   --  best effort.  Failures are ignored, for example a path that was never
   --  registered.
   --  @param Target_Dir  Root of the target repository.
   --  @param Tmp_Path  Path of the snapshot to remove.
   procedure Remove_Worktree (Target_Dir : String; Tmp_Path : String);

   --  Print a side-by-side delta report of the two assessments.
   --  It also reports whether the current state regressed versus the base.
   --  A regression is when docstring coverage dropped.  It is also when HLR
   --  traceability was lost or orphan tags were introduced.  When both states
   --  have comparable data, a regression is also when proved VCs decreased,
   --  test failures increased, or the DAL status went from Achieved to Unmet.
   --  @param Base  Assessment of the base ref.
   --  @param Cur  Assessment of the current working tree.
   --  @param Base_Ref  Human-readable name of the base ref shown in the report.
   --  @param Use_Color  Enable ANSI colour output (default False).
   --  @return True if the current state regressed versus the base.
   function Report_Delta
     (Base      : Assessment_Result;
      Cur       : Assessment_Result;
      Base_Ref  : String;
      Use_Color : Boolean := False) return Boolean;

   --  Print a compact docstring-coverage delta report for a PR-style gate.
   --  A regression is reported when the current docstring coverage percentage
   --  is lower than the base.  If the base tree has no sources, no regression
   --  is reported because there is nothing to compare against.
   --  @param Base  Coverage of the base ref.
   --  @param Cur  Coverage of the current working tree.
   --  @param Base_Ref  Human-readable name of the base ref.
   --  @param Use_Color  Enable ANSI colour output (default False).
   --  @return True if the current coverage regressed versus the base.
   function Report_Coverage_Delta
     (Base      : Coverage_Result;
      Cur       : Coverage_Result;
      Base_Ref  : String;
      Use_Color : Boolean := False) return Boolean;

end Adacovex.Diff;
