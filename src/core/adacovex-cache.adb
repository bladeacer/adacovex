with Ada.Calendar;
with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Environment_Variables;
with Ada.Text_IO;
with GNAT.SHA256;

package body Adacovex.Cache is

   use Ada.Directories;
   use Ada.Calendar;
   use Ada.Streams;
   use Ada.Streams.Stream_IO;

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

   --  In-memory map of file path -> (size, canonical filename) recorded at
   --  the last Stamped_Hash call.  It is bounded: when the map reaches
   --  Stamp_Map_Max entries, existing entries are dropped (a period of
   --  pathological churn just causes a re-hash).  Sized on insertion so a
   --  changed content with identically-sized file appears as a fresh hash.
   type Stamp_Entry is record
      Size : Long_Long_Integer := -1;
      Name : String (1 .. 2048) := (others => ' ');
   end record;
   subtype Stamp_Index is Natural range 0 .. 4095;
   Stamp_Names   : array (Stamp_Index) of String (1 .. 2048) :=
     (others => (others => ' '));
   Stamp_Sizes   : array (Stamp_Index) of Long_Long_Integer := (others => -1);
   Stamp_Digests : array (Stamp_Index) of String (1 .. 64) :=
     (others => (others => ' '));

   --  Current stamp of a file: size (or -1 when Size raises).
   function File_Size (Path : String) return Long_Long_Integer is
      use Ada.Directories;
   begin
      return Long_Long_Integer (Size (Path));
   exception
      when others =>
         return -1;
   end File_Size;

   --  Find Path in the stamp map.  Returns the index or -1.
   function Stamp_Find (Path : String) return Integer is
   begin
      for I in Stamp_Index loop
         if Stamp_Sizes (I) >= 0 then
            declare
               N : constant String :=
                 Stamp_Names (I) (1 .. Stamp_Names (I)'Length);
            begin
               if N = Path then
                  return I;
               end if;
            end;
         end if;
      end loop;
      return -1;
   end Stamp_Find;

   --  Serve a previously-remembered digest when Path's size still matches
   --  the size recorded with that digest.  The path must be the same
   --  string (a re-scan of the same file).  The function returns "" when
   --  there is no matching stamp (the caller then falls back to
   --  Hash_File).
   function Hash_Fast (Path : String) return String is
      Sz : constant Long_Long_Integer := File_Size (Path);
   begin
      if Sz < 0 or else Path'Length > 2048 then
         return "";
      end if;
      for I in Stamp_Index loop
         if Stamp_Sizes (I) = Sz
           and then Stamp_Names (I) (1 .. Stamp_Names (I)'Length) = Path
         then
            return Stamp_Digests (I);
         end if;
      end loop;
      return "";
   end Hash_Fast;

   --  Remember Path with the given digest (and Path's size at hash time)
   --  so a later Hash_Fast (same path, same size) can reuse the digest
   --  without re-reading the file.  The size is the strongest cheap
   --  proxy for "content unchanged" after this process already hashed the
   --  file; mtime is secondary and not tracked.
   procedure Stamp_Remember (Path : String; Digest : String) is
      Idx : Integer;
   begin
      if Path'Length > 2048 or else Digest'Length /= 64 then
         return;
      end if;
      Idx := Stamp_Find (Path);
      if Idx < 0 then
         --  insert at the first free slot
         for I in Stamp_Index loop
            if Stamp_Sizes (I) < 0 then
               Idx := I;
               exit;
            end if;
         end loop;
         if Idx < 0 then
            return;  --  map full; skip

         end if;
      end if;
      Stamp_Names (Idx) (1 .. Path'Length) := Path;
      Stamp_Sizes (Idx) := File_Size (Path);
      Stamp_Digests (Idx) (1 .. 64) := Digest;
   end Stamp_Remember;

   function Hash_File (Path : String) return String is
      Fast : constant String := Hash_Fast (Path);
   begin
      if Fast'Length = 64 then
         return Fast;
      end if;
      declare
         Ctx  : GNAT.SHA256.Context;
         F    : File_Type;
         Buf  : Ada.Streams.Stream_Element_Array (0 .. 8191);
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

   --  <probes>/<tool> -- per-tool version-probe file, outside the two-level
   --  entry tree so probes never collide with content-hashed blobs and are
   --  cheap to check.
   function Probe_Path (Tool : String) return String is
      Root : constant String := Probe_Root;
   begin
      if Tool'Length = 0 or else Root'Length = 0 then
         return "";
      end if;
      return Root & "/" & Tool (Tool'First .. Tool'Last);
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

   function Oldest_File (Dir : String) return String is
      Search : Search_Type;
      Ent    : Directory_Entry_Type;
      Best   : String (1 .. 4096) := (others => ' ');
      BLen   : Natural := 0;
      Best_T : Ada.Calendar.Time := Ada.Calendar.Clock;
      First  : Boolean := True;
   begin
      begin
         if Kind (Dir) /= Directory then
            return "";
         end if;
      exception
         when others =>
            return "";
      end;
      Start_Search (Search, Dir, "");
      while More_Entries (Search) loop
         Get_Next_Entry (Search, Ent);
         declare
            N : constant String := Full_Name (Ent);
            K : File_Kind;
         begin
            K := Kind (N);
            if K = Directory then
               if Simple_Name (Ent) /= "." and then Simple_Name (Ent) /= ".."
               then
                  declare
                     Sub : constant String := Oldest_File (N);
                  begin
                     if Sub'Length > 0 then
                        declare
                           T : constant Ada.Calendar.Time :=
                             Ada.Directories.Modification_Time (Sub);
                        begin
                           if First or else (T - Best_T) < 0.0 then
                              Best_T := T;
                              if Sub'Length <= Best'Length then
                                 BLen := Sub'Length;
                                 Best (1 .. BLen) := Sub;
                              end if;
                              First := False;
                           end if;
                        end;
                     end if;
                  end;
               end if;
            elsif K = Ordinary_File then
               declare
                  T : constant Ada.Calendar.Time :=
                    Ada.Directories.Modification_Time (N);
               begin
                  if First or else (T - Best_T) < 0.0 then
                     Best_T := T;
                     if N'Length <= Best'Length then
                        BLen := N'Length;
                        Best (1 .. BLen) := N;
                     end if;
                     First := False;
                  end if;
               end;
            end if;
         end;
      end loop;
      End_Search (Search);
      return Best (1 .. BLen);
   end Oldest_File;

   function Count_Files (Dir : String) return Natural is
      Search : Search_Type;
      Ent    : Directory_Entry_Type;
      Total  : Natural := 0;
   begin
      begin
         if Kind (Dir) /= Directory then
            return 0;
         end if;
      exception
         when others =>
            return 0;
      end;
      Start_Search (Search, Dir, "");
      while More_Entries (Search) loop
         Get_Next_Entry (Search, Ent);
         declare
            N : constant String := Full_Name (Ent);
            K : File_Kind;
         begin
            K := Kind (N);
            if K = Directory then
               if Simple_Name (Ent) /= "." and then Simple_Name (Ent) /= ".."
               then
                  Total := Total + Count_Files (N);
               end if;
            elsif K = Ordinary_File then
               Total := Total + 1;
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
