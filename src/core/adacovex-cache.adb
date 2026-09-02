with Ada.Calendar;
with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Environment_Variables;
with Ada.Text_IO;
with GNAT.SHA256;
with Interfaces;

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

   --  Current stamp of a file: size (or -1 when Size raises).
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
   --  and diagnostics can see whether the fast path fired.
   function Hash_Fast (Path : String) return String is
      Sz  : constant Long_Long_Integer := File_Size (Path);
      Idx : Integer;
   begin
      if Sz < 0 or else Path'Length = 0 or else Path'Length > 2048 then
         return "";
      end if;
      Idx := Stamp_Find (Path);
      if Idx < 0 then
         Stamp_Misses := Stamp_Misses + 1;
         return "";
      end if;
      if Stamp_Size (Idx) = Sz then
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

   function Hash_File (Path : String) return String is
      Fast : constant String := Hash_Fast (Path);
   begin
      if Fast'Length = 64 then
         return Fast;
      end if;
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
      SEA    :
        Stream_Element_Array (0 .. Stream_Element_Offset (Data'Length - 1));
   begin
      Success := False;
      if Key'Length < 3 or else DDir = "" then
         return;
      end if;

      begin
         Create_Path (Parent);
         Create (F, Out_File, DDir);
         for I in Data'Range loop
            SEA (Stream_Element_Offset (I - Data'First)) :=
              Stream_Element (Character'Pos (Data (I)));
         end loop;
         Write (F, SEA);
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
      if not Ada.Directories.Exists (DDir) then
         return;
      end if;

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
            for I in SEA'Range loop
               Data (Data'First + Natural (I)) := Character'Val (SEA (I));
            end loop;
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
     (Tool    : String;
      Value   : out String;
      Val_Len : out Natural;
      Found   : out Boolean)
   is
      use Ada.Calendar;
      Path : constant String := Probe_Path (Tool);
      F    : Ada.Text_IO.File_Type;
   begin
      Value := (others => ' ');
      Val_Len := 0;
      Found := False;
      if Path'Length = 0 or else not Ada.Directories.Exists (Path) then
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
         if not Ada.Text_IO.End_Of_File (F) then
            Ada.Text_IO.Get_Line (F, Value, Val_Len);
         end if;
         Ada.Text_IO.Close (F);
         Found := True;
      exception
         when others =>
            if Ada.Text_IO.Is_Open (F) then
               Ada.Text_IO.Close (F);
            end if;
      end;
   end Get_Probe;

   procedure Put_Probe (Tool : String; Value : String) is
      P : constant String := Probe_Path (Tool);
      F : Ada.Text_IO.File_Type;
   begin
      if P'Length = 0 then
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
         Ada.Text_IO.Put_Line (F, Value);
         Ada.Text_IO.Close (F);
      exception
         when others =>
            if Ada.Text_IO.Is_Open (F) then
               Ada.Text_IO.Close (F);
            end if;
      end;
   end Put_Probe;

   --  Location of the per-project registry-metadata files.  This lives under
   --  the configured result cache (per --cache-dir, so the project's own
   --  cache when one is set), not in a separate machine-local store: the meta
   --  answer is scoped to the project that owns the package, and clearing the
   --  project cache clears it too.  The key also carries the target so two
   --  projects that share a cache directory never serve each other's
   --  resolved licence or version.
   function Meta_Root return String is
      Dir : String (1 .. 1024);
      Len : Natural := 0;
   begin
      Cache_Dir (Dir, Len);
      if Len = 0 then
         return "";
      end if;
      return Dir (Dir'First .. Dir'First + Len - 1) & "/meta";
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
