--  Shared per-process directory-snapshot memo.
--
--  Every adacovex assessment walks the target tree several times: the
--  source scanner, the SBOM tools-key hash, the graph-key language probe,
--  the vendored discovery and hash walks, the GPR collection walk, and the
--  complexity checker. Each walk re-enumerated the same directories and
--  re-stat'ed every entry (Ada.Directories' Kind on an entry costs one
--  stat), so a warm run paid the enumeration cost five times over --
--  measured at 11 stats per source file on the self-audit tree.
--
--  This package is the single shared snapshot those walkers consult. The
--  first walker to touch a directory enumerates it once, records every
--  entry's (name, kind), and stamps the record with the directory's mtime;
--  every later walker in the same process serves the snapshot after one
--  mtime stat validates it. This is the same shape a language server's
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
--
--  Cache-friendliness: a slot's metadata (path, mtime, count) sits in its
--  first cache lines and the entry array follows, so a hit touches the
--  metadata first. An entry is packed to 66 bytes (a 64-byte name, a
--  one-byte length, and a one-byte kind) rather than the 128 bytes the
--  v1.61.0 profile recorded, and the memo key is capped at 128 bytes
--  instead of 256. Max_Dir_Entries is 128 because the self-audit tree's
--  two densest scanned directories hold 84 and 78 entries: a cap of 64
--  rejected both and made every walker re-enumerate them.

package Adacovex.Dir_Cache is

   --  Maximum entries retained per directory snapshot. A directory with
   --  more entries is reported as truncated and never memoised. 128
   --  clears every scanned directory in the self-audit tree (src/parsers
   --  holds 78 entries and docs/api-docs 84) while keeping one slot
   --  small enough to copy from the memo.
   Max_Dir_Entries : constant := 128;

   --  Maximum number of directory snapshots retained. The self-audit tree
   --  enumerates ~120 distinct directories across its walkers, so the
   --  table must hold more slots than that or a late walk evicts an early
   --  snapshot and pays the enumeration burst again. Oldest-resolved
   --  slots are reused (open-addressed, so a full table just misses).
   Memo_Slots : constant := 256;

   --  Entry classification (a reduced File_Kind: the walkers only ever
   --  branch on file-vs-directory). The size clause keeps the packed
   --  record's kind field a whole byte, so no multi-byte field of a slot
   --  ever straddles a byte boundary.
   type Entry_Kind is (K_File, K_Dir, K_Other);
   for Entry_Kind'Size use 8;

   --  True when K classifies a subdirectory. Walkers branch on this
   --  helper instead of the (not directly visible) equality operator.
   --  @param K  Entry classification.
   --  @return True when K is K_Dir.
   function Is_Directory (K : Entry_Kind) return Boolean
   is (K = K_Dir);

   --  Maximum length of a remembered entry name. A longer name reports
   --  the directory as truncated, so the caller falls back instead of
   --  losing the entry. 64 covers every name in the self-audit tree
   --  (the longest scanned name is 58 characters).
   Max_Name_Len : constant := 64;

   --  Entry name length. The subtype's range is the memo's name bound;
   --  the packed record stores it in one byte.
   subtype Name_Length is Natural range 0 .. Max_Name_Len;

   --  One remembered directory entry. The name comes first: the length
   --  and kind fields then share its tail. Packed to 66 bytes, where the
   --  v1.61.0 record took 128 and the 1.62.0 one took 72, so 128 entries
   --  fit in 8 KiB.
   type Dir_Entry_Rec is record
      Name     : String (1 .. Max_Name_Len) := (others => ' ');
      Name_Len : Name_Length := 0;
      Kind     : Entry_Kind := K_Other;
   end record;
   pragma Pack (Dir_Entry_Rec);

   --  A directory snapshot: up to Max_Dir_Entries entries plus a count.
   type Dir_Entry_List is array (1 .. Max_Dir_Entries) of Dir_Entry_Rec;

   --  Enumerate Dir, serving a valid memoised snapshot when one exists.
   --  Entries (1 .. Count) hold the directory's children; "." and ".." are
   --  excluded. Truncated is True when the directory holds more entries
   --  than Max_Dir_Entries or an entry name exceeds Max_Name_Len -- the
   --  caller must then fall back to direct enumeration, and nothing is
   --  memoised. OK is False when Dir cannot be enumerated at all.
   --
   --  The memo key is Dir's ABSOLUTE image: a relative Dir is resolved
   --  against the process working directory (read once, then cached) so
   --  walkers that spell the same directory differently (".", "src",
   --  "/abs/src", "./src") share one snapshot instead of memoising
   --  duplicates. A key longer than 128 bytes is not memoised; the
   --  snapshot is still returned.
   --  @param Dir        Directory to enumerate (absolute or relative).
   --  @param Entries    Output array of remembered entries.
   --  @param Count      Number of valid entries written to Entries.
   --  @param Truncated  True when the caller must re-enumerate directly.
   --  @param OK         False when the directory could not be read.
   procedure Snapshot
     (Dir       : String;
      Entries   : out Dir_Entry_List;
      Count     : out Natural;
      Truncated : out Boolean;
      OK        : out Boolean);

   --  Effectiveness counters. Hits counts the enumerations a memoised
   --  snapshot served; Misses counts the real enumerations (first touch,
   --  mtime change, table overflow, or an over-cap directory).
   Hits   : Natural := 0;
   Misses : Natural := 0;

   --  Drop every memoised snapshot (and reset Misses; Hits stays
   --  cumulative). For tests and diagnostics.
   procedure Reset;

end Adacovex.Dir_Cache;
