--  Shared per-process directory-snapshot memo.
--
--  Every adacovex assessment walks the target tree several times: the
--  source scanner, the SBOM tools-key hash, the graph-key language probe,
--  the vendored discovery and hash walks, the GPR collection walk, and the
--  complexity checker.  Each walk re-enumerated the same directories and
--  re-stat'ed every entry (Ada.Directories' Kind on an entry costs one
--  stat), so a warm run paid the enumeration cost five times over --
--  measured at 11 stats per source file on the self-audit tree.
--
--  This package is the single shared snapshot those walkers consult.  The
--  first walker to touch a directory enumerates it once, records every
--  entry's (name, kind), and stamps the record with the directory's mtime;
--  every later walker in the same process serves the snapshot after one
--  mtime stat validates it.  This is the same shape a language server's
--  indexed file set takes: one authoritative view of the workspace that
--  every subsystem reads, invalidated from cheap stat probes rather than
--  re-enumerated from scratch.
--
--  Correctness rules:
--  * a snapshot is served only when the directory's mtime is unchanged
--    since it was taken (entries added or removed change the mtime);
--  * a directory with more than Max_Dir_Entries entries is never memoised
--    -- the caller falls back to direct enumeration, so large vendor
--    trees behave exactly as before;
--  * the memo lives for one process only (an adacovex run, a test, a
--    serve session) and is never written to disk.
--
--  The memo is bounded: at most Memo_Slots directories are remembered;
--  beyond that, lookups miss and the caller enumerates directly.

package Adacovex.Dir_Cache is

   --  Maximum entries retained per directory snapshot.  A directory with
   --  more entries is reported as truncated and never memoised.
   Max_Dir_Entries : constant := 256;

   --  Maximum number of directory snapshots retained.  The self-audit tree
   --  enumerates ~120 distinct directories across its walkers, so the
   -- table must hold more slots than that or a late walk evicts an early
   -- snapshot and pays the enumeration burst again.  Oldest-resolved
   -- slots are reused (open-addressed, so a full table just misses).
   Memo_Slots : constant := 256;

   --  Entry classification (a reduced File_Kind: the walkers only ever
   --  branch on file-vs-directory).
   type Entry_Kind is (K_File, K_Dir, K_Other);

   --  True when K classifies a subdirectory.  Walkers branch on this
   --  helper instead of the (not directly visible) equality operator.
   --  @param K  Entry classification.
   --  @return True when K is K_Dir.
   function Is_Directory (K : Entry_Kind) return Boolean
   is (K = K_Dir);

   --  Maximum length of a remembered entry name.  Longer names are stored
   --  truncated and flagged (Truncated), forcing a fallback.
   Max_Name_Len : constant := 120;

   --  One remembered directory entry.
   type Dir_Entry_Rec is record
      Name_Len : Natural := 0;
      Name     : String (1 .. Max_Name_Len) := (others => ' ');
      Kind     : Entry_Kind := K_Other;
   end record;

   --  A directory snapshot: up to Max_Dir_Entries entries plus a count.
   type Dir_Entry_List is array (1 .. Max_Dir_Entries) of Dir_Entry_Rec;

   --  Enumerate Dir, serving a valid memoised snapshot when one exists.
   --  Entries (1 .. Count) hold the directory's children; "." and ".." are
   --  excluded.  Truncated is True when the directory holds more entries
   --  than Max_Dir_Entries or an entry name exceeds Max_Name_Len -- the
   --  caller must then fall back to direct enumeration, and nothing is
   --  memoised.  OK is False when Dir cannot be enumerated at all.
   --
   --  The memo key is Dir's ABSOLUTE image: a relative Dir is resolved
   --  against the process working directory (read once, then cached) so
   --  walkers that spell the same directory differently (".", "src",
   --  "/abs/src", "./src") share one snapshot instead of memoising
   --  duplicates per spelling.  @param Dir       Directory to enumerate
   --  (absolute or relative).  @param Entries   Output array of remembered
   --  entries.  @param Count     Number of valid entries written to
   --  Entries.  @param Truncated True when the caller must re-enumerate
   --  directly.  @param OK        False when the directory could not be
   --  read.
   procedure Snapshot
     (Dir       : String;
      Entries   : out Dir_Entry_List;
      Count     : out Natural;
      Truncated : out Boolean;
      OK        : out Boolean);

   --  Effectiveness counters.  Hits counts the enumerations a memoised
   --  snapshot served; Misses counts the real enumerations (first touch,
   --  mtime change, table overflow, or an over-cap directory).
   Hits   : Natural := 0;
   Misses : Natural := 0;

   --  Drop every memoised snapshot (and reset Misses; Hits stays
   --  cumulative).  For tests and diagnostics.
   procedure Reset;

end Adacovex.Dir_Cache;
