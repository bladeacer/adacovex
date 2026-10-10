with Adacovex.Dir_Cache;
with Ada.Directories;
with Ada.Text_IO;

package body Adacovex_Dir_Cache_Tests is

   --  The fixture lives under obj/ so that a relative spelling and an
   --  absolute spelling of the same directory can both be exercised without
   --  changing the process working directory.
   Fixture_Rel : constant String := "obj/adacovex_dir_cache_test";
   Fixture_Abs : constant String :=
     Ada.Directories.Current_Directory & "/obj/adacovex_dir_cache_test";
   Over_Rel    : constant String := "obj/adacovex_dir_cache_over";
   Over_Abs    : constant String :=
     Ada.Directories.Current_Directory & "/obj/adacovex_dir_cache_over";
   Long_Rel    : constant String := "obj/adacovex_dir_cache_long";
   Long_Abs    : constant String :=
     Ada.Directories.Current_Directory & "/obj/adacovex_dir_cache_long";
   Missing_Abs : constant String :=
     Ada.Directories.Current_Directory & "/obj/adacovex_dir_cache_missing";

   --  Remove Dir when it exists, then recreate it empty.
   --  @param Dir  Directory path to reset.
   procedure Fresh_Dir (Dir : String) is
   begin
      if Ada.Directories.Exists (Dir) then
         Ada.Directories.Delete_Tree (Dir);
      end if;
      Ada.Directories.Create_Directory (Dir);
   end Fresh_Dir;

   --  Create an empty file.
   --  @param Path  File path to create.
   procedure Touch (Path : String) is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Close (F);
   end Touch;

   --  Whether Entries (1 .. Count) holds Name classified as Kind.
   --  @param Entries  Snapshot entry list.
   --  @param Count  Number of valid entries.
   --  @param Name  Entry name to look for.
   --  @param Kind  Expected classification.
   --  @return True when the entry is present with that classification.
   function Holds
     (Entries : Adacovex.Dir_Cache.Dir_Entry_List;
      Count   : Natural;
      Name    : String;
      Kind    : Adacovex.Dir_Cache.Entry_Kind) return Boolean
   is
      use type Adacovex.Dir_Cache.Entry_Kind;
      Found : Boolean := False;
   begin
      for I in 1 .. Count loop
         if Entries (I).Name_Len = Name'Length
           and then Entries (I).Name (1 .. Entries (I).Name_Len) = Name
           and then Entries (I).Kind = Kind
         then
            Found := True;
         end if;
      end loop;
      return Found;
   end Holds;

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      E      : Adacovex.Dir_Cache.Dir_Entry_List;
      C      : Natural;
      Trunc  : Boolean;
      OK     : Boolean;
      Hits_0 : Natural;
   begin
      if not Ada.Directories.Exists ("obj") then
         Ada.Directories.Create_Directory ("obj");
      end if;

      --  Entry classification helper.
      R.Check
        (Adacovex.Dir_Cache.Is_Directory (Adacovex.Dir_Cache.K_Dir),
         "K_Dir classifies as a directory");
      R.Check
        (not Adacovex.Dir_Cache.Is_Directory (Adacovex.Dir_Cache.K_File),
         "K_File does not classify as a directory");
      R.Check
        (not Adacovex.Dir_Cache.Is_Directory (Adacovex.Dir_Cache.K_Other),
         "K_Other does not classify as a directory");

      --  A directory that cannot be read reports OK = False.
      if Ada.Directories.Exists (Missing_Abs) then
         Ada.Directories.Delete_Tree (Missing_Abs);
      end if;
      Adacovex.Dir_Cache.Snapshot (Missing_Abs, E, C, Trunc, OK);
      R.Check (not OK, "a missing directory reports OK = False");
      R.Check (not Trunc, "a missing directory is not reported truncated");

      --  Fixture: one regular file and one subdirectory.
      Fresh_Dir (Fixture_Abs);
      Touch (Fixture_Abs & "/one.ads");
      Ada.Directories.Create_Directory (Fixture_Abs & "/sub");

      Adacovex.Dir_Cache.Reset;
      R.Check (Adacovex.Dir_Cache.Misses = 0, "Reset clears the miss count");

      declare
         Before_M : constant Natural := Adacovex.Dir_Cache.Misses;
      begin
         Adacovex.Dir_Cache.Snapshot (Fixture_Abs, E, C, Trunc, OK);
         R.Check (OK, "the fixture directory reads OK");
         R.Check (not Trunc, "a small directory is not truncated");
         R.Check (C = 2, "the snapshot holds both fixtures entries");
         R.Check
           (Holds (E, C, "one.ads", Adacovex.Dir_Cache.K_File),
            "a regular file is classified as K_File");
         R.Check
           (Holds (E, C, "sub", Adacovex.Dir_Cache.K_Dir),
            "a subdirectory is classified as K_Dir");
         R.Check
           (Adacovex.Dir_Cache.Misses = Before_M + 1,
            "the first touch of a directory is a miss");
      end;

      Hits_0 := Adacovex.Dir_Cache.Hits;
      Adacovex.Dir_Cache.Snapshot (Fixture_Abs, E, C, Trunc, OK);
      R.Check
        (Adacovex.Dir_Cache.Hits = Hits_0 + 1,
         "the second touch is served from the memo");
      R.Check (C = 2, "the memoised snapshot keeps the entry count");

      --  Two spellings of one directory share one memo slot: a hit on the
      --  absolute spelling proves the relative touch populated it.
      Adacovex.Dir_Cache.Reset;
      Adacovex.Dir_Cache.Snapshot (Fixture_Rel, E, C, Trunc, OK);
      R.Check (OK and then C = 2, "a relative spelling enumerates the tree");
      Hits_0 := Adacovex.Dir_Cache.Hits;
      Adacovex.Dir_Cache.Snapshot (Fixture_Abs, E, C, Trunc, OK);
      R.Check
        (Adacovex.Dir_Cache.Hits = Hits_0 + 1,
         "a relative and an absolute spelling share one snapshot");

      --  Reset drops every snapshot: the next touch is a real enumeration.
      Adacovex.Dir_Cache.Reset;
      Hits_0 := Adacovex.Dir_Cache.Hits;
      Adacovex.Dir_Cache.Snapshot (Fixture_Abs, E, C, Trunc, OK);
      R.Check
        (Adacovex.Dir_Cache.Misses = 1
         and then Adacovex.Dir_Cache.Hits = Hits_0,
         "Reset drops the snapshots and keeps Hits cumulative");

      --  An entry name longer than the memo can hold forces the caller
      --  back to direct enumeration instead of reporting an empty tree.
      Fresh_Dir (Long_Abs);
      Touch (Long_Abs & "/short.ads");
      Touch (Long_Abs & "/" & (1 .. 130 => 'a'));
      Adacovex.Dir_Cache.Reset;
      Adacovex.Dir_Cache.Snapshot (Long_Abs, E, C, Trunc, OK);
      R.Check (OK, "an over-long entry name still reads OK");
      R.Check (Trunc, "an over-long entry name reports truncation");

      --  A directory over the entry cap is reported truncated as well.
      Fresh_Dir (Over_Abs);
      for I in 1 .. Adacovex.Dir_Cache.Max_Dir_Entries + 4 loop
         Touch (Over_Abs & "/f" & Natural'Image (I));
      end loop;
      Adacovex.Dir_Cache.Reset;
      Adacovex.Dir_Cache.Snapshot (Over_Abs, E, C, Trunc, OK);
      R.Check (OK, "an over-cap directory still reads OK");
      R.Check (Trunc, "an over-cap directory reports truncation");
      R.Check
        (C > Adacovex.Dir_Cache.Max_Dir_Entries,
         "the over-cap count exceeds the memo capacity");

      --  Clean up.
      Adacovex.Dir_Cache.Reset;
      Ada.Directories.Delete_Tree (Fixture_Abs);
      Ada.Directories.Delete_Tree (Over_Abs);
      Ada.Directories.Delete_Tree (Long_Abs);
   end Run;

end Adacovex_Dir_Cache_Tests;
