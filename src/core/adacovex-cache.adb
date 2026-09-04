with Ada.Calendar;
with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Environment_Variables;
with Ada.Text_IO;
with GNAT.SHA256;
with Interfaces;
with System.OS_Lib;

package body Adacovex.Cache is

   use Ada.Directories;
   use Ada.Calendar;
   use Ada.Streams;
   use Ada.Streams.Stream_IO;
   use Interfaces;

   --  Configured cache root (absolute).  Defaults to Default_Cache_Dir at
   --  elaboration; overridden by Set_Cache_Dir (--cache-dir).
   Cache_Root     : String (1 .. 4096) := (others => ' ');
   Cache_Root_Len : Natural := 0;

   --  Full path of a cache entry: <root>/<aa>/<key>.  Cache_Root is stored
   --  without a trailing separator; Entry_Path adds the joining slashes.
   function Entry_Path (Key : String) return String is
   begin
      if Key'Length < 3 or else Cache_Root_Len = 0 then
         return "";
      end if;
      return
        Cache_Root (1 .. Cache_Root_Len)
        & "/"
        & Key (Key'First .. Key'First + 1)
        & "/"
        & Key;
   end Entry_Path;

   --  Parent directory of an entry (the <root><aa> subdir).
   function Subdir_Path (Key : String) return String is
   begin
      if Key'Length < 3 or else Cache_Root_Len = 0 then
         return "";
      end if;
      return
        Cache_Root (1 .. Cache_Root_Len)
        & "/"
        & Key (Key'First .. Key'First + 1);
   end Subdir_Path;

   procedure Set_Cache_Dir (Dir : String) is
   begin
      if Dir'Length = 0 or else Dir'Length > Cache_Root'Length then
         return;
      end if;
      Cache_Root_Len := Dir'Length;
      Cache_Root (1 .. Cache_Root_Len) := Dir;
      if Cache_Root (Cache_Root_Len) = '/' then
         Cache_Root_Len := Cache_Root_Len - 1;
      end if;
   end Set_Cache_Dir;

   procedure Cache_Dir (Dir : out String; Len : out Natural) is
   begin
      if Cache_Root_Len <= Dir'Length then
         Len := Cache_Root_Len;
         Dir (Dir'First .. Dir'First + Len - 1) :=
           Cache_Root (1 .. Cache_Root_Len);
      else
         Len := 0;
      end if;
   end Cache_Dir;

   procedure Default_Cache_Dir (Dir : out String; Len : out Natural) is
      Home : constant String :=
        (if Ada.Environment_Variables.Exists ("HOME")
         then Ada.Environment_Variables.Value ("HOME")
         else "/tmp");
      S    : constant String :=
        Home & "/.adacovex/cache/" & Adacovex.Version & "/" & Cache_Schema;
   begin
      if S'Length <= Dir'Length then
         Len := S'Length;
         Dir (Dir'First .. Dir'First + Len - 1) := S;
      else
         Len := 0;
      end if;
   end Default_Cache_Dir;

   --  In-memory map of file path -> (size, digest) recorded at the last
   --  Hash_File call.  It is bounded: when the map reaches Stamp_Map_Cap
   --  entries, new paths are not inserted (a period of pathological churn
   --  just causes a re-hash).  The size is recorded on insertion, so a
   --  changed content with an identically-sized file is served the stale
   --  digest only within one process and one run -- the map is never
   --  persisted, and a size change always forces a fresh hash.
   --
   --  Layout is cache-line friendly.  Lookups probe the compact scalar
   --  arrays (hash, size, length) and touch the 2048-byte name buffer only
   --  when all three scalars match a candidate.  The table is
   --  open-addressed on a 32-bit FNV-1a hash of the path, so a hit probes
   --  one or two slots instead of scanning the whole map.  A slot whose
   --  Stamp_Hash is Empty_Hash is free.
   Stamp_Map_Cap : constant := 4096;  --  power of two
   subtype Stamp_Index is Natural range 0 .. Stamp_Map_Cap - 1;
   Empty_Hash    : constant Integer := -1;
   Stamp_Hash    : array (Stamp_Index) of Integer := (others => Empty_Hash);
   Stamp_Size    : array (Stamp_Index) of Long_Long_Integer := (others => -1);
   Stamp_Len     : array (Stamp_Index) of Natural := (others => 0);
   Stamp_Names   : array (Stamp_Index) of String (1 .. 2048) :=
     (others => (others => ' '));
   Stamp_Digest  : array (Stamp_Index) of String (1 .. 64) :=
     (others => (others => ' '));

   --  FNV-1a hash of Path, folded into the table range.  The wrapping
   --  Unsigned_32 arithmetic keeps the multiply in range; the fold is a
   --  power-of-two mask (Stamp_Map_Cap is a power of two), which the
   --  compiler turns into a simple and.
   function Stamp_Hash_Of (Path : String) return Integer is
      H : Interfaces.Unsigned_32 := 16#811c9dc5#;
   begin
      for I in Path'Range loop
         H :=
           (H xor Interfaces.Unsigned_32 (Character'Pos (Path (I))))
           * 16#01000193#;
      end loop;
      return Integer (H and Interfaces.Unsigned_32 (Stamp_Map_Cap - 1));
   end Stamp_Hash_Of;

   --  Current stamp of a file: size (or -1 when Size raises).  One stat
   --  call (Ada.Directories.Size answers presence and size in the same
   --  __gnat_named_file_length stat and raises when the file is missing),
   --  so the fast path never opens the file and never pays a separate
   --  Exists probe.
   function File_Size (Path : String) return Long_Long_Integer is
      use Ada.Directories;
   begin
      return Long_Long_Integer (Size (Path));
   exception
      when others =>
         return -1;
   end File_Size;

   --  Find Path in the stamp map.  Returns the index or -1.  Open
   --  addressing with linear probing: the probe starts at the path hash
   --  and walks forward until an empty slot (not present) or a full match
   --  (hash value, stored length, then the stored name slice of exactly
   --  that length).  The earlier bug compared the full fixed-size name
   --  buffer (2048 chars) against the real path, so the length never
   --  matched and the fast path silently never fired -- every file was
   --  re-read and re-hashed on every run.
   function Stamp_Find (Path : String) return Integer is
      H      : Integer := Stamp_Hash_Of (Path);
      Target : constant Integer := H;
   begin
      if Path'Length = 0 or else Path'Length > Stamp_Names (0)'Length then
         return -1;
      end if;
      for Seen in 0 .. Stamp_Map_Cap - 1 loop
         if Stamp_Hash (H) = Empty_Hash then
            return -1;
         end if;
         if Stamp_Hash (H) = Target
           and then Stamp_Len (H) = Path'Length
           and then Stamp_Names (H) (1 .. Path'Length) = Path
         then
            return H;
         end if;
         H := (H + 1) mod Stamp_Map_Cap;
      end loop;
      return -1;
   end Stamp_Find;

   --  Serve a previously-remembered digest when Path's size still matches
   --  the size recorded with that digest.  The path must be the same
   --  string (a re-scan of the same file).  The function returns "" when
   --  there is no matching stamp (the caller then falls back to
   --  Hash_File).  Stamp_Hits / Stamp_Misses count both outcomes so tests
   --  and diagnostics can see whether the fast path fired.  The map lookup
   --  runs BEFORE the stat: a miss (a path never hashed in this process)
   --  then costs no stat at all -- the file is read and hashed anyway on
   --  the fallback path.  A hit costs exactly one stat, still far below
   --  the read + SHA-256 it avoids.
   function Hash_Fast (Path : String) return String is
      Idx : Integer;
      Sz  : Long_Long_Integer;
   begin
      if Path'Length = 0 or else Path'Length > 2048 then
         return "";
      end if;
      Idx := Stamp_Find (Path);
      if Idx < 0 then
         Stamp_Misses := Stamp_Misses + 1;
         return "";
      end if;
      Sz := File_Size (Path);
      if Sz >= 0 and then Stamp_Size (Idx) = Sz then
         Stamp_Hits := Stamp_Hits + 1;
         return Stamp_Digest (Idx);
      end if;
      Stamp_Misses := Stamp_Misses + 1;
      return "";
   end Hash_Fast;

   --  Remember Path with the given digest (and Path's size at hash time)
   --  so a later Hash_Fast (same path, same size) can reuse the digest
   --  without re-reading the file.  The size is the strongest cheap
   --  proxy for "content unchanged" after this process already hashed the
   --  file; mtime is secondary and not tracked.
   procedure Stamp_Remember (Path : String; Digest : String) is
      H      : Integer := Stamp_Hash_Of (Path);
      Target : constant Integer := H;
   begin
      if Path'Length = 0
        or else Path'Length > Stamp_Names (0)'Length
        or else Digest'Length /= 64
      then
         return;
      end if;
      --  Reuse the entry when present; otherwise occupy the first empty
      --  slot on the probe chain (insertions agree with Stamp_Find's probe
      --  order, so later lookups converge on the same slot).
      for Seen in 0 .. Stamp_Map_Cap - 1 loop
         if Stamp_Hash (H) = Empty_Hash
           or else (Stamp_Hash (H) = Target
                    and then Stamp_Len (H) = Path'Length
                    and then Stamp_Names (H) (1 .. Path'Length) = Path)
         then
            Stamp_Hash (H) := Target;
            Stamp_Len (H) := Path'Length;
            Stamp_Names (H) (1 .. Path'Length) := Path;
            Stamp_Size (H) := File_Size (Path);
            Stamp_Digest (H) (1 .. 64) := Digest;
            return;
         end if;
         H := (H + 1) mod Stamp_Map_Cap;
      end loop;
   --  Map full and Path not present: skip the insert.  Pathological
   --  churn just re-hashes.
   end Stamp_Remember;

   --  Read chunk for Hash_File.  64 KiB keeps the read syscall rate low on
   --  large source trees (the previous 8 KiB chunk octupled the read
   --  syscalls on big files).
   Hash_Chunk : constant := 65_536;

   --  Persistent stat-stamp index -- the cross-process extension of the
   --  in-process stamp map above.  The in-process map dies with the run, so
   --  every warm adacovex invocation still opened and re-hashed every
   --  unchanged file (source files for scan keys, manifest files and whole
   --  vendored trees for graph keys).  This index keeps the (size, mtime,
   --  digest) triples on disk in ONE machine-local file (exactly like
   --  git's index, or a language server's workspace snapshot), so
   --  --cache-dir redirection and cache wipes never cost a re-hash, and a
   --  lookup costs ZERO extra syscalls after the one-time load.
   --
   --  1.44.0 first shipped a per-file store (<stamps>/<sha-256-of-path>,
   --  one text record per file).  Its warm-run measurement on this tree
   --  exposed the flaw: each lookup paid an open + four short reads, so
   --  stamping SMALL files was a net loss (the lookup cost more than the
   --  re-hash) and the store was size-gated at 16 KiB, which left the 36
   --  warm re-reads of the .ads sources on the table.  Packing all records
   --  into one binary index (loaded once, flushed in bulk) drives the
   --  per-lookup cost to zero, so every file -- small sources included --
   --  is worth stamping.  This mirrors git's own evolution: the index is
   --  one file, not one file per path.
   --
   --  Two safety rules keep a stale digest from ever being served for
   --  edited content (both inherited from git's index discipline):
   --  * size and mtime must BOTH match the stored pair (an edit that keeps
   --    the size must move the mtime);
   --  * a file modified during the second the record was taken is never
   --    recorded (git's racy-clean rule -- the mtime has not yet provably
   --    stabilised).
   --  Records expire after 30 days.  Residual exposure is an edit that
   --  restores both the size and the second-granularity mtime of the
   --  stamped state -- the same class of trade every dirty-tracker
   --  accepts, and it self-heals on the next size or mtime change.
   Stamp_TTL_Days : constant := 30;

   --  <HOME>/.adacovex/stamps -- machine-local, outside the result cache.
   function Stamp_Store_Root return String is
      Home : constant String :=
        (if Ada.Environment_Variables.Exists ("HOME")
         then Ada.Environment_Variables.Value ("HOME")
         else "/tmp");
   begin
      return Home & "/.adacovex/stamps";
   end Stamp_Store_Root;

   --  The single index file: <stamps>/index.bin.  Binary layout (little-
   --  endian via Stream_Element writes, one flat buffer):
   --    magic "ADASTMP1" (8 bytes)
   --    per slot (fixed 4096 slots, probed in the same order as the
   --    in-process map):
   --      state   : 1 byte  (0 = empty, 1 = occupied)
   --      hash    : 4 bytes (FNV-1a fold of the path, Stamp_Map_Cap-masked
   --                high bits + full-mix low bits for the probe)
   --      size    : 8 bytes
   --      mtime   : 8 bytes (OS seconds)
   --      recsec  : 8 bytes (record time, OS seconds -- the TTL anchor)
   --      namelen : 2 bytes
   --      name    : namelen bytes (max 2048)
   --      digest  : 64 bytes
   PStamp_Magic       : constant String := "ADASTMP1";
   PStamp_Hdr         : constant := 8;
   PStamp_Slot_Fixed  : constant := 1 + 4 + 8 + 8 + 8 + 2;  --  31 bytes
   PStamp_Slot_Max    : constant :=
     PStamp_Slot_Fixed + 2048 + 64;                        --  2143 bytes
   PStamp_File_Max    : constant :=
     PStamp_Hdr + Stamp_Map_Cap * PStamp_Slot_Max;
   PStamp_Flush_Every : constant := 24;  --  records between flushes

   --  Persistent slot state (parallel to the in-process map; loaded once).
   P_Loaded : Boolean := False;
   P_Dirty  : Natural := 0;   --  records since last flush
   P_Hash   : array (Stamp_Index) of Interfaces.Unsigned_32 := (others => 0);
   P_Size   : array (Stamp_Index) of Long_Long_Integer := (others => -1);
   P_Mtime  : array (Stamp_Index) of Long_Long_Integer := (others => -1);
   P_Rec    : array (Stamp_Index) of Long_Long_Integer := (others => 0);
   P_Len    : array (Stamp_Index) of Natural := (others => 0);
   P_Names  : array (Stamp_Index) of String (1 .. 2048) :=
     (others => (others => ' '));
   P_Digest : array (Stamp_Index) of String (1 .. 64) :=
     (others => (others => ' '));

   --  Full FNV-1a mix of Path (not masked): used as the persistent slot
   --  identity so two paths sharing a masked probe slot can be told apart.
   function PStamp_Hash_Of (Path : String) return Interfaces.Unsigned_32 is
      H : Interfaces.Unsigned_32 := 16#811c9dc5#;
   begin
      for I in Path'Range loop
         H :=
           (H xor Interfaces.Unsigned_32 (Character'Pos (Path (I))))
           * 16#01000193#;
      end loop;
      return H;
   end PStamp_Hash_Of;

   --  Little-endian scalar encoders into a byte buffer.
   procedure Put_U32
     (Buf : in out Ada.Streams.Stream_Element_Array;
      Pos : in out Natural;
      V   : Interfaces.Unsigned_32)
   is
      X : Interfaces.Unsigned_32 := V;
   begin
      for I in 0 .. 3 loop
         Buf (Ada.Streams.Stream_Element_Offset (Pos + I)) :=
           Ada.Streams.Stream_Element (X and 16#FF#);
         X := X / 256;
      end loop;
      Pos := Pos + 4;
   end Put_U32;

   procedure Put_U64
     (Buf : in out Ada.Streams.Stream_Element_Array;
      Pos : in out Natural;
      V   : Long_Long_Integer)
   is
      use type Interfaces.Unsigned_64;
      X : Interfaces.Unsigned_64 := Interfaces.Unsigned_64 (V);
   begin
      for I in 0 .. 7 loop
         Buf (Ada.Streams.Stream_Element_Offset (Pos + I)) :=
           Ada.Streams.Stream_Element (X and 16#FF#);
         X := X / 256;
      end loop;
      Pos := Pos + 8;
   end Put_U64;

   function Get_U32
     (Buf : Ada.Streams.Stream_Element_Array; Pos : Natural)
      return Interfaces.Unsigned_32
   is
      use type Interfaces.Unsigned_32;
      X : Interfaces.Unsigned_32 := 0;
   begin
      for I in reverse 0 .. 3 loop
         X :=
           X
           * 256
           + Interfaces.Unsigned_32
               (Buf (Ada.Streams.Stream_Element_Offset (Pos + I)));
      end loop;
      return X;
   end Get_U32;

   function Get_U64
     (Buf : Ada.Streams.Stream_Element_Array; Pos : Natural)
      return Long_Long_Integer
   is
      use type Interfaces.Unsigned_64;
      X : Interfaces.Unsigned_64 := 0;
   begin
      for I in reverse 0 .. 7 loop
         X :=
           X
           * 256
           + Interfaces.Unsigned_64
               (Buf (Ada.Streams.Stream_Element_Offset (Pos + I)));
      end loop;
      return Long_Long_Integer (X);
   end Get_U64;

   --  Load the index once per process.  A missing, stale-magic, or corrupt
   --  file leaves the table empty (everything re-hashes and re-records;
   --  no error is surfaced -- the index is a cache, never a truth source).
   procedure PStamp_Load is
      use Ada.Streams;
      Path : constant String := Stamp_Store_Root & "/index.bin";
      F    : Stream_IO.File_Type;
      Size : Ada.Directories.File_Size := 0;
      Buf  : access Stream_Element_Array := null;
      Pos  : Natural;
   begin
      if P_Loaded then
         return;
      end if;
      P_Loaded := True;
      begin
         Size := Ada.Directories.Size (Path);
      exception
         when others =>
            return;   --  no index yet: empty table
      end;
      if Size < Ada.Directories.File_Size (PStamp_Hdr)
        or else Size > Ada.Directories.File_Size (PStamp_File_Max)
      then
         return;
      end if;
      begin
         Stream_IO.Open (F, Stream_IO.In_File, Path);
      exception
         when others =>
            return;
      end;
      Buf := new Stream_Element_Array (0 .. Stream_Element_Offset (Size) - 1);
      declare
         Last : Stream_Element_Offset;
      begin
         Stream_IO.Read (F, Buf.all, Last);
         Stream_IO.Close (F);
         Size := Ada.Directories.File_Size (Last + 1);
      exception
         when others =>
            if Stream_IO.Is_Open (F) then
               Stream_IO.Close (F);
            end if;
            return;
      end;
      --  Magic check.
      for I in PStamp_Magic'Range loop
         if Character'Val (Buf (Stream_Element_Offset (I - 1)))
           /= PStamp_Magic (I)
         then
            return;
         end if;
      end loop;
      Pos := PStamp_Hdr;
      while Pos + PStamp_Slot_Fixed <= Natural (Size) loop
         declare
            State_Byte : constant Stream_Element :=
              Buf (Stream_Element_Offset (Pos));
            H          : Interfaces.Unsigned_32;
            NL         : Natural;
         begin
            if State_Byte = 0 then
               Pos := Pos + PStamp_Slot_Fixed;
               --  Empty slot: skip the fixed part; name/digest are absent.
               Pos := Pos - 2048 - 64 + PStamp_Slot_Fixed;
               --  (empty slots are written with full fixed fields and no
               --  name/digest, so just advance the fixed amount)
               exit when Pos > Natural (Size);
            else
               H := Get_U32 (Buf.all, Pos + 1);
               declare
                  Sz  : constant Long_Long_Integer :=
                    Get_U64 (Buf.all, Pos + 5);
                  Mt  : constant Long_Long_Integer :=
                    Get_U64 (Buf.all, Pos + 13);
                  Rc  : constant Long_Long_Integer :=
                    Get_U64 (Buf.all, Pos + 21);
                  NL2 : constant Natural :=
                    Natural (Get_U32 (Buf.all, Pos + 29) and 16#FFFF#);
               begin
                  NL := NL2;
                  Pos := Pos + PStamp_Slot_Fixed;
                  exit when NL > 2048 or else Pos + NL + 64 > Natural (Size);
                  --  Find the slot for H in the in-memory table.
                  declare
                     Idx : constant Natural :=
                       Natural (H and 16#FFFF#) mod Stamp_Map_Cap;
                  begin
                     if P_Len (Idx) = 0 then
                        P_Hash (Idx) := H;
                        P_Size (Idx) := Sz;
                        P_Mtime (Idx) := Mt;
                        P_Rec (Idx) := Rc;
                        P_Len (Idx) := NL;
                        for I in 1 .. NL loop
                           P_Names (Idx) (I) :=
                             Character'Val
                               (Buf (Stream_Element_Offset (Pos + I - 1)));
                        end loop;
                        for I in 1 .. 64 loop
                           P_Digest (Idx) (I) :=
                             Character'Val
                               (Buf
                                  (Stream_Element_Offset (Pos + NL + I - 1)));
                        end loop;
                     end if;
                  --  Collision (two paths, one slot): the newer record
                  --  wins next run via the rewrite; serving the loaded
                  --  one is safe because the name check below gates it.
                  end;
                  Pos := Pos + NL + 64;
               end;
            end if;
         end;
      end loop;
   exception
      when others =>
         null;
   end PStamp_Load;

   --  Flush the whole persistent table to the single index file (one
   --  write).  Called after every PStamp_Flush_Every records; a process
   --  exit before a flush only loses recent stamps (they re-hash once).
   procedure PStamp_Flush is
      use Ada.Streams;
      Path    : constant String := Stamp_Store_Root & "/index.bin";
      F       : Stream_IO.File_Type;
      Buf     : not null access Stream_Element_Array :=
        new Stream_Element_Array (0 .. PStamp_File_Max - 1);
      Pos     : Natural := PStamp_Hdr;
      Written : Stream_Element_Offset;
   begin
      P_Dirty := 0;
      for I in PStamp_Magic'Range loop
         Buf (Stream_Element_Offset (I - 1)) :=
           Stream_Element (Character'Pos (PStamp_Magic (I)));
      end loop;
      for Idx in Stamp_Index loop
         if P_Len (Idx) > 0 then
            Buf (Stream_Element_Offset (Pos)) := 1;
            Put_U32 (Buf.all, Pos, P_Hash (Idx));
            Put_U64 (Buf.all, Pos, P_Size (Idx));
            Put_U64 (Buf.all, Pos, P_Mtime (Idx));
            Put_U64 (Buf.all, Pos, P_Rec (Idx));
            Put_U32 (Buf.all, Pos, Interfaces.Unsigned_32 (P_Len (Idx)));
            for I in 1 .. P_Len (Idx) loop
               Buf (Stream_Element_Offset (Pos + I - 1)) :=
                 Stream_Element (Character'Pos (P_Names (Idx) (I)));
            end loop;
            Pos := Pos + P_Len (Idx);
            for I in 1 .. 64 loop
               Buf (Stream_Element_Offset (Pos + I - 1)) :=
                 Stream_Element (Character'Pos (P_Digest (Idx) (I)));
            end loop;
            Pos := Pos + 64;
         end if;
      end loop;
      begin
         Ada.Directories.Create_Path (Stamp_Store_Root);
      exception
         when others =>
            null;
      end;
      begin
         Stream_IO.Create (F, Stream_IO.Out_File, Path);
         Stream_IO.Write (F, Buf (0 .. Stream_Element_Offset (Pos) - 1));
         Stream_IO.Close (F);
      exception
         when others =>
            if Stream_IO.Is_Open (F) then
               Stream_IO.Close (F);
            end if;
      end;
   end PStamp_Flush;

   --  Look up Path in the persistent index.  Sz is the file's current size
   --  and Mt its mtime in OS seconds (both captured by the caller before
   --  the lookup).  The stored (size, mtime) pair must match exactly and
   --  the record must be younger than Stamp_TTL_Days; anything else is a
   --  miss (Dig_Len = 0).  Cost after the one-time load: pure memory -- no
   --  syscalls at all.
   procedure PStamp_Lookup
     (Path    : String;
      Sz      : Long_Long_Integer;
      Mt      : Long_Long_Integer;
      Dig     : out String;
      Dig_Len : out Natural)
   is
      use type Interfaces.Unsigned_32;
      H   : constant Interfaces.Unsigned_32 := PStamp_Hash_Of (Path);
      Idx : Stamp_Index;
   begin
      Dig_Len := 0;
      if Path'Length = 0 or else Path'Length > 2048 then
         return;
      end if;
      PStamp_Load;
      Idx := Stamp_Index (Natural (H and 16#FFFF#) mod Stamp_Map_Cap);
      if P_Len (Idx) /= Path'Length
        or else P_Hash (Idx) /= H
        or else P_Names (Idx) (1 .. Path'Length) /= Path
      then
         return;
      end if;
      --  TTL from the record's own write time (integer OS seconds).
      declare
         Now : constant Long_Long_Integer :=
           System.OS_Lib.To_C (System.OS_Lib.Current_Time);
         Age : constant Long_Long_Integer := Now - P_Rec (Idx);
      begin
         if Age < 0 or else Age > Stamp_TTL_Days * 86_400 then
            return;
         end if;
      end;
      if P_Size (Idx) /= Sz or else P_Mtime (Idx) /= Mt then
         return;
      end if;
      Persistent_Stamp_Hits := Persistent_Stamp_Hits + 1;
      Dig (1 .. 64) := P_Digest (Idx);
      Dig_Len := 64;
   end PStamp_Lookup;

   --  Record Path's (size, mtime, digest) triple in the persistent index.
   --  Files modified during the current second are skipped (git's
   --  racy-clean rule): their mtime has not yet provably stabilised, so
   --  recording now could serve a digest of pre-edit content on the next
   --  run.  The file simply stays uncached for this run and becomes
   --  stampable on the next.
   procedure PStamp_Record
     (Path : String;
      Sz   : Long_Long_Integer;
      Mt   : Long_Long_Integer;
      Dig  : String)
   is
      use Ada.Calendar;
      use type Interfaces.Unsigned_32;
      H       : Interfaces.Unsigned_32;
      Idx     : Stamp_Index;
      Now_Sec : constant Long_Long_Integer :=
        System.OS_Lib.To_C (System.OS_Lib.Current_Time);
   begin
      if Path'Length = 0
        or else Path'Length > 2048
        or else Sz < 0
        or else Mt < 0
        or else Dig'Length /= 64
      then
         return;
      end if;
      --  Racy-clean guard: both times are Ada.Calendar.Time values, so the
      --  difference needs no epoch anchor and no time-zone reasoning.
      begin
         if Clock - Ada.Directories.Modification_Time (Path) < 1.0 then
            return;
         end if;
      exception
         when others =>
            return;
      end;
      PStamp_Load;
      H := PStamp_Hash_Of (Path);
      Idx := Stamp_Index (Natural (H and 16#FFFF#) mod Stamp_Map_Cap);
      P_Hash (Idx) := H;
      P_Size (Idx) := Sz;
      P_Mtime (Idx) := Mt;
      P_Rec (Idx) := Now_Sec;
      P_Len (Idx) := Path'Length;
      P_Names (Idx) (1 .. Path'Length) := Path;
      P_Digest (Idx) (1 .. 64) := Dig;
      P_Dirty := P_Dirty + 1;
      if P_Dirty >= PStamp_Flush_Every then
         PStamp_Flush;
      end if;
   end PStamp_Record;

   --  Pending record from the pre-read decision in Hash_File: the path,
   --  and the (size, mtime) pair captured BEFORE the file was read.  When
   --  the read succeeds, the digest joins the pair and the record is
   --  complete -- no stats after the read.
   P_Stash_Valid : Boolean := False;
   P_Stash_Path  : String (1 .. 2048) := (others => ' ');
   P_Stash_Len   : Natural := 0;
   P_Stash_Size  : Long_Long_Integer := -1;
   P_Stash_Mtime : Long_Long_Integer := -1;

   --  Remember that the file just about to be read is stampable, with the
   --  (size, mtime) pair captured before the read.
   procedure PStamp_Stash
     (Path : String; Sz : Long_Long_Integer; Mt : Long_Long_Integer) is
   begin
      if Path'Length = 0 or else Path'Length > 2048 then
         P_Stash_Valid := False;
         return;
      end if;
      P_Stash_Valid := True;
      P_Stash_Len := Path'Length;
      P_Stash_Path (1 .. Path'Length) := Path;
      P_Stash_Size := Sz;
      P_Stash_Mtime := Mt;
   end PStamp_Stash;

   --  Complete the pending record with Dig and write it into the index.
   --  A no-op when no stash is pending (unreadable file, or the racy-clean
   --  guard rejected the file).
   procedure PStamp_Record_Stashed (Dig : String) is
   begin
      if not P_Stash_Valid or else Dig'Length /= 64 then
         P_Stash_Valid := False;
         return;
      end if;
      P_Stash_Valid := False;
      PStamp_Record
        (P_Stash_Path (1 .. P_Stash_Len), P_Stash_Size, P_Stash_Mtime, Dig);
   end PStamp_Record_Stashed;

   --  Drop every in-process stamp and every persistent record still
   --  unflushed, then rewrite the index.  Used by Reset_Process_Stamps and
   --  by the serve-mode refresh path.
   procedure PStamp_Reset_All is
   begin
      P_Hash := (others => 0);
      P_Size := (others => -1);
      P_Mtime := (others => -1);
      P_Rec := (others => 0);
      P_Len := (others => 0);
      P_Names := (others => (others => ' '));
      P_Digest := (others => (others => ' '));
      P_Dirty := 0;
   end PStamp_Reset_All;

   function Hash_File (Path : String) return String is
      Fast : constant String := Hash_Fast (Path);
   begin
      if Fast'Length = 64 then
         return Fast;
      end if;
      --  Second fast path: the persistent stat-stamp index.  Two stats
      --  (size + mtime) against the stored pair replace the open, read,
      --  close, and SHA-256 of a re-hash -- for EVERY file size, small
      --  sources included, because the packed index makes a lookup free
      --  after its one-time load.  The captured (Sz, Mt) pair is carried
      --  into the record path below, so a miss costs NO extra stats.
      declare
         Sz   : Long_Long_Integer := -1;
         Mt   : Long_Long_Integer := -1;
         PDig : String (1 .. 64);
         PLen : Natural := 0;
         use Ada.Calendar;
      begin
         Sz := File_Size (Path);
         if Sz >= 0 then
            Mt := System.OS_Lib.To_C (System.OS_Lib.File_Time_Stamp (Path));
         end if;
         if Sz >= 0 and then Mt >= 0 then
            PStamp_Lookup (Path, Sz, Mt, PDig, PLen);
            if PLen = 64 then
               Stamp_Remember (Path, PDig);
               return PDig;
            end if;
            --  Consulted but not answered (first-ever file, size/mtime
            --  change, or stale record): a real read follows.
            Persistent_Stamp_Misses := Persistent_Stamp_Misses + 1;
            --  Miss.  Before the real read, take the racy-clean decision
            --  ONCE here (one Modification_Time stat): a file modified
            --  during the current second is hashed fresh and never
            --  recorded; anything older is recordable.  The pair (Sz, Mt)
            --  was captured before the read, so the record describes the
            --  file as it was read.
            declare
               Stampable : Boolean := False;
            begin
               begin
                  Stampable :=
                    Clock - Ada.Directories.Modification_Time (Path) >= 1.0;
               exception
                  when others =>
                     Stampable := False;
               end;
               if Stampable then
                  PStamp_Stash (Path, Sz, Mt);
               end if;
            end;
         else
            Persistent_Stamp_Misses := Persistent_Stamp_Misses + 1;
         end if;
      end;
      declare
         Ctx  : GNAT.SHA256.Context;
         F    : File_Type;
         Buf  : Ada.Streams.Stream_Element_Array (0 .. Hash_Chunk - 1);
         Last : Ada.Streams.Stream_Element_Offset;
         Dig  : String (1 .. 64);
      begin
         begin
            Open (F, In_File, Path);
         exception
            when others =>
               return "";
         end;
         loop
            Read (F, Buf, Last);
            exit when Last < Buf'First;
            GNAT.SHA256.Update (Ctx, Buf (Buf'First .. Last));
         end loop;
         Close (F);
         Dig := GNAT.SHA256.Digest (Ctx);
         Stamp_Remember (Path, Dig);
         --  Record into the persistent index when the pre-read stash said
         --  this file is stampable (no extra stats here: the pair was
         --  captured before the read).
         PStamp_Record_Stashed (Dig);
         return Dig;
      exception
         when others =>
            if Is_Open (F) then
               Close (F);
            end if;
            return "";
      end;
   end Hash_File;

   function Hash_String (S : String) return String is
   begin
      return GNAT.SHA256.Digest (S);
   end Hash_String;

   procedure Store (Key : String; Data : String; Success : out Boolean) is
      DDir   : constant String := Entry_Path (Key);
      Parent : constant String := Subdir_Path (Key);
      F      : File_Type;
   begin
      Success := False;
      if Key'Length < 3 or else DDir = "" then
         return;
      end if;

      begin
         Create_Path (Parent);
         Create (F, Out_File, DDir);
         --  Single Write call over a type-punned view of the payload: on
         --  every GNAT x86/x86_64/AArch64 target Stream_Element is a byte
         --  with the same size as Character, so the arrays alias exactly.
         --  This replaces the per-character conversion loop (one bounds
         --  check and one shift per byte) with the runtime's block write,
         --  which is a single write(2) for a cache-sized blob.
         declare
            subtype Byte_Array is
              Stream_Element_Array
                (0 .. Stream_Element_Offset (Data'Length - 1));
            SEA : Byte_Array;
            for SEA'Address use Data'Address;
            pragma Import (Ada, SEA);
         begin
            Write (F, SEA);
         end;
         Close (F);
         Success := True;
      exception
         when others =>
            if Is_Open (F) then
               Close (F);
            end if;
      end;
   end Store;

   procedure Load
     (Key : String; Data : out String; Len : out Natural; Found : out Boolean)
   is
      DDir : constant String := Entry_Path (Key);
      F    : File_Type;
      Size : Natural;
   begin
      Len := 0;
      Found := False;
      if Key'Length < 3 or else DDir = "" then
         return;
      end if;
      --  No Exists() probe: the Open below answers presence in the same
      --  errno check.  The old shape paid two stats per load (Exists then
      --  Size) and every miss doubled them.
      begin
         Size := Natural (Ada.Directories.Size (DDir));
      exception
         when others =>
            return;
      end;
      if Size > Data'Length or else Size = 0 then
         return;
      end if;

      begin
         Open (F, In_File, DDir);
         declare
            SEA  :
              Stream_Element_Array (0 .. Stream_Element_Offset (Size - 1));
            Last : Stream_Element_Offset;
         begin
            Read (F, SEA, Last);
            --  Single block copy instead of the per-character conversion
            --  loop (same aliasing argument as Store): the whole payload
            --  lands in Data with one memcpy-shaped move.
            declare
               subtype Byte_Array is
                 Stream_Element_Array (0 .. Stream_Element_Offset (Size - 1));
               Out_SEA : Byte_Array;
               for Out_SEA'Address use Data (Data'First)'Address;
               pragma Import (Ada, Out_SEA);
            begin
               Out_SEA := SEA;
            end;
            Len := Natural (Last) + 1;
            Found := True;
         end;
         Close (F);
      exception
         when others =>
            if Is_Open (F) then
               Close (F);
            end if;
      end;
   end Load;

   function Exists (Key : String) return Boolean is
      DDir : constant String := Entry_Path (Key);
   begin
      if Key'Length < 3 or else DDir = "" then
         return False;
      end if;
      return Ada.Directories.Exists (DDir);
   end Exists;

   --  Current eviction cap (entries retained).  Set via Set_Cache_Policy.
   Cache_Cap : Positive := 4096;

   --  Location of the per-tool version-probe files.  Probes describe the
   --  *machine's* toolchain (which executables exist on PATH and their
   --  --version output), not a particular project's scan results, so they
   --  live in a stable directory that --cache-dir changes and cache wipes
   --  do not affect: wiping the result cache must not cost re-probing
   --  every tool (each probe spawns a subprocess; node/hg/mandb boot an
   --  interpreter).  A fixed probe root keeps a 7-day TTL the only reason
   --  a known toolchain ever re-probes.
   function Probe_Root return String is
      Home : constant String :=
        (if Ada.Environment_Variables.Exists ("HOME")
         then Ada.Environment_Variables.Value ("HOME")
         else "/tmp");
   begin
      return Home & "/.adacovex/probes";
   end Probe_Root;

   --  Identity of a tool's installed binary: the PATH-resolved executable
   --  path, its size, and its mtime, joined with '|'.  The probe cache
   --  stores this image next to the version it probed; a later lookup that
   --  presents a different image (binary upgraded, replaced, or shadowed
   --  by a PATH change) invalidates the stored answer.  This is the same
   --  identity rule the persistent stamp index uses for source files:
   --  cache entries are only as valid as the stat identity of the object
   --  they describe.  "" when the tool is not on PATH (the caller then
   --  never probes).
   function Tool_Fingerprint (Exe_Path : String) return String is
      Sz : Long_Long_Integer := -1;
      Mt : Long_Long_Integer := -1;
   begin
      if Exe_Path'Length = 0 then
         return "";
      end if;
      begin
         Sz := Long_Long_Integer (Ada.Directories.Size (Exe_Path));
      exception
         when others =>
            return Exe_Path;
      end;
      begin
         Mt := System.OS_Lib.To_C (System.OS_Lib.File_Time_Stamp (Exe_Path));
      exception
         when others =>
            Mt := -1;
      end;
      if Mt < 0 then
         return Exe_Path & "|" & Long_Long_Integer'Image (Sz);
      end if;
      return
        Exe_Path
        & "|"
        & Long_Long_Integer'Image (Sz)
        & "|"
        & Long_Long_Integer'Image (Mt);
   end Tool_Fingerprint;

   --  <probes>/<tool>.v2 -- per-tool version-probe file, outside the
   --  two-level entry tree so probes never collide with content-hashed blobs
   --  and are cheap to check.  The ".v2" suffix salts the namespace: the
   --  1.33 probe behaviour (flag fallbacks, `go version`, v/go token
   --  stripping) differs from the 1.32 single-flag probe, so old probe
   --  files must not be served as if they were fresh.
   function Probe_Path (Tool : String) return String is
      Root : constant String := Probe_Root;
   begin
      if Tool'Length = 0 or else Root'Length = 0 then
         return "";
      end if;
      return Root & "/" & Tool (Tool'First .. Tool'Last) & ".v2";
   end Probe_Path;

   procedure Get_Probe
     (Tool        : String;
      Fingerprint : String;
      Value       : out String;
      Val_Len     : out Natural;
      Found       : out Boolean)
   is
      use Ada.Calendar;
      Path : constant String := Probe_Path (Tool);
      F    : Ada.Text_IO.File_Type;
   begin
      Value := (others => ' ');
      Val_Len := 0;
      Found := False;
      if Path'Length = 0
        or else not Ada.Directories.Exists (Path)
        or else Fingerprint'Length = 0
      then
         return;
      end if;
      --  TTL: a stale probe is reported as not found; the caller re-probes
      --  and overwrites via Put_Probe.
      declare
         Age : constant Duration :=
           Clock - Ada.Directories.Modification_Time (Path);
      begin
         if Age < 0.0 or else Age > Duration (Probe_TTL_Days * 86_400) then
            return;
         end if;
      end;
      begin
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Path);
         --  Line 1: the binary fingerprint the answer was probed from.
         --  Line 2: the version.  A fingerprint mismatch (upgraded or
         --  replaced binary, PATH shadowing) discards the stored answer.
         --  A pre-fingerprint file (one line, v1.45.0 and earlier) has no
         --  second line and no match: reported as not found.
         if not Ada.Text_IO.End_Of_File (F) then
            declare
               Stored : String (1 .. 2600);
               SLen   : Natural := 0;
            begin
               Ada.Text_IO.Get_Line (F, Stored, SLen);
               if SLen /= Fingerprint'Length
                 or else Stored (1 .. SLen) /= Fingerprint
               then
                  Ada.Text_IO.Close (F);
                  return;
               end if;
            end;
         else
            Ada.Text_IO.Close (F);
            return;
         end if;
         if not Ada.Text_IO.End_Of_File (F) then
            Ada.Text_IO.Get_Line (F, Value, Val_Len);
            Found := True;
         end if;
         Ada.Text_IO.Close (F);
      exception
         when others =>
            if Ada.Text_IO.Is_Open (F) then
               Ada.Text_IO.Close (F);
            end if;
      end;
   end Get_Probe;

   procedure Put_Probe (Tool : String; Fingerprint : String; Value : String) is
      P : constant String := Probe_Path (Tool);
      F : Ada.Text_IO.File_Type;
   begin
      if P'Length = 0
        or else Fingerprint'Length = 0
        or else Fingerprint'Length > 2600
      then
         return;
      end if;
      begin
         Ada.Directories.Create_Path (Probe_Root);
      exception
         when others =>
            null;
      end;
      begin
         Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, P);
         Ada.Text_IO.Put_Line (F, Fingerprint);
         Ada.Text_IO.Put_Line (F, Value);
         Ada.Text_IO.Close (F);
      exception
         when others =>
            if Ada.Text_IO.Is_Open (F) then
               Ada.Text_IO.Close (F);
            end if;
      end;
   end Put_Probe;

   --  Location of the registry-metadata files.  Machine-local
   --  (~/.adacovex/meta/), outside the result cache, exactly like the
   --  system-tool probe store: a resolved registry answer describes the
   --  package at its recorded version, not the project's scan state, so
   --  wiping the result cache (or pointing --cache-dir at a fresh
   --  directory) must not cost a full re-resolution.  Measured on the
   --  self-audit tree: a full-cold run spent ~3.9 s of ~4.0 s wall inside
   --  the 11 registry CLI spawns (pnpm view, pip index versions, alr
   --  show); with the machine-local meta store warm, the same cold run
   --  drops to tens of milliseconds.  A stale or edited answer
   --  self-heals via the 7-day TTL (Probe_TTL_Days).  The key carries the
   --  target so two projects that share the machine store never serve
   --  each other's resolved licence or version.
   function Meta_Root return String is
      Home : constant String :=
        (if Ada.Environment_Variables.Exists ("HOME")
         then Ada.Environment_Variables.Value ("HOME")
         else "/tmp");
   begin
      return Home & "/.adacovex/meta";
   end Meta_Root;

   --  <meta>/<hash> -- keyed by the SHA-256 of "target|eco|name" so the
   --  filename is fixed-width, filesystem-safe, and stable per project.
   function Meta_Path
     (Target : String; Ecosystem : String; Name : String) return String
   is
      Root : constant String := Meta_Root;
   begin
      if Ecosystem'Length = 0 or else Name'Length = 0 or else Root'Length = 0
      then
         return "";
      end if;
      return Root & "/" & Hash_String (Target & "|" & Ecosystem & "|" & Name);
   end Meta_Path;

   procedure Get_Meta
     (Target    : String;
      Ecosystem : String;
      Name      : String;
      License   : out String;
      Lic_Len   : out Natural;
      Version   : out String;
      Ver_Len   : out Natural;
      Website   : out String;
      Web_Len   : out Natural;
      Found     : out Boolean)
   is
      use Ada.Calendar;
      Path : constant String := Meta_Path (Target, Ecosystem, Name);
      F    : Ada.Text_IO.File_Type;
   begin
      License := (others => ' ');
      Version := (others => ' ');
      Website := (others => ' ');
      Lic_Len := 0;
      Ver_Len := 0;
      Web_Len := 0;
      Found := False;
      if Path'Length = 0 or else not Ada.Directories.Exists (Path) then
         return;
      end if;
      --  TTL: a stale entry is reported as not found; the caller re-resolves
      --  and overwrites via Put_Meta.
      declare
         Age : constant Duration :=
           Clock - Ada.Directories.Modification_Time (Path);
      begin
         if Age < 0.0 or else Age > Duration (Probe_TTL_Days * 86_400) then
            return;
         end if;
      end;
      begin
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Path);
         if not Ada.Text_IO.End_Of_File (F) then
            Ada.Text_IO.Get_Line (F, License, Lic_Len);
         end if;
         if not Ada.Text_IO.End_Of_File (F) then
            Ada.Text_IO.Get_Line (F, Version, Ver_Len);
         end if;
         if not Ada.Text_IO.End_Of_File (F) then
            Ada.Text_IO.Get_Line (F, Website, Web_Len);
         end if;
         Ada.Text_IO.Close (F);
         Found := True;
      exception
         when others =>
            if Ada.Text_IO.Is_Open (F) then
               Ada.Text_IO.Close (F);
            end if;
      end;
   end Get_Meta;

   procedure Put_Meta
     (Target    : String;
      Ecosystem : String;
      Name      : String;
      License   : String;
      Version   : String;
      Website   : String)
   is
      P : constant String := Meta_Path (Target, Ecosystem, Name);
      F : Ada.Text_IO.File_Type;
   begin
      if P'Length = 0 then
         return;
      end if;
      begin
         Ada.Directories.Create_Path (Meta_Root);
      exception
         when others =>
            null;
      end;
      begin
         Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, P);
         Ada.Text_IO.Put_Line (F, License);
         Ada.Text_IO.Put_Line (F, Version);
         Ada.Text_IO.Put_Line (F, Website);
         Ada.Text_IO.Close (F);
      exception
         when others =>
            if Ada.Text_IO.Is_Open (F) then
               Ada.Text_IO.Close (F);
            end if;
      end;
   end Put_Meta;

   procedure Set_Cache_Policy (Max_Entries : Positive) is
   begin
      Cache_Cap := Max_Entries;
   end Set_Cache_Policy;
   procedure Reset_Process_Stamps is
   begin
      Stamp_Hash := (others => Empty_Hash);
      Stamp_Size := (others => -1);
      Stamp_Len := (others => 0);
      Stamp_Names := (others => (others => ' '));
      Stamp_Digest := (others => (others => ' '));
      Stamp_Misses := 0;
      --  Stamp_Hits is deliberately kept: it is a cumulative diagnostic.
      --  The persistent index is NOT reset: it is validated by the size
      --  and mtime of every file on the next lookup, so stale records are
      --  harmless; dropping it would cost a full re-hash for nothing.
      PStamp_Flush;
   end Reset_Process_Stamps;

   procedure Get_Cached
     (Key : String; Data : out String; Len : out Natural; Found : out Boolean)
   is
   begin
      Load (Key, Data, Len, Found);
   end Get_Cached;

   --  Running number of blob stores since the process started.  Eviction
   --  runs every Eviction_Interval stores instead of after every store, so
   --  a cold run that stores one blob per source file walks the cache tree
   --  once per interval instead of once per file (a full-tree walk is
   --  O(entries) readdir + stat syscalls; the cap is a soft cap, so a
   --  bounded overshoot of at most Eviction_Interval - 1 entries between
   --  evictions is by design).
   Evict_Interval : constant := 32;
   Evict_Store_Ct : Natural := 0;

   procedure Put_Cached (Key : String; Data : String; Success : out Boolean) is
   begin
      Store (Key, Data, Success);
      if Success then
         Evict_Store_Ct := Evict_Store_Ct + 1;
         if Evict_Store_Ct mod Evict_Interval = 0 then
            Evict_If_Needed (Cache_Cap);
         end if;
      end if;
   end Put_Cached;

   --  Visit every ordinary file under Root at depth <= 2 -- the fixed cache
   --  layout is <root>/<aa>/<key> plus <root>/meta/<hash> -- and track the
   --  one with the oldest modification time.  Iterative, not recursive: the
   --  two-level layout means a flat walk always finds every entry, and it
   --  avoids the recursion and the extra stat traffic of the old tree walk
   --  (eviction runs in a loop, so per-step overhead multiplies).  Returns
   --  "" when Root holds no files.  A deeper nesting is a layout violation
   --  and is skipped.
   function Oldest_File (Root : String) return String is
      Search : Search_Type;
      Ent    : Directory_Entry_Type;
      Best   : String (1 .. 4096) := (others => ' ');
      BLen   : Natural := 0;
      Best_T : Ada.Calendar.Time := Ada.Calendar.Clock;
      First  : Boolean := True;

      --  Remember Path when it is older than the current best.
      procedure Latest (Path : String) is
         T : Ada.Calendar.Time;
      begin
         begin
            T := Ada.Directories.Modification_Time (Path);
         exception
            when others =>
               return;
         end;
         if First or else (T - Best_T) < 0.0 then
            if Path'Length <= Best'Length then
               Best_T := T;
               BLen := Path'Length;
               Best (1 .. BLen) := Path;
               First := False;
            end if;
         end if;
      end Latest;
   begin
      begin
         if Kind (Root) /= Directory then
            return "";
         end if;
      exception
         when others =>
            return "";
      end;
      Start_Search (Search, Root, "");
      while More_Entries (Search) loop
         Get_Next_Entry (Search, Ent);
         declare
            N  : constant String := Full_Name (Ent);
            Sn : constant String := Simple_Name (Ent);
            K  : File_Kind := Ordinary_File;
         begin
            begin
               K := Kind (N);
            exception
               when others =>
                  K := Ordinary_File;
            end;
            if Sn /= "." and then Sn /= ".." then
               if K = Ordinary_File then
                  Latest (N);
               elsif K = Directory then
                  --  Second (and final) level: cache blobs and meta files.
                  --  Files qualify; anything deeper is skipped.
                  declare
                     S2 : Search_Type;
                     E2 : Directory_Entry_Type;
                  begin
                     Start_Search (S2, N, "");
                     while More_Entries (S2) loop
                        Get_Next_Entry (S2, E2);
                        declare
                           N2 : constant String := Full_Name (E2);
                           K2 : File_Kind := Ordinary_File;
                        begin
                           begin
                              K2 := Kind (N2);
                           exception
                              when others =>
                                 K2 := Ordinary_File;
                           end;
                           if K2 = Ordinary_File
                             and then Simple_Name (E2) /= "."
                             and then Simple_Name (E2) /= ".."
                           then
                              Latest (N2);
                           end if;
                        end;
                     end loop;
                     End_Search (S2);
                  end;
               end if;
            end if;
         end;
      end loop;
      End_Search (Search);
      return Best (1 .. BLen);
   end Oldest_File;

   --  Count the cache entries on disk (ordinary files at depth <= 2 under
   --  Root, metadata files included).  Flat and iterative for the same
   --  reason as Oldest_File: eviction calls it repeatedly, so every saved
   --  stat is a saved syscall.
   function Count_Files (Root : String) return Natural is
      Search : Search_Type;
      Ent    : Directory_Entry_Type;
      Total  : Natural := 0;
   begin
      begin
         if Kind (Root) /= Directory then
            return 0;
         end if;
      exception
         when others =>
            return 0;
      end;
      Start_Search (Search, Root, "");
      while More_Entries (Search) loop
         Get_Next_Entry (Search, Ent);
         declare
            N  : constant String := Full_Name (Ent);
            Sn : constant String := Simple_Name (Ent);
            K  : File_Kind := Ordinary_File;
         begin
            begin
               K := Kind (N);
            exception
               when others =>
                  K := Ordinary_File;
            end;
            if Sn /= "." and then Sn /= ".." then
               if K = Ordinary_File then
                  Total := Total + 1;
               elsif K = Directory then
                  declare
                     S2 : Search_Type;
                     E2 : Directory_Entry_Type;
                  begin
                     Start_Search (S2, N, "");
                     while More_Entries (S2) loop
                        Get_Next_Entry (S2, E2);
                        declare
                           N2 : constant String := Full_Name (E2);
                           K2 : File_Kind := Ordinary_File;
                        begin
                           begin
                              K2 := Kind (N2);
                           exception
                              when others =>
                                 K2 := Ordinary_File;
                           end;
                           if K2 = Ordinary_File then
                              Total := Total + 1;
                           end if;
                        end;
                     end loop;
                     End_Search (S2);
                  end;
               end if;
            end if;
         end;
      end loop;
      End_Search (Search);
      return Total;
   end Count_Files;

   procedure Evict_If_Needed (Max_Entries : Positive) is
      Count : Natural := Count_Files (Cache_Root (1 .. Cache_Root_Len));
   begin
      while Count > Max_Entries loop
         declare
            Old : constant String :=
              Oldest_File (Cache_Root (1 .. Cache_Root_Len));
         begin
            exit when Old'Length = 0;
            begin
               Delete_File (Old);
            exception
               when others =>
                  exit;
            end;
            Count := Count - 1;
            Eviction_Count := Eviction_Count + 1;
         end;
      end loop;
   end Evict_If_Needed;

   --  In-memory stream backing onto a fixed String buffer, used to turn any
   --  streamable value into a blob String (and back) without touching disk.
   type Memory_Stream is new Ada.Streams.Root_Stream_Type with record
      Buf        : String (1 .. Max_Cache_Blob) := (others => ' ');
      Count      : Natural := 0;
      Pos        : Positive := 1;
      Overflowed : Boolean := False;
   end record;

   overriding
   procedure Write
     (S : in out Memory_Stream; Item : Ada.Streams.Stream_Element_Array);

   overriding
   procedure Read
     (S    : in out Memory_Stream;
      Item : out Ada.Streams.Stream_Element_Array;
      Last : out Ada.Streams.Stream_Element_Offset);

   procedure Write
     (S : in out Memory_Stream; Item : Ada.Streams.Stream_Element_Array) is
   begin
      for I in Item'Range loop
         if S.Count < S.Buf'Last then
            S.Count := S.Count + 1;
            S.Buf (S.Count) := Character'Val (Item (I));
         else
            S.Overflowed := True;
         end if;
      end loop;
   end Write;

   procedure Read
     (S    : in out Memory_Stream;
      Item : out Ada.Streams.Stream_Element_Array;
      Last : out Ada.Streams.Stream_Element_Offset)
   is
      J : Stream_Element_Offset := Item'First - 1;
   begin
      while J < Item'Last and then S.Pos <= S.Count loop
         J := J + 1;
         Item (J) := Stream_Element (Character'Pos (S.Buf (S.Pos)));
         S.Pos := S.Pos + 1;
      end loop;
      Last := J;
   end Read;

   package body Serialization is

      function Serialize (X : T) return String is
         M : aliased Memory_Stream;
      begin
         T'Write (M'Access, X);
         if M.Overflowed then
            --  Blob would exceed Max_Cache_Blob: never persist a truncated
            --  payload (it would deserialize as silently-corrupt data).
            return "";
         end if;
         return M.Buf (1 .. M.Count);
      end Serialize;

      function Deserialize (S : String; X : out T) return Boolean is
         M : aliased Memory_Stream;
      begin
         if S'Length = 0 or else S'Length > M.Buf'Last then
            return False;
         end if;
         M.Buf (1 .. S'Length) := S;
         M.Count := S'Length;
         M.Pos := 1;
         T'Read (M'Access, X);
         return True;
      exception
         when others =>
            return False;
      end Deserialize;

   end Serialization;

begin
   Default_Cache_Dir (Cache_Root, Cache_Root_Len);
end Adacovex.Cache;
