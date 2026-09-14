with Adacovex.Prove;
with Adacovex.CPUs;
with Ada.Directories;
with Ada.Text_IO;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package body Adacovex_Prove_Runner_Tests is

   Fixture_Dir : constant String :=
     Adacovex.CPUs.Get_Temp_Directory & "/adacovex_prove_runner_test";
   Missing_Dir : constant String :=
     Adacovex.CPUs.Get_Temp_Directory & "/adacovex_prove_runner_missing";

   --  True when Needle appears in Haystack.
   --  @param Haystack  String to search.
   --  @param Needle  Substring to look for.
   --  @return True when the substring is present.
   function Has_Text (Haystack : String; Needle : String) return Boolean is
   begin
      if Needle'Length = 0 or else Needle'Length > Haystack'Length then
         return False;
      end if;
      for I in Haystack'First .. Haystack'Last - Needle'Length + 1 loop
         if Haystack (I .. I + Needle'Length - 1) = Needle then
            return True;
         end if;
      end loop;
      return False;
   end Has_Text;

   --  Create an empty file.
   --  @param Path  File path to create.
   procedure Touch (Path : String) is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Close (F);
   end Touch;

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      O   : Adacovex.Prove.Prove_Options;
      GPR : String (1 .. 512);
      Len : Natural;
      OK  : Boolean;

      --  Rebuild the fixture directory with exactly the listed .gpr files.
      --  @param First_GPR  Name of the first project file to create.
      --  @param Second_GPR  Name of a second project file ("" for none).
      procedure Fixture (First_GPR : String; Second_GPR : String := "") is
      begin
         if Ada.Directories.Exists (Fixture_Dir) then
            Ada.Directories.Delete_Tree (Fixture_Dir);
         end if;
         Ada.Directories.Create_Directory (Fixture_Dir);
         if First_GPR'Length > 0 then
            Touch (Fixture_Dir & "/" & First_GPR);
         end if;
         if Second_GPR'Length > 0 then
            Touch (Fixture_Dir & "/" & Second_GPR);
         end if;
      end Fixture;
   begin
      --  Defaults: auto-detected jobs, the default step budget, and loop
      --  unrolling always disabled.
      R.Check
        (Adacovex.Prove.Detect_Core_Count >= 1,
         "the detected core count is at least one");

      declare
         S : constant String := Adacovex.Prove.Build_Option_String (O, 8);
      begin
         R.Check
           (S = "-j 8 --steps 10000 --no-loop-unrolling",
            "the default option string is jobs, steps, no-unrolling");
      end;

      --  Zero jobs is forwarded as-is (all cores).
      declare
         S : constant String := Adacovex.Prove.Build_Option_String (O, 0);
      begin
         R.Check (Has_Text (S, "-j 0"), "-j0 forwards every core");
      end;

      --  Every configured option is forwarded, in a stable order.
      O.Jobs := 4;
      O.Level := 3;
      O.Timeout := 60;
      O.Steps := 2000;
      O.Memlimit := 1500;
      O.Force := True;
      O.No_Inlining := True;
      declare
         S : constant String := Adacovex.Prove.Build_Option_String (O, 4);
      begin
         R.Check
           (S
            = "-j 4 --level 3 --timeout 60 --steps 2000 --memlimit 1500"
              & " -f --no-loop-unrolling --no-inlining",
            "the configured option string carries every switch in order");
      end;

      --  An explicit --steps value replaces the default budget.
      R.Check
        (Has_Text (Adacovex.Prove.Build_Option_String (O, 4), "--steps 2000"),
         "an explicit step budget replaces the default");

      --  Raw --args passthrough lands after the built options.
      O.Extra_Args := To_Unbounded_String ("--counterexamples=on");
      declare
         S : constant String := Adacovex.Prove.Build_Option_String (O, 4);
      begin
         R.Check
           (Has_Text (S, "--counterexamples=on"),
            "the raw --args value is appended verbatim");
         R.Check
           (Has_Text (S, "--no-inlining --counterexamples=on"),
            "the raw --args value follows the built options");
      end;

      --  Root GPR lookup: a directory with no project file has none.
      Fixture ("");
      Adacovex.Prove.Find_Root_GPR (Fixture_Dir, GPR, Len, OK);
      R.Check (not OK, "a target without a .gpr reports no root project");

      --  A single project file is the root project.
      Fixture ("single.gpr");
      Adacovex.Prove.Find_Root_GPR (Fixture_Dir, GPR, Len, OK);
      R.Check (OK, "a single .gpr is resolved as the root project");
      R.Check
        (Len > 0 and then GPR (1 .. Len) = Fixture_Dir & "/single.gpr",
         "the resolved root project path is the fixture .gpr");

      --  Two project files are ambiguous: no root project is reported.
      Fixture ("first.gpr", "second.gpr");
      Adacovex.Prove.Find_Root_GPR (Fixture_Dir, GPR, Len, OK);
      R.Check
        (not OK, "two .gpr files are ambiguous and report no root project");

      --  A missing directory reports no root project.
      if Ada.Directories.Exists (Missing_Dir) then
         Ada.Directories.Delete_Tree (Missing_Dir);
      end if;
      Adacovex.Prove.Find_Root_GPR (Missing_Dir, GPR, Len, OK);
      R.Check (not OK, "a missing target directory reports no root project");

      Ada.Directories.Delete_Tree (Fixture_Dir);
   end Run;

end Adacovex_Prove_Runner_Tests;
