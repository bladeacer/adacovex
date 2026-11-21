with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Adacovex.Cache;
with Adacovex.Paths;
with Adacovex.Prove;

package body Adacovex.Prove_Units is

   use Ada.Strings.Fixed;
   use Ada.Strings.Unbounded;

   --  Unit sources and `with` names share the same unbounded containers.
   package Path_Vectors is new
     Ada.Containers.Vectors (Positive, Unbounded_String);
   package Name_Vectors is new
     Ada.Containers.Vectors (Positive, Unbounded_String);

   --  One local unit's base stem (for example "a-b") and its path. The stem
   --  map resolves a `with A.B;` clause to the local spec file.
   type Stem_Entry is record
      Stem : Unbounded_String := Null_Unbounded_String;
      Path : Unbounded_String := Null_Unbounded_String;
   end record;

   package Stem_Vectors is new Ada.Containers.Vectors (Positive, Stem_Entry);

   --  Whether a directory name cannot hold project proof units. It mirrors
   --  the proof-input walk in Adacovex.Prove, so unit enumeration and the
   --  whole-run hash see the same files.
   --  @param Name  Directory base name.
   --  @return True when the walk skips the directory.
   function Skip_Dir (Name : String) return Boolean is
   begin
      return
        Name = ".git"
        or else Name = ".jj"
        or else Name = ".hg"
        or else Name = ".svn"
        or else Name = ".fslckout"
        or else Name = "_FOSSIL_"
        or else Name = "obj"
        or else Name = "bin"
        or else Name = "tests"
        or else Name = "config"
        or else Name = ".adacovex"
        or else Name = "alire"
        or else Name = "gnatprove"
        or else Name = "__pycache__"
        or else Name = "node_modules"
        or else Name = ".venv"
        or else Name = ".headroom"
        or else Name = ".lccst"
        or else Name = "_build"
        or else Name = "dist"
        or else Name = "index"
        or else Name = "resources"
        or else Name = "docs";
   end Skip_Dir;

   --  The lower-case extension of a file name (without the dot), or "" when
   --  the name has no extension.
   --  @param Name  File base name.
   --  @return Lower-case extension.
   function Extension_Of (Name : String) return String is
      Dot : Natural := 0;
   begin
      for I in reverse Name'Range loop
         if Name (I) = '.' then
            Dot := I;
            exit;
         end if;
      end loop;
      if Dot = 0 or else Dot = Name'Last then
         return "";
      end if;
      return Ada.Characters.Handling.To_Lower (Name (Dot + 1 .. Name'Last));
   end Extension_Of;

   --  Collect every .ads/.adb proof input under Dir into Paths.
   --  @param Dir  Directory to walk.
   --  @param Paths  Accumulator of absolute file paths.
   procedure Collect (Dir : String; Paths : in out Path_Vectors.Vector) is
      use Ada.Directories;
      Search : Search_Type;
      Ent    : Directory_Entry_Type;
      Opened : Boolean := False;
   begin
      if not Exists (Dir) or else Kind (Dir) /= Directory then
         return;
      end if;
      Start_Search (Search, Dir, "");
      Opened := True;
      while More_Entries (Search) loop
         Get_Next_Entry (Search, Ent);
         declare
            Nm : constant String := Simple_Name (Ent);
            K  : constant File_Kind := Kind (Ent);
         begin
            if K = Directory then
               if Nm /= "." and then Nm /= ".." and then not Skip_Dir (Nm) then
                  Collect (Full_Name (Ent), Paths);
               end if;
            elsif K = Ordinary_File then
               declare
                  Ext : constant String := Extension_Of (Nm);
               begin
                  if (Ext = "ads" or else Ext = "adb")
                    and then Adacovex.Prove.Is_Proof_Input (Nm)
                  then
                     Paths.Append (To_Unbounded_String (Full_Name (Ent)));
                  end if;
               end;
            end if;
         end;
      end loop;
      End_Search (Search);
   exception
      when others =>
         if Opened then
            End_Search (Search);
         end if;
   end Collect;

   --  The base stem of a unit file: the simple name without its extension,
   --  lower-cased ("A-B.ads" becomes "a-b").
   --  @param Path  Unit file path.
   --  @return Lower-case stem.
   function Stem_Of (Path : String) return String is
      Nm  : constant String := Ada.Directories.Simple_Name (Path);
      Ext : constant String := Extension_Of (Nm);
      Cut : Natural := Nm'Last;
   begin
      if Ext'Length > 0 then
         Cut := Nm'Last - Ext'Length - 1;
      end if;
      if Cut < Nm'First then
         return "";
      end if;
      return Ada.Characters.Handling.To_Lower (Nm (Nm'First .. Cut));
   end Stem_Of;

   --  Add a unit to the stem map, preferring a spec over a body for a stem
   --  both files share.
   --  @param Map  Stem map.
   --  @param Path  Unit file path.
   procedure Add_Stem (Map : in out Stem_Vectors.Vector; Path : String) is
      Stem : constant String := Stem_Of (Path);
      Spec : constant Boolean := Extension_Of (Path) = "ads";
   begin
      if Stem'Length = 0 then
         return;
      end if;
      for I in 1 .. Integer (Map.Length) loop
         if To_String (Map (I).Stem) = Stem then
            if Spec then
               Map (I).Path := To_Unbounded_String (Path);
            end if;
            return;
         end if;
      end loop;
      Map.Append
        ((Stem => To_Unbounded_String (Stem),
          Path => To_Unbounded_String (Path)));
   end Add_Stem;

   --  The path of a local unit named by a `with` clause, or "" when the
   --  name resolves outside the project.
   --  @param Map  Stem map built from the enumerated units.
   --  @param Name  Lower-case unit name with '.' separators.
   --  @return The local unit path, or "".
   function Stem_To_Path
     (Map : Stem_Vectors.Vector; Name : String) return String
   is
      Buf : String (1 .. Name'Length);
   begin
      for I in Name'Range loop
         if Name (I) = '.' then
            Buf (I - Name'First + 1) := '-';
         else
            Buf (I - Name'First + 1) :=
              Ada.Characters.Handling.To_Lower (Name (I));
         end if;
      end loop;
      for I in 1 .. Integer (Map.Length) loop
         if To_String (Map (I).Stem) = Buf then
            return To_String (Map (I).Path);
         end if;
      end loop;
      return "";
   end Stem_To_Path;

   --  Whether a `with` name is a language- or runtime-provided unit that
   --  cannot resolve to a project file.
   --  @param Name  Lower-case unit name.
   --  @return True for a predefined name.
   function Is_Predefined (Name : String) return Boolean is
   begin
      return
        Name = "ada"
        or else Name = "gnat"
        or else Name = "system"
        or else Name = "interfaces"
        or else Name = "gnarl"
        or else (Name'Length > 4
                 and then (Name (Name'First .. Name'First + 3) = "ada."
                           or else Name (Name'First .. Name'First + 3)
                                   = "gnat"))
        or else (Name'Length > 7
                 and then Name (Name'First .. Name'First + 6) = "system.")
        or else (Name'Length > 11
                 and then Name (Name'First .. Name'First + 10)
                          = "interfaces.");
   end Is_Predefined;

   --  The unit names a source file's `with` clauses name. A line is read
   --  from its first non-comment content; `limited with` and `private with`
   --  are accepted as `with`. Names are lower-cased and kept with their '.'
   --  separators.
   --  @param Path  Source file to read.
   --  @return The names named by the file's with clauses.
   function With_Names (Path : String) return Name_Vectors.Vector is
      Result : Name_Vectors.Vector;
      F      : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (F) loop
         declare
            Raw   : constant String := Ada.Text_IO.Get_Line (F);
            Line  : String := Trim (Raw, Ada.Strings.Both);
            Cut   : constant Natural := Index (Line, "--");
            Low   : String (1 .. Line'Length);
            Start : Natural := 0;
         begin
            if Cut > 0 then
               Line := Trim (Line (Line'First .. Cut - 1), Ada.Strings.Both);
            end if;
            if Line'Length > 0 then
               for I in Line'Range loop
                  Low (I - Line'First + 1) :=
                    Ada.Characters.Handling.To_Lower (Line (I));
               end loop;
               declare
                  L : constant String := Low (1 .. Line'Length);
               begin
                  if L'Length > 13
                    and then (L (L'First .. L'First + 12) = "limited with "
                              or else L (L'First .. L'First + 12)
                                      = "private with ")
                  then
                     Start := L'First + 13;
                  elsif L'Length > 5
                    and then L (L'First .. L'First + 4) = "with "
                  then
                     Start := L'First + 5;
                  end if;
               end;
               if Start > 0 then
                  declare
                     Name_Start : Natural := Start;
                  begin
                     for I in Start .. Line'Last + 1 loop
                        if I > Line'Last
                          or else Line (I) = ','
                          or else Line (I) = ';'
                        then
                           if Name_Start <= I - 1 then
                              declare
                                 Nm : constant String :=
                                   Trim
                                     (Low
                                        (Name_Start
                                         - Line'First
                                         + 1
                                         .. I - Line'First),
                                      Ada.Strings.Both);
                              begin
                                 if Nm'Length > 0
                                   and then not Is_Predefined (Nm)
                                 then
                                    Result.Append (To_Unbounded_String (Nm));
                                 end if;
                              end;
                           end if;
                           Name_Start := I + 1;
                           exit when I > Line'Last;
                        end if;
                     end loop;
                  end;
               end if;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (F);
      return Result;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (F) then
            Ada.Text_IO.Close (F);
         end if;
         return Result;
   end With_Names;

   --  Content hash of a unit and its local `with` closure. A repeated path
   --  (a cycle, or a diamond) contributes once. Recursion is capped so a
   --  pathological `with` graph cannot exhaust the stack.
   --  @param Path  Unit file path.
   --  @param Map  Stem map of the project's units.
   --  @param Depth  Recursion depth.
   --  @param Seen  Paths already folded into the digest.
   --  @return Combined content digest.
   function Closure_Hash
     (Path  : String;
      Map   : Stem_Vectors.Vector;
      Depth : Natural;
      Seen  : in out Name_Vectors.Vector) return String
   is
      Resolved : constant String := Adacovex.Paths.Resolve (Path);
      Acc      : Unbounded_String;
   begin
      if Depth > 16 then
         return "";
      end if;
      for I in 1 .. Integer (Seen.Length) loop
         if To_String (Seen (I)) = Resolved then
            return "";
         end if;
      end loop;
      Seen.Append (To_Unbounded_String (Resolved));
      Acc := To_Unbounded_String (Adacovex.Cache.Hash_File (Path));
      declare
         Names : constant Name_Vectors.Vector := With_Names (Path);
      begin
         for I in 1 .. Integer (Names.Length) loop
            declare
               Dep : constant String :=
                 Stem_To_Path (Map, To_String (Names (I)));
            begin
               if Dep'Length > 0 then
                  Acc :=
                    To_Unbounded_String
                      (To_String (Acc)
                       & Closure_Hash (Dep, Map, Depth + 1, Seen));
               end if;
            end;
         end loop;
      end;
      return To_String (Acc);
   end Closure_Hash;

   procedure Enumerate
     (Target_Dir : String;
      Options    : String;
      Prover_Id  : String;
      Units      : out Unit_Vectors.Vector)
   is
      Root  : constant String :=
        Adacovex.Paths.Resolve
          (Adacovex.Paths.Strip_Trailing_Separators (Target_Dir));
      Paths : Path_Vectors.Vector;
      Map   : Stem_Vectors.Vector;
   begin
      Units.Clear;
      if Root'Length = 0 then
         return;
      end if;
      Collect (Root, Paths);
      for I in 1 .. Integer (Paths.Length) loop
         Add_Stem (Map, To_String (Paths (I)));
      end loop;
      for I in 1 .. Integer (Paths.Length) loop
         declare
            Path : constant String :=
              Adacovex.Paths.Resolve (To_String (Paths (I)));
            Seen : Name_Vectors.Vector;
            Key  : constant String :=
              "proveunit:"
              & Adacovex.Cache.Hash_String
                  (Path
                   & ASCII.NUL
                   & Adacovex.Cache.Hash_File (Path)
                   & ASCII.NUL
                   & Options
                   & ASCII.NUL
                   & Prover_Id
                   & ASCII.NUL
                   & Closure_Hash (Path, Map, 0, Seen));
         begin
            Units.Append
              ((Path => To_Unbounded_String (Path),
                Key  => To_Unbounded_String (Key)));
         end;
      end loop;
   end Enumerate;

   procedure Count_Hits (Units : Unit_Vectors.Vector; Hits : out Natural) is
   begin
      Hits := 0;
      for I in 1 .. Integer (Units.Length) loop
         if Adacovex.Cache.Exists (To_String (Units (I).Key)) then
            Hits := Hits + 1;
         end if;
      end loop;
   end Count_Hits;

   procedure Store (Units : Unit_Vectors.Vector; Stored : out Natural) is
      OK : Boolean;
   begin
      Stored := 0;
      for I in 1 .. Integer (Units.Length) loop
         Adacovex.Cache.Store (To_String (Units (I).Key), "1", OK);
         if OK then
            Stored := Stored + 1;
         end if;
      end loop;
   end Store;

end Adacovex.Prove_Units;
