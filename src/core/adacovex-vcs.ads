--  Version-control-system abstraction for differential modes.
--  --compare-base and --coverage-delta need a snapshot of a base revision
--  without disturbing the working tree.  Legacy codebases may live in
--  Mercurial, Subversion, Fossil, or jj rather than git, so the snapshot
--  operations are dispatched per VCS here:
--
--    git    - `git worktree add --detach` in a linked worktree
--    hg     - `hg archive -r REF DIR` (pure export, no working-copy change)
--    svn    - `svn info --show-item url` + `svn export -r REF URL DIR`
--    fossil - copy the repo DB and `fossil open` it at REF in a scratch dir
--    jj     - `jj git export` into the internal git store, then a git
--              worktree add against .jj/repo/store/git (jj commits ARE git
--              commits, so any change/commit id resolves)
--
--  Detection is marker-file based (.git / .jj / .hg / .svn / .fslckout /
--  _FOSSIL_), with a command probe fallback when no marker is present.
--  Runs only on Linux/WSL (uses sh -c for CWD-dependent tools like fossil).
--  HLR-DIFF: VCS abstraction for differential assessment

package Adacovex.VCS is

   type VCS_Kind is (Unknown, Git, Mercurial, Subversion, Fossil, Jujutsu);

   --  Detect the VCS managing Target_Dir.
   --  Marker files take priority (deterministic, no subprocesses); when no
   --  marker is present the VCS command-line tools are probed.  Git wins
   --  over jj for colocated repos (git interop is exact there).
   --  @param Target_Dir  Directory to inspect.
   --  @return Detected VCS kind (Unknown when none is found).
   function Detect (Target_Dir : String) return VCS_Kind;

   --  Whether Target_Dir is managed by any supported VCS.
   --  @param Target_Dir  Directory to inspect.
   --  @return True when a supported VCS is detected.
   function Is_Managed (Target_Dir : String) return Boolean;

   --  Human-readable name of a VCS kind ("git", "mercurial", ...).
   --  @param Kind  VCS kind.
   --  @return Lowercase display name ("" for Unknown).
   function To_String (Kind : VCS_Kind) return String
   with
     SPARK_Mode => On,
     Post       =>
       To_String'Result = "git"
       or else To_String'Result = "mercurial"
       or else To_String'Result = "subversion"
       or else To_String'Result = "fossil"
       or else To_String'Result = "jj"
       or else To_String'Result = "",
     Global     => null;

   --  Command-line tool binary that drives a VCS kind ("git", "hg",
   --  "svn", "fossil", "jj"), or "" for Unknown.  `adacovex status` uses it
   --  to report which VCS tools are available on PATH for the differential
   --  modes.
   --  @param Kind  VCS kind.
   --  @return Tool binary name ("" for Unknown).
   function Tool_Name (Kind : VCS_Kind) return String
   with
     SPARK_Mode => On,
     Post       =>
       Tool_Name'Result = "git"
       or else Tool_Name'Result = "hg"
       or else Tool_Name'Result = "svn"
       or else Tool_Name'Result = "fossil"
       or else Tool_Name'Result = "jj"
       or else Tool_Name'Result = "",
     Global     => null;

   --  UX guidance for a VCS kind: "" for a fully supported VCS; for legacy
   --  VCS whose snapshot UX is poor (Subversion: no local history, network-
   --  dependent; Fossil: niche tooling), a note recommending the developers
   --  convert the repository to git (or a git-compatible VCS).
   --  @param Kind  VCS kind.
   --  @return Recommendation text ("" when no note is needed).
   function UX_Note (Kind : VCS_Kind) return String
   with
     SPARK_Mode => On,
     Post       =>
       (if Kind = Subversion or Kind = Fossil
        then UX_Note'Result'Length > 0
        else UX_Note'Result'Length = 0),
     Global     => null;

   --  Snapshot Base_Ref of the Target_Dir repository into a temporary
   --  directory (Tmp_Path), without touching the working tree.
   --  The temp path is /tmp/adacovex-diff-<pid> (Linux/WSL).  On failure
   --  Tmp_Len is 0; a stale snapshot at the same path is removed first.
   --  @param Target_Dir  Root of the target repository.
   --  @param Kind  Detected VCS kind (from Detect).
   --  @param Base_Ref  Revision to snapshot (branch/commit/rev/tag).
   --  @param Tmp_Path  Output buffer receiving the snapshot path.
   --  @param Tmp_Len  Length of the snapshot path on success.
   --  @param Success  True when the snapshot was created.
   procedure Make_Snapshot
     (Target_Dir : String;
      Kind       : VCS_Kind;
      Base_Ref   : String;
      Tmp_Path   : out String;
      Tmp_Len    : out Natural;
      Success    : out Boolean);

   --  Remove a snapshot created by Make_Snapshot.
   --  Deregisters VCS worktrees (git/jj) and deletes the directory.  Best
   --  effort; failures are ignored.
   --  @param Target_Dir  Root of the target repository.
   --  @param Kind  VCS kind the snapshot was created with.
   --  @param Tmp_Path  Snapshot directory to remove.
   procedure Remove_Snapshot
     (Target_Dir : String; Kind : VCS_Kind; Tmp_Path : String);

end Adacovex.VCS;
