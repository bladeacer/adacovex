with Ada.Directories;
with Ada.Text_IO;
with Interfaces;
with System.OS_Lib;

package body Adacovex.Dir_Cache is

   --  Memoised snapshot for one directory: the entry list, the live count,
   --  and the directory mtime the snapshot was taken at (integer OS
   --  seconds, the same epoch the stamp store uses).  The path image is
   --  stored inline so a hit needs no re-allocation.
   type Slot is record
      Used     : Boolean := False;
      Path_Len : Natural := 0;
      Path_Img : String (1 .. 1024) := (others => ' ');
      Mtime    : Long_Long_Integer := -1;
      Count    : Natural := 0;
      Entries  : Dir_Entry_List;
   end record;

   Table       : array (1 .. Memo_Slots) of Slot;
   Next_Victim : Natural := 1;

   --  The process working directory, resolved once and reused.  Walkers
   --  spell the same directory differently (".", "src", "/abs/src",
   --  "./src"); resolving every key to its absolute image makes them all
   --  share one memo slot.  Len = 0 means "not resolved yet".
   Cwd_Len : Natural := 0;
   Cwd_Img : String (1 .. 1024) := (others => ' ');

   --  Hash a path into the table range.  FNV-1a over the bytes.
   function Slot_Of (Path : String) return Natural is
      use type Interfaces.Unsigned_32;
      H : Interfaces.Unsigned_32 := 16#811c9dc5#;
   begin
      for I in Path'Range loop
         H :=
           (H xor Interfaces.Unsigned_32 (Character'Pos (Path (I))))
           * 16#01000193#;
      end loop;
      return Natural (H mod Interfaces.Unsigned_32 (Memo_Slots)) + 1;
   end Slot_Of;

   --  Current mtime of Dir as integer OS seconds, or -1 when unreadable.
   --  One stat: System.OS_Lib.File_Time_Stamp answers existence and time
   --  in the same probe.
   function Dir_Mtime (Dir : String) return Long_Long_Integer is
   begin
      return System.OS_Lib.To_C (System.OS_Lib.File_Time_Stamp (Dir));
   exception
      when others =>
         return -1;
   end Dir_Mtime;

   --  Absolute image of Key: Key itself when already absolute, otherwise
   --  the cached working directory joined with Key (with "." and a lone
   --  "/" separator folded away).  Returns Key unchanged when it does not
   --  fit the buffer -- the caller then memoises under the raw spelling,
   --  which is correct (just less shareable).
   function Abs_Key (Key : String) return String is
      Out_Len : Natural := 0;
   begin
      if Key'Length = 0 or else Key (Key'First) = '/' then
         return Key;
      end if;
      if Cwd_Len = 0 then
         declare
            use type System.OS_Lib.OS_Time;
            C : constant String := Ada.Directories.Current_Directory;
         begin
            if C'Length <= Cwd_Img'Last then
               Cwd_Len := C'Length;
               Cwd_Img (1 .. Cwd_Len) := C;
            end if;
         end;
      end if;
      if Cwd_Len = 0 or else Cwd_Len + 1 + Key'Length > Cwd_Img'Last then
         return Key;
      end if;
      declare
         Res : String (1 .. Cwd_Len + 1 + Key'Length);
      begin
         Res (1 .. Cwd_Len) := Cwd_Img (1 .. Cwd_Len);
         if Cwd_Img (Cwd_Len) /= '/' then
            Res (Cwd_Len + 1) := '/';
            Res (Cwd_Len + 2 .. Res'Last) := Key;
            Out_Len := Res'Last;
         else
            Res (Cwd_Len + 1 .. Res'Last) := Key;
            Out_Len := Res'Last;
         end if;
         return Res (1 .. Out_Len);
      end;
   end Abs_Key;

   procedure Snapshot
     (Dir       : String;
      Entries   : out Dir_Entry_List;
      Count     : out Natural;
      Truncated : out Boolean;
      OK        : out Boolean)
   is
      use Ada.Directories;
      Key   : constant String := Abs_Key (Dir);
      Now_M : constant Long_Long_Integer := Dir_Mtime (Key);

      --  Read the directory straight into the caller's buffer.  Returns
      --  True when the read succeeded (OK then holds True and Count the
      --  live entry count -- possibly > Max_Dir_Entries, which is
      --  Truncated).
      function Read_Direct return Boolean is
         Search : Search_Type;
         Ent    : Directory_Entry_Type;
      begin
         Count := 0;
         Start_Search (Search, Dir, "");
         while More_Entries (Search) loop
            Get_Next_Entry (Search, Ent);
            declare
               N : constant String := Simple_Name (Ent);
            begin
               if N /= "." and then N /= ".." then
                  if Count < Max_Dir_Entries then
                     if N'Length > Max_Name_Len then
                        Count := 0;
                        End_Search (Search);
                        return True;   -- over-long name: truncated

                     end if;
                     Count := Count + 1;
                     Entries (Count).Name_Len := N'Length;
                     Entries (Count).Name (1 .. N'Length) := N;
                     --  Kind on the freshly-read entry is already cached
                     --  by Start_Search (the enumeration stats each entry
                     --  exactly once); no extra probe here.
                     begin
                        case Kind (Ent) is
                           when Ordinary_File =>
                              Entries (Count).Kind := K_File;

                           when Directory     =>
                              Entries (Count).Kind := K_Dir;

                           when others        =>
                              Entries (Count).Kind := K_Other;
                        end case;
                     exception
                        when others =>
                           Entries (Count).Kind := K_Other;
                     end;
                  else
                     --  Over-cap: finish the count to mark truncation,
                     --  then stop.
                     Count := Count + 1;
                     exit;
                  end if;
               end if;
            end;
         end loop;
         End_Search (Search);
         return True;
      exception
         when others =>
            begin
               End_Search (Search);
            exception
               when others =>
                  null;
            end;
            return False;
      end Read_Direct;
   begin
      Count := 0;
      Truncated := False;
      OK := False;
      if Key'Length = 0 or else Key'Length > 1024 then
         return;
      end if;

      --  Probe the memo: a slot whose path matches and whose mtime is
      --  unchanged serves the snapshot after the one stat above.
      declare
         Idx : constant Natural := Slot_Of (Key);
      begin
         if Table (Idx).Used
           and then Table (Idx).Path_Len = Key'Length
           and then Table (Idx).Path_Img (1 .. Key'Length) = Key
           and then Table (Idx).Mtime >= 0
           and then Table (Idx).Mtime = Now_M
         then
            Entries := Table (Idx).Entries;
            Count := Table (Idx).Count;
            Hits := Hits + 1;
            OK := True;
            return;
         end if;
      end;

      Misses := Misses + 1;
      if not Read_Direct then
         return;
      end if;
      OK := True;
      if Count > Max_Dir_Entries then
         --  Over-cap directory: serve the count so the caller falls back,
         --  and never memoise (huge churn trees would evict useful
         --  snapshots).
         Truncated := True;
         return;
      end if;
      --  Memoise in the hashed slot (linear probe for a free slot).
      declare
         Idx : Natural := Slot_Of (Key);
      begin
         for Probed in 0 .. Memo_Slots - 1 loop
            Idx := ((Slot_Of (Key) - 1 + Probed) mod Memo_Slots) + 1;
            if not Table (Idx).Used
              or else (Table (Idx).Path_Len = Key'Length
                       and then Table (Idx).Path_Img (1 .. Key'Length) = Key)
            then
               Table (Idx).Used := True;
               Table (Idx).Path_Len := Key'Length;
               Table (Idx).Path_Img (1 .. Key'Length) := Key;
               Table (Idx).Mtime := Now_M;
               Table (Idx).Count := Count;
               Table (Idx).Entries := Entries;
               return;
            end if;
         end loop;
         --  Table full and Key not present: replace the round-robin
         --  victim.
         Table (Next_Victim).Used := True;
         Table (Next_Victim).Path_Len := Key'Length;
         Table (Next_Victim).Path_Img (1 .. Key'Length) := Key;
         Table (Next_Victim).Mtime := Now_M;
         Table (Next_Victim).Count := Count;
         Table (Next_Victim).Entries := Entries;
         Next_Victim := (Next_Victim mod Memo_Slots) + 1;
      end;
   end Snapshot;

   procedure Reset is
   begin
      Table := (others => <>);
      Next_Victim := 1;
      Misses := 0;
   end Reset;

end Adacovex.Dir_Cache;
