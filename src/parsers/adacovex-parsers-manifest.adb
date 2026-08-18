with Ada.Text_IO;
with Ada.Directories;
with Ada.Containers.Vectors;
with Ada.Strings.Fixed;
with GNAT.OS_Lib; use GNAT.OS_Lib;
with Adacovex.Cache;

package body Adacovex.Parsers.Manifest is

   use type Types.Component_Kind;
   use type Types.Component_Scope;

   --  Small local name list used to collect GPR with-clause dependencies.
   type Name_Item is record
      Name : Types.Desc_Field;
      Len  : Natural := 0;
   end record;

   package Name_Vectors is new Ada.Containers.Vectors (Positive, Name_Item);

   --  Small local path list used to collect .gpr files in the project tree.
   type Path_Item is record
      Path : Types.Path_Field;
      Len  : Natural := 0;
   end record;

   package Path_Vectors is new Ada.Containers.Vectors (Positive, Path_Item);

   --  Crate-name sets collected from the publishing manifest (alire.toml or
   --  the --manifest override) and the dev manifest (alire-dev.toml).  Used
   --  to classify every resolved dependency into a Component_Scope.
   Base_Names : Name_Vectors.Vector;
   Dev_Names  : Name_Vectors.Vector;

   --  On-disk serialization for the resolved dependency graph, so an
   --  unchanged manifest/lockfile/.gpr set is served from the result cache
   --  without re-parsing (HLR-SBOM: dependency-graph caching).
   package Graph_Store is new
     Adacovex.Cache.Serialization
       (Types.Implementation.Component_Vectors.Vector);

   procedure Set_Field
     (Field : out Types.Desc_Field; Len : out Natural; S : String) is
   begin
      Len := S'Length;
      if Len > Types.Max_Desc_Str then
         Len := Types.Max_Desc_Str;
      end if;
      for I in 1 .. Len loop
         Field (I) := S (S'First + I - 1);
      end loop;
   end Set_Field;

   procedure Set_Path
     (Field : out Types.Path_Field; Len : out Natural; S : String) is
   begin
      Len := S'Length;
      if Len > Types.Max_Path then
         Len := Types.Max_Path;
      end if;
      for I in 1 .. Len loop
         Field (I) := S (S'First + I - 1);
      end loop;
   end Set_Path;

   function Trim (S : String) return String
   with
     SPARK_Mode => On,
     Pre        => S'First >= 1 and S'Last < Natural'Last and S'Last >= 0
   is
      F, L : Natural;
   begin
      F := S'First;
      L := S'Last;
      while F <= L and then S (F) = ' ' loop
         pragma Loop_Invariant (F in S'First .. S'Last + 1);
         pragma Loop_Variant (Increases => F);
         F := F + 1;
      end loop;
      while L >= F and then S (L) = ' ' loop
         pragma Loop_Invariant (L in S'First .. S'Last);
         pragma Loop_Variant (Decreases => L);
         L := L - 1;
      end loop;
      if L < F then
         return "";
      end if;
      return S (F .. L);
   end Trim;

   --  Whether S begins with the exact character sequence Pre.  The
   --  precondition gives the function a contract so gnatprove analyzes it as
   --  a unit instead of re-proving the body at every call site.
   function Starts_With (S : String; Pre : String) return Boolean
   with SPARK_Mode => On, Pre => S'First >= 1 and S'Last < Natural'Last
   is
   begin
      if Pre'Length > S'Length then
         return False;
      end if;
      return S (S'First .. S'First + Pre'Length - 1) = Pre;
   end Starts_With;

   --  Extract the quoted value of "Key = "value"" from a line of TOML.
   --  Returns "" when the key is not present or not a quoted string.
   function Key_Value (Line : String; Key : String) return String is
      Eq : Natural := 0;
   begin
      for I in Line'Range loop
         if Line (I) = '=' then
            Eq := I;
            exit;
         end if;
      end loop;
      if Eq = 0 then
         return "";
      end if;
      if Trim (Line (Line'First .. Eq - 1)) /= Key then
         return "";
      end if;
      for I in Eq + 1 .. Line'Last loop
         if Line (I) = '"' then
            for J in I + 1 .. Line'Last loop
               if Line (J) = '"' then
                  return Line (I + 1 .. J - 1);
               end if;
            end loop;
            exit;
         end if;
      end loop;
      return "";
   end Key_Value;

   --  Extract the first quoted string inside "Key = ["list"]" (project-files).
   function First_List_Value (Line : String; Key : String) return String is
      Eq  : Natural := 0;
      Lhs : Natural := 0;
   begin
      for I in Line'Range loop
         if Line (I) = '=' then
            Eq := I;
            exit;
         end if;
      end loop;
      if Eq = 0 then
         return "";
      end if;
      Lhs := Eq - 1;
      while Lhs >= Line'First and then Line (Lhs) = ' ' loop
         Lhs := Lhs - 1;
      end loop;
      if Lhs < Line'First
        or else Lhs - Line'First + 1 /= Key'Length
        or else Line (Line'First .. Lhs) /= Key
      then
         return "";
      end if;
      for I in Eq + 1 .. Line'Last loop
         if Line (I) = '"' then
            for J in I + 1 .. Line'Last loop
               if Line (J) = '"' then
                  return Line (I + 1 .. J - 1);
               end if;
            end loop;
            exit;
         end if;
      end loop;
      return "";
   end First_List_Value;

   --  Read root-project metadata from an Alire manifest (alire.toml / dev).
   procedure Read_Manifest
     (Manifest_Path    : String;
      Root_Name        : out Types.Desc_Field;
      Root_Name_Len    : out Natural;
      Root_Version     : out Types.Desc_Field;
      Root_Version_Len : out Natural;
      Root_License     : out Types.Desc_Field;
      Root_License_Len : out Natural;
      Root_Desc        : out Types.Path_Field;
      Root_Desc_Len    : out Natural;
      Project_File     : out Types.Path_Field;
      Project_File_Len : out Natural;
      Success          : out Boolean)
   is
      use Ada.Text_IO;
      F        : File_Type;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Overflow : Boolean;
      Line_Num : Natural := 0;
   begin
      Root_Name_Len := 0;
      Root_Version_Len := 0;
      Root_License_Len := 0;
      Root_Desc_Len := 0;
      Project_File_Len := 0;
      Success := False;

      begin
         Open (F, In_File, Manifest_Path);
      exception
         when others =>
            return;
      end;

      while not End_Of_File (F) loop
         Line_Num := Line_Num + 1;
         Adacovex.Parsers.Read_Line
           (F, Manifest_Path, Line_Num, Line, Last, Overflow);
         if Overflow then
            --  A physical line longer than Max_Line is drained and reported
            --  by Read_Line; the manifest is not resolved so no partial
            --  dependency graph is produced.
            Close (F);
            return;
         end if;
         declare
            T : constant String := Trim (Line (1 .. Last));
         begin
            if Root_Name_Len = 0 then
               declare
                  V : constant String := Key_Value (T, "name");
               begin
                  if V'Length > 0 then
                     Set_Field (Root_Name, Root_Name_Len, V);
                  end if;
               end;
            end if;
            if Root_Version_Len = 0 then
               declare
                  V : constant String := Key_Value (T, "version");
               begin
                  if V'Length > 0 then
                     Set_Field (Root_Version, Root_Version_Len, V);
                  end if;
               end;
            end if;
            if Root_License_Len = 0 then
               declare
                  V : constant String := Key_Value (T, "licenses");
               begin
                  if V'Length > 0 then
                     Set_Field (Root_License, Root_License_Len, V);
                  end if;
               end;
            end if;
            if Root_Desc_Len = 0 then
               declare
                  V : constant String := Key_Value (T, "description");
               begin
                  if V'Length > 0 then
                     Set_Path (Root_Desc, Root_Desc_Len, V);
                  end if;
               end;
            end if;
            if Project_File_Len = 0 then
               declare
                  V : constant String := First_List_Value (T, "project-files");
               begin
                  if V'Length > 0 then
                     Set_Path (Project_File, Project_File_Len, V);
                  end if;
               end;
            end if;
         end;
      end loop;

      Close (F);
      Success := Root_Name_Len > 0;
   end Read_Manifest;

   --  Parse a GNAT project file: extract the project name and with clauses.
   procedure Parse_GPR
     (GPR_Path  : String;
      Proj_Name : out Types.Desc_Field;
      Proj_Len  : out Natural;
      Deps      : in out Name_Vectors.Vector)
   is
      use Ada.Text_IO;
      F            : File_Type;
      Line         : String (1 .. Types.Max_Line);
      Last         : Natural;
      Overflow     : Boolean;
      Line_Num     : Natural := 0;
      With_Pending : Boolean := False;

      procedure Add_Name (S : String) is
         Item : Name_Item;
         Name : String := Trim (S);
      begin
         --  Strip a trailing ".gpr" extension.
         if Name'Length > 4 and then Name (Name'Last - 3 .. Name'Last) = ".gpr"
         then
            Name := Name (Name'First .. Name'Last - 4);
         end if;
         if Name'Length = 0 then
            return;
         end if;
         --  Skip duplicates.
         for I in 1 .. Integer (Deps.Length) loop
            if Deps (I).Len = Name'Length
              and then Deps (I).Name (1 .. Name'Length) = Name
            then
               return;
            end if;
         end loop;
         Item.Len := Name'Length;
         for I in 1 .. Name'Length loop
            Item.Name (I) := Name (Name'First + I - 1);
         end loop;
         Deps.Append (Item);
      end Add_Name;

      procedure Extract_Quoted (T : String) is
         In_Q  : Boolean := False;
         Start : Natural := 0;
      begin
         for I in T'Range loop
            if T (I) = '"' then
               if not In_Q then
                  In_Q := True;
                  Start := I + 1;
               else
                  Add_Name (T (Start .. I - 1));
                  In_Q := False;
               end if;
            end if;
         end loop;
      end Extract_Quoted;

      function Has_Semicolon (T : String) return Boolean is
      begin
         for I in T'Range loop
            if T (I) = ';' then
               return True;
            end if;
         end loop;
         return False;
      end Has_Semicolon;

   begin
      Proj_Len := 0;

      begin
         Open (F, In_File, GPR_Path);
      exception
         when others =>
            return;
      end;

      while not End_Of_File (F) loop
         Line_Num := Line_Num + 1;
         Adacovex.Parsers.Read_Line
           (F, GPR_Path, Line_Num, Line, Last, Overflow);
         if Overflow then
            --  A physical line longer than Max_Line is drained and reported
            --  by Read_Line; the .gpr is not resolved so no partial
            --  dependency graph is produced.
            Close (F);
            return;
         end if;
         declare
            T : constant String := Trim (Line (1 .. Last));
         begin
            if Proj_Len = 0 and then Starts_With (T, "project ") then
               declare
                  Name_Start : constant Natural := T'First + 8;
                  I          : Natural := Name_Start;
               begin
                  while I <= T'Last and then T (I) not in ' ' | ':' | '(' loop
                     I := I + 1;
                  end loop;
                  if I > Name_Start then
                     Set_Field (Proj_Name, Proj_Len, T (Name_Start .. I - 1));
                  end if;
               end;
            end if;

            if Starts_With (T, "with ") then
               Extract_Quoted (T);
               With_Pending := not Has_Semicolon (T);
            elsif With_Pending then
               Extract_Quoted (T);
               With_Pending := not Has_Semicolon (T);
            end if;
         end;
      end loop;

      Close (F);
   end Parse_GPR;

   --  Collect every .gpr file under Target_Dir (excluding obj, alire, etc.).
   procedure Collect_GPR_Files
     (Target_Dir : String; Files : in out Path_Vectors.Vector)
   is
      use Ada.Directories;
      type Dir_Entry is record
         Path : Types.Path_Field;
         Len  : Natural := 0;
      end record;
      package Dir_Stacks is new Ada.Containers.Vectors (Positive, Dir_Entry);
      Dir_Stack : Dir_Stacks.Vector;
      Search    : Search_Type;
      Ent       : Directory_Entry_Type;

      procedure Push_Dir (Dir : String) is
         Item : Dir_Entry;
      begin
         if Dir'Length <= Types.Max_Path then
            Item.Len := Dir'Length;
            for I in Dir'Range loop
               Item.Path (I - Dir'First + 1) := Dir (I);
            end loop;
            Dir_Stack.Append (Item);
         end if;
      end Push_Dir;
   begin
      Push_Dir (Target_Dir);

      while not Dir_Stack.Is_Empty loop
         declare
            Current  : Dir_Entry := Dir_Stack.Last_Element;
            Dir_Path : String renames Current.Path (1 .. Current.Len);
         begin
            Dir_Stack.Delete_Last;

            Start_Search (Search, Dir_Path, "");
            begin
               while More_Entries (Search) loop
                  Get_Next_Entry (Search, Ent);
                  declare
                     Name : constant String := Simple_Name (Ent);
                     Path : constant String := Full_Name (Ent);
                     Dot  : Natural := 0;
                  begin
                     if Kind (Ent) = Directory then
                        if Name /= "."
                          and Name /= ".."
                          and Name /= ".git"
                          and Name /= "obj"
                          and Name /= "tests"
                          and Name /= "config"
                          and Name /= ".adacovex"
                          and Name /= "alire"
                        then
                           Push_Dir (Path);
                        end if;
                     elsif Kind (Ent) = Ordinary_File then
                        for I in reverse Name'Range loop
                           if Name (I) = '.' then
                              Dot := I;
                              exit;
                           end if;
                        end loop;
                        if Dot > 0 and then Name (Dot .. Name'Last) = ".gpr"
                        then
                           declare
                              Item : Path_Item;
                           begin
                              Item.Len := Path'Length;
                              for I in Path'Range loop
                                 Item.Path (I - Path'First + 1) := Path (I);
                              end loop;
                              Files.Append (Item);
                           end;
                        end if;
                     end if;
                  end;
               end loop;
            exception
               when others =>
                  End_Search (Search);
                  raise;
            end;
            End_Search (Search);
         end;
      end loop;
   end Collect_GPR_Files;

   --  Locate the .gpr file for a crate name within the collected files.
   procedure Find_GPR
     (Files : Path_Vectors.Vector;
      Crate : String;
      Path  : out Types.Path_Field;
      Len   : out Natural) is
   begin
      Len := 0;
      if Crate'Length = 0 then
         return;
      end if;
      for I in 1 .. Integer (Files.Length) loop
         declare
            P    : String renames Files (I).Path (1 .. Files (I).Len);
            Base : constant String := Ada.Directories.Simple_Name (P);
            Dot  : Natural := 0;
         begin
            for J in reverse Base'Range loop
               if Base (J) = '.' then
                  Dot := J;
                  exit;
               end if;
            end loop;
            if Dot > 0 and then Base (Base'First .. Dot - 1) = Crate then
               Len := Files (I).Len;
               for J in 1 .. Len loop
                  Path (J) := Files (I).Path (J);
               end loop;
               return;
            end if;
         end;
      end loop;
   end Find_GPR;

   function Name_In_Graph
     (Graph : Types.Implementation.Component_Vectors.Vector; Name : String)
      return Boolean is
   begin
      for I in 1 .. Integer (Graph.Length) loop
         if Graph (I).Name_Len = Name'Length
           and then Graph (I).Name (1 .. Name'Length) = Name
         then
            return True;
         end if;
      end loop;
      return False;
   end Name_In_Graph;

   --  Append a crate name to a name vector unless already present.
   procedure Add_Dep_Name (Names : in out Name_Vectors.Vector; Name : String)
   is
      Item : Name_Item;
   begin
      if Name'Length = 0 then
         return;
      end if;
      for I in 1 .. Integer (Names.Length) loop
         if Names (I).Len = Name'Length
           and then Names (I).Name (1 .. Name'Length) = Name
         then
            return;
         end if;
      end loop;
      Item.Len := Name'Length;
      for I in 1 .. Name'Length loop
         Item.Name (I) := Name (Name'First + I - 1);
      end loop;
      Names.Append (Item);
   end Add_Dep_Name;

   --  Collect the crate names declared in a manifest's [[depends-on]] (or
   --  [depends-on]) section.  Missing files are ignored; a physical line
   --  longer than Max_Line clears the collected names (no partial set).
   procedure Read_Manifest_Deps
     (Path : String; Names : in out Name_Vectors.Vector)
   is
      use Ada.Text_IO;
      F          : File_Type;
      Line       : String (1 .. Types.Max_Line);
      Last       : Natural;
      Overflow   : Boolean;
      Line_Num   : Natural := 0;
      In_Depends : Boolean := False;
   begin
      Names.Clear;

      if not Ada.Directories.Exists (Path) then
         return;
      end if;
      begin
         Open (F, In_File, Path);
      exception
         when others =>
            return;
      end;

      while not End_Of_File (F) loop
         Line_Num := Line_Num + 1;
         Adacovex.Parsers.Read_Line (F, Path, Line_Num, Line, Last, Overflow);
         if Overflow then
            --  No partial dev-dependency set: classification falls back to
            --  base/transitive only.
            Names.Clear;
            Close (F);
            return;
         end if;
         declare
            T : constant String := Trim (Line (1 .. Last));
         begin
            if T'Length > 2
              and then T (T'First) = '['
              and then T (T'Last) = ']'
            then
               declare
                  Sec : constant String := T (T'First + 1 .. T'Last - 1);
               begin
                  In_Depends :=
                    Trim (Sec) = "depends-on"
                    or else (Sec'Length > 1
                             and then Sec (Sec'First) = '['
                             and then Sec (Sec'Last) = ']'
                             and then Trim
                                        (Sec (Sec'First + 1 .. Sec'Last - 1))
                                      = "depends-on");
               end;
            elsif In_Depends then
               declare
                  Eq : Natural := 0;
               begin
                  for I in T'Range loop
                     if T (I) = '=' then
                        Eq := I;
                        exit;
                     end if;
                  end loop;
                  if Eq > T'First then
                     Add_Dep_Name (Names, Trim (T (T'First .. Eq - 1)));
                  end if;
               end;
            end if;
         end;
      end loop;

      Close (F);
   end Read_Manifest_Deps;

   --  Classify a dependency name into a Component_Scope from the collected
   --  manifest sets: a name in the publishing manifest is base, one declared
   --  only in the dev manifest is dev, and anything else is transitive.
   function Classify_Scope (Name : String) return Types.Component_Scope is
   begin
      for I in 1 .. Integer (Base_Names.Length) loop
         if Base_Names (I).Len = Name'Length
           and then Base_Names (I).Name (1 .. Name'Length) = Name
         then
            return Types.Scope_Base;
         end if;
      end loop;
      for I in 1 .. Integer (Dev_Names.Length) loop
         if Dev_Names (I).Len = Name'Length
           and then Dev_Names (I).Name (1 .. Name'Length) = Name
         then
            return Types.Scope_Dev;
         end if;
      end loop;
      return Types.Scope_Transitive;
   end Classify_Scope;

   procedure Append_Dependency
     (Graph    : in out Types.Implementation.Component_Vectors.Vector;
      Name     : String;
      Version  : String;
      License  : String;
      Desc     : String;
      PURL     : String;
      Parent   : Natural;
      From_GPR : Boolean;
      Scope    : Types.Component_Scope)
   is
      C : Types.Implementation.Component_Info;
   begin
      if Name'Length = 0 or else Name_In_Graph (Graph, Name) then
         return;
      end if;
      Set_Field (C.Name, C.Name_Len, Name);
      Set_Field (C.Version, C.Version_Len, Version);
      Set_Field (C.License, C.License_Len, License);
      Set_Path (C.Description, C.Description_Len, Desc);
      Set_Path (C.PURL, C.PURL_Len, PURL);
      Set_Path (C.Ref, C.Ref_Len, PURL);
      C.Kind := Types.Dependency_Component;
      C.Parent := Parent;
      C.From_GPR := From_GPR;
      C.Scope := Scope;
      Graph.Append (C);
   end Append_Dependency;

   --  Register manifest-declared dependencies that no GPR with-clause or
   --  lockfile resolved: base deps from the publishing manifest (alire.toml)
   --  and dev deps from alire-dev.toml.  Their version constraints are not
   --  solved (only the crate name is parsed), so they appear name-only with a
   --  "pkg:alire/<name>" purl, like GPR-only deps.  Already-registered names
   --  are skipped by Append_Dependency.
   procedure Register_Manifest_Deps
     (Graph      : in out Types.Implementation.Component_Vectors.Vector;
      Base_Names : Name_Vectors.Vector;
      Dev_Names  : Name_Vectors.Vector)
   is
      procedure Register
        (Names : Name_Vectors.Vector; Scope : Types.Component_Scope) is
      begin
         for I in 1 .. Integer (Names.Length) loop
            declare
               Name : constant String := Names (I).Name (1 .. Names (I).Len);
            begin
               Append_Dependency
                 (Graph,
                  Name,
                  "",
                  "",
                  "",
                  "pkg:alire/" & Name,
                  1,
                  False,
                  Scope);
            end;
         end loop;
      end Register;
   begin
      Register (Base_Names, Types.Scope_Base);
      Register (Dev_Names, Types.Scope_Dev);
   end Register_Manifest_Deps;

   procedure Read_Alire_Lock
     (Lock_Path : String;
      Graph     : in out Types.Implementation.Component_Vectors.Vector)
   is
      use Ada.Text_IO;
      F                 : File_Type;
      Line              : String (1 .. Types.Max_Line);
      Last              : Natural;
      Overflow          : Boolean;
      Line_Num          : Natural := 0;
      In_State          : Boolean := False;
      Has_Crate         : Boolean := False;
      Crate_Name        : Types.Desc_Field;
      Crate_Name_Len    : Natural := 0;
      Crate_Version     : Types.Desc_Field;
      Crate_Version_Len : Natural := 0;
      Crate_License     : Types.Desc_Field;
      Crate_License_Len : Natural := 0;
      Crate_Desc        : Types.Path_Field;
      Crate_Desc_Len    : Natural := 0;

      procedure Flush is
      begin
         if In_State and Has_Crate and Crate_Name_Len > 0 then
            declare
               V    : constant String :=
                 (if Crate_Version_Len > 0
                  then
                    Crate_Name (1 .. Crate_Name_Len)
                    & "@"
                    & Crate_Version (1 .. Crate_Version_Len)
                  else Crate_Name (1 .. Crate_Name_Len));
               PURL : constant String := "pkg:alire/" & V;
            begin
               Append_Dependency
                 (Graph,
                  Crate_Name (1 .. Crate_Name_Len),
                  (if Crate_Version_Len > 0
                   then Crate_Version (1 .. Crate_Version_Len)
                   else ""),
                  (if Crate_License_Len > 0
                   then Crate_License (1 .. Crate_License_Len)
                   else ""),
                  Crate_Desc (1 .. Crate_Desc_Len),
                  PURL,
                  1,
                  False,
                  Classify_Scope (Crate_Name (1 .. Crate_Name_Len)));
            end;
         end if;
         Crate_Name_Len := 0;
         Crate_Version_Len := 0;
         Crate_License_Len := 0;
         Crate_Desc_Len := 0;
         Has_Crate := False;
      end Flush;

      procedure Capture (T : String) is
      begin
         declare
            V : constant String := Key_Value (T, "crate");
         begin
            if V'Length > 0 then
               Set_Field (Crate_Name, Crate_Name_Len, V);
               Has_Crate := True;
            end if;
         end;
         declare
            V : constant String := Key_Value (T, "name");
         begin
            if V'Length > 0 then
               Set_Field (Crate_Name, Crate_Name_Len, V);
               Has_Crate := True;
            end if;
         end;
         declare
            V : constant String := Key_Value (T, "version");
         begin
            if V'Length > 0 then
               Set_Field (Crate_Version, Crate_Version_Len, V);
            end if;
         end;
         declare
            V : constant String := Key_Value (T, "licenses");
         begin
            if V'Length > 0 then
               Set_Field (Crate_License, Crate_License_Len, V);
            end if;
         end;
         declare
            V : constant String := Key_Value (T, "description");
         begin
            if V'Length > 0 then
               Set_Path (Crate_Desc, Crate_Desc_Len, V);
            end if;
         end;
      end Capture;

   begin
      begin
         Open (F, In_File, Lock_Path);
      exception
         when others =>
            return;
      end;

      while not End_Of_File (F) loop
         Line_Num := Line_Num + 1;
         Adacovex.Parsers.Read_Line
           (F, Lock_Path, Line_Num, Line, Last, Overflow);
         if Overflow then
            --  A physical line longer than Max_Line is drained and reported
            --  by Read_Line; the lockfile is not resolved so no partial
            --  dependency graph is produced.
            Close (F);
            return;
         end if;
         declare
            T : constant String := Trim (Line (1 .. Last));
         begin
            if T'Length = 0 then
               null;
            elsif T (T'First) = '[' then
               if Starts_With (T, "[[solution.state]]") then
                  Flush;
                  In_State := True;
               else
                  --  A nested section ([solution.state.release.X]); the
                  --  crate remains the current one until the next state.
                  null;
               end if;
            elsif In_State then
               Capture (T);
            end if;
         end;
      end loop;

      Flush;
      Close (F);
   end Read_Alire_Lock;

   --  Resolve GPR with-clause dependencies into the graph.  Deps already
   --  present in the graph are skipped.  Transitive GPR dependencies are
   --  resolved by parsing the referenced .gpr file (if it lives in the
   --  project tree), up to a bounded depth to guard against cycles.
   procedure Resolve_GPR_Deps
     (Graph     : in out Types.Implementation.Component_Vectors.Vector;
      GPR_Files : Path_Vectors.Vector;
      Deps      : Name_Vectors.Vector;
      Parent    : Natural;
      Depth     : Natural) is
   begin
      for I in 1 .. Integer (Deps.Length) loop
         declare
            Name : constant String := Deps (I).Name (1 .. Deps (I).Len);
         begin
            if not Name_In_Graph (Graph, Name) then
               declare
                  S : Types.Component_Scope := Classify_Scope (Name);
               begin
                  --  A GPR with-clause dependency of the root project is a
                  --  direct build dependency (base) unless a manifest names
                  --  it (in which case Classify_Scope already decided);
                  --  deeper with-clauses are transitive.
                  if S = Types.Scope_Transitive and then Parent = 1 then
                     S := Types.Scope_Base;
                  end if;
                  Append_Dependency
                    (Graph,
                     Name,
                     "",
                     "",
                     "",
                     "pkg:gpr/" & Name,
                     Parent,
                     True,
                     S);
               end;
               if Depth > 0 then
                  declare
                     GPR_Path : Types.Path_Field;
                     GPR_Len  : Natural := 0;
                  begin
                     Find_GPR (GPR_Files, Name, GPR_Path, GPR_Len);
                     if GPR_Len > 0 then
                        declare
                           P_Name   : Types.Desc_Field;
                           P_Len    : Natural := 0;
                           Sub_Deps : Name_Vectors.Vector;
                           C_Index  : Natural := Natural (Graph.Length);
                        begin
                           Parse_GPR
                             (GPR_Path (1 .. GPR_Len),
                              P_Name,
                              P_Len,
                              Sub_Deps);
                           Resolve_GPR_Deps
                             (Graph, GPR_Files, Sub_Deps, C_Index, Depth - 1);
                        end;
                     end if;
                  end;
               end if;
            end if;
         end;
      end loop;
   end Resolve_GPR_Deps;

   --  Add a component for every vendored package overlaid by a docstring
   --  patch under <target>/.adacovex/patches/.  Each patch file (.ads) names
   --  the vendored package (basename); such packages have no manifest entry
   --  and no .gpr of their own, so they are recorded as Scope_Vendored
   --  dependencies of the root.
   procedure Discover_Vendored_Components
     (Target_Dir : String;
      Graph      : in out Types.Implementation.Component_Vectors.Vector)
   is
      use Ada.Directories;
      type Dir_Entry is record
         Path : Types.Path_Field;
         Len  : Natural := 0;
      end record;
      package Dir_Stacks is new Ada.Containers.Vectors (Positive, Dir_Entry);
      Dir_Stack : Dir_Stacks.Vector;
      Search    : Search_Type;
      Ent       : Directory_Entry_Type;
      Root      : constant String :=
        (if Target_Dir'Length > 0 and then Target_Dir (Target_Dir'Last) = '/'
         then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
         else Target_Dir)
        & "/.adacovex/patches";

      procedure Push_Dir (Dir : String) is
         Item : Dir_Entry;
      begin
         if Dir'Length <= Types.Max_Path then
            Item.Len := Dir'Length;
            for I in Dir'Range loop
               Item.Path (I - Dir'First + 1) := Dir (I);
            end loop;
            Dir_Stack.Append (Item);
         end if;
      end Push_Dir;

      procedure Add_Vendored (Ads_Path : String) is
         Base : constant String := Simple_Name (Ads_Path);
         Dot  : Natural := 0;
      begin
         for I in reverse Base'Range loop
            if Base (I) = '.' then
               Dot := I;
               exit;
            end if;
         end loop;
         if Dot <= Base'First then
            return;
         end if;
         Append_Dependency
           (Graph,
            Base (Base'First .. Dot - 1),
            "",
            "",
            "",
            "pkg:gpr/" & Base (Base'First .. Dot - 1),
            1,
            False,
            Types.Scope_Vendored);
      end Add_Vendored;

   begin
      if not Ada.Directories.Exists (Root) then
         return;
      end if;

      Push_Dir (Root);
      while not Dir_Stack.Is_Empty loop
         declare
            Current  : Dir_Entry := Dir_Stack.Last_Element;
            Dir_Path : String renames Current.Path (1 .. Current.Len);
         begin
            Dir_Stack.Delete_Last;

            Start_Search (Search, Dir_Path, "");
            begin
               while More_Entries (Search) loop
                  Get_Next_Entry (Search, Ent);
                  declare
                     N    : constant String := Simple_Name (Ent);
                     Path : constant String := Full_Name (Ent);
                  begin
                     if Kind (Ent) = Directory then
                        if N /= "." and N /= ".." then
                           Push_Dir (Path);
                        end if;
                     elsif Kind (Ent) = Ordinary_File then
                        if N'Length > 4
                          and then N (N'Last - 3 .. N'Last) = ".ads"
                        then
                           Add_Vendored (Path);
                        end if;
                     end if;
                  end;
               end loop;
            exception
               when others =>
                  End_Search (Search);
                  raise;
            end;
            End_Search (Search);
         end;
      end loop;
   end Discover_Vendored_Components;

   --  Known system binaries that count as development dependencies.  This
   --  is the curated toolchain set a project can interact with at
   --  development time (build drivers, the GNAT/SPARK toolchain, Python
   --  tooling, VCS clients, and container/network/doc tools).  Universal
   --  coreutils (sed, grep, tar, ...) are deliberately absent: they are OS
   --  components rather than project dev dependencies and would add noise
   --  to every SBOM.
   type Tool_Entry is record
      Name : String (1 .. 16);
      Len  : Natural := 0;
      Flag : String (1 .. 16);
      FLen : Natural := 0;
   end record;

   --  Build a Tool_Entry from a string literal, so the System_Tools table
   --  stays readable.  VFlag is the version-probe flag or subcommand;
   --  every tool here accepts "--version" except fossil and git-lfs, which
   --  use the "version" subcommand.
   --  @param S  Tool name (lowercase, e.g. "python3").
   --  @param VFlag  Version-probe flag (default "--version").
   --  @return The Tool_Entry holding S.
   function Make_Tool
     (S : String; VFlag : String := "--version") return Tool_Entry
   is
      E : Tool_Entry;
   begin
      E.Len := S'Length;
      for I in 1 .. S'Length loop
         E.Name (I) := S (S'First + I - 1);
      end loop;
      E.FLen := VFlag'Length;
      for I in 1 .. VFlag'Length loop
         E.Flag (I) := VFlag (VFlag'First + I - 1);
      end loop;
      return E;
   end Make_Tool;

   System_Tools : constant array (1 .. 37) of Tool_Entry :=
     (Make_Tool ("alr"),
      Make_Tool ("make"),
      Make_Tool ("cmake"),
      Make_Tool ("ninja"),
      Make_Tool ("gprbuild"),
      Make_Tool ("gprclean"),
      Make_Tool ("gprinstall"),
      Make_Tool ("gnatmake"),
      Make_Tool ("gnatbind"),
      Make_Tool ("gnatlink"),
      Make_Tool ("gnat"),
      Make_Tool ("gnatls"),
      Make_Tool ("gnatprep"),
      Make_Tool ("gnatprove"),
      Make_Tool ("gnatdoc"),
      Make_Tool ("gnatformat"),
      Make_Tool ("gnatpp"),
      Make_Tool ("python3"),
      Make_Tool ("python"),
      Make_Tool ("pip3"),
      Make_Tool ("pip"),
      Make_Tool ("pytest"),
      Make_Tool ("rst2md"),
      Make_Tool ("git"),
      Make_Tool ("git-lfs", "version"),
      Make_Tool ("hg"),
      Make_Tool ("svn"),
      Make_Tool ("fossil", "version"),
      Make_Tool ("jj"),
      Make_Tool ("bash"),
      Make_Tool ("mandb"),
      Make_Tool ("gh"),
      Make_Tool ("docker"),
      Make_Tool ("podman"),
      Make_Tool ("curl"),
      Make_Tool ("wget"),
      Make_Tool ("pandoc"));

   --  Whether Line contains Tool as a whole word.  The match is
   --  case-sensitive and bounded by characters outside [a-z0-9_-], so
   --  "make" matches in "make build" but not in "Makefile" (capital M) or
   --  "makefile", and "python" does not match inside "python3".
   --  @param Line  Line of text to search.
   --  @param Tool  Lowercase tool name to look for.
   --  @return True when Line refers to Tool as a whole word.
   function Line_Refers_To (Line : String; Tool : String) return Boolean is
      function Is_Word_Char (C : Character) return Boolean is
      begin
         return
           (C in 'a' .. 'z')
           or else (C in '0' .. '9')
           or else C = '_'
           or else C = '-';
      end Is_Word_Char;

      function Match_At (I : Natural) return Boolean is
      begin
         if I + Tool'Length - 1 > Line'Last then
            return False;
         end if;
         if I > Line'First and then Is_Word_Char (Line (I - 1)) then
            return False;
         end if;
         if I + Tool'Length <= Line'Last
           and then Is_Word_Char (Line (I + Tool'Length))
         then
            return False;
         end if;
         for J in Tool'Range loop
            if Line (I + (J - Tool'First)) /= Tool (J) then
               return False;
            end if;
         end loop;
         return True;
      end Match_At;
   begin
      if Tool'Length = 0 or else Tool'Length > Line'Length then
         return False;
      end if;
      for I in Line'First .. Line'Last - Tool'Length + 1 loop
         if Match_At (I) then
            return True;
         end if;
      end loop;
      return False;
   end Line_Refers_To;

   --  Probe a tool's version by running "<Tool> <Flag>" and extracting the
   --  first whitespace-separated token that contains a digit from the
   --  captured output (e.g. "2.55.0" from "git version 2.55.0", "4.4.1"
   --  from "GNU Make 4.4.1").  Returns "" when the tool is missing, the
   --  probe fails, or no digit token is found -- so a tool that does not
   --  understand its version flag simply reports no version.
   --  @param Tool  Executable name (must be on PATH).
   --  @param Flag  Version-probe flag or subcommand.
   --  @return The extracted version string, or "".
   function Probe_Version (Tool : String; Flag : String) return String is
      Pid     : constant Integer := Pid_To_Integer (Current_Process_Id);
      Pid_Img : constant String := Integer'Image (Pid);
      Tmp     : constant String :=
        "/tmp/adacovex-ver-" & Pid_Img (2 .. Pid_Img'Last) & ".out";
      Buf     : String (1 .. 4096);
      BLen    : Natural := 0;
      F       : Ada.Text_IO.File_Type;
      Exe     : String_Access := Locate_Exec_On_Path (Tool);
      OK      : Boolean;
      Code    : Integer;
      Ver     : String (1 .. 40);
   begin
      if Exe = null then
         return "";
      end if;
      Spawn
        (Exe.all, (1 => new String'(Flag)), Tmp, OK, Code, Err_To_Out => True);
      Free (Exe);
      if not OK or else Code /= 0 then
         return "";
      end if;
      begin
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Tmp);
         while not Ada.Text_IO.End_Of_File (F) loop
            declare
               Line : constant String := Ada.Text_IO.Get_Line (F);
            begin
               for I in Line'Range loop
                  if BLen < Buf'Last then
                     BLen := BLen + 1;
                     Buf (BLen) := Line (I);
                  end if;
               end loop;
               --  Keep the physical line break so tokens on separate lines
               --  do not run together (e.g. "4.4.1\nBuilt for ...").
               if BLen < Buf'Last then
                  BLen := BLen + 1;
                  Buf (BLen) := ASCII.LF;
               end if;
            end;
         end loop;
         Ada.Text_IO.Close (F);
      exception
         when others =>
            if Ada.Text_IO.Is_Open (F) then
               Ada.Text_IO.Close (F);
            end if;
            return "";
      end;
      begin
         Ada.Directories.Delete_File (Tmp);
      exception
         when others =>
            null;
      end;

      --  First whitespace/newline-separated token containing a digit, with
      --  stray trailing punctuation (e.g. the ")" of "7.2.4)") trimmed.
      declare
         Last : constant Natural := Buf'First + BLen - 1;
         I    : Natural := Buf'First;

         function Is_Sep (C : Character) return Boolean is
         begin
            return C = ' ' or else C = ASCII.LF or else C = ASCII.CR;
         end Is_Sep;
      begin
         while I <= Last loop
            while I <= Last and then Is_Sep (Buf (I)) loop
               I := I + 1;
            end loop;
            declare
               Start     : constant Natural := I;
               Has_Digit : Boolean := False;
            begin
               while I <= Last and then not Is_Sep (Buf (I)) loop
                  if Buf (I) in '0' .. '9' then
                     Has_Digit := True;
                  end if;
                  I := I + 1;
               end loop;
               if Has_Digit then
                  declare
                     L : Natural := I - 1;
                  begin
                     while L > Start
                       and then Buf (L) not in 'a' .. 'z'
                       and then Buf (L) not in 'A' .. 'Z'
                       and then Buf (L) not in '0' .. '9'
                       and then Buf (L) /= '.'
                       and then Buf (L) /= '-'
                     loop
                        L := L - 1;
                     end loop;
                     if L - Start + 1 <= Ver'Last then
                        for J in 1 .. L - Start + 1 loop
                           Ver (J) := Buf (Start + J - 1);
                        end loop;
                        return Ver (1 .. L - Start + 1);
                     end if;
                  end;
               end if;
            end;
         end loop;
      end;
      return "";
   end Probe_Version;

   --  Version-probe flag for a registered tool name (the table entry's
   --  Flag), defaulting to "--version" for names not in the table.
   --  @param Name  Tool name from the System_Tools table.
   --  @return The version-probe flag or subcommand.
   function Version_Flag (Name : String) return String is
   begin
      for T in System_Tools'Range loop
         if System_Tools (T).Len = Name'Length
           and then System_Tools (T).Name (1 .. Name'Length) = Name
         then
            return System_Tools (T).Flag (1 .. System_Tools (T).FLen);
         end if;
      end loop;
      return "--version";
   end Version_Flag;

   --  Discover system-tool dev dependencies referenced by the project.
   --  Walks the project tree, reads dev-facing files (Makefile variants,
   --  shell scripts, Python tools, Alire manifests, CI workflows, GNAT
   --  project files, and Ada sources), and registers every known system
   --  tool that the files reference AND that is actually installed on PATH
   --  as a dev-scope dependency of the root.  A Makefile at the project
   --  root implies make even when no recipe spells out the driver by name.
   --  Docstrings (.md prose) are not scanned: prose is not tool
   --  interaction, and words like "make" are far too common in it.  The
   --  source file that declares the System_Tools table itself is skipped:
   --  it references every curated tool by construction, so scanning it
   --  would register every installed tool as a self-reference.
   procedure Discover_System_Dev_Deps
     (Target_Dir : String;
      Graph      : in out Types.Implementation.Component_Vectors.Vector)
   is
      use Ada.Directories;
      type Dir_Entry is record
         Path : Types.Path_Field;
         Len  : Natural := 0;
      end record;
      package Dir_Stacks is new Ada.Containers.Vectors (Positive, Dir_Entry);
      Dir_Stack : Dir_Stacks.Vector;
      Search    : Search_Type;
      Ent       : Directory_Entry_Type;

      --  Tool names the project's files reference (deduplicated).
      Referenced : Name_Vectors.Vector;

      procedure Push_Dir (Dir : String) is
         Item : Dir_Entry;
      begin
         if Dir'Length <= Types.Max_Path then
            Item.Len := Dir'Length;
            for I in Dir'Range loop
               Item.Path (I - Dir'First + 1) := Dir (I);
            end loop;
            Dir_Stack.Append (Item);
         end if;
      end Push_Dir;

      --  Whether a file should be scanned for tool references: Makefile
      --  variants by name, or dev-facing text files by extension.
      function Should_Scan (Name : String) return Boolean is
         Dot : Natural := 0;
      begin
         if Name = "makefile"
           or else Name = "Makefile"
           or else Name = "GNUmakefile"
         then
            return True;
         end if;
         for I in reverse Name'Range loop
            if Name (I) = '.' then
               Dot := I;
               exit;
            end if;
         end loop;
         if Dot = 0 then
            return False;
         end if;
         declare
            Ext : constant String := Name (Dot .. Name'Last);
         begin
            return
              Ext = ".sh"
              or else Ext = ".py"
              or else Ext = ".gpr"
              or else Ext = ".yml"
              or else Ext = ".yaml"
              or else Ext = ".toml"
              or else Ext = ".ads"
              or else Ext = ".adb";
         end;
      end Should_Scan;

      --  Record Tool as referenced by the project's files.
      procedure Note_Tool (Tool : Tool_Entry) is
      begin
         Add_Dep_Name (Referenced, Tool.Name (1 .. Tool.Len));
      end Note_Tool;

      --  Scan one file for every known system tool.
      procedure Scan_File (Path : String) is
         use Ada.Text_IO;
         F        : File_Type;
         Line     : String (1 .. Types.Max_Line);
         Last     : Natural;
         Overflow : Boolean;
         Line_Num : Natural := 0;
      begin
         begin
            Open (F, In_File, Path);
         exception
            when others =>
               return;
         end;
         while not End_Of_File (F) loop
            Line_Num := Line_Num + 1;
            Adacovex.Parsers.Read_Line
              (F, Path, Line_Num, Line, Last, Overflow);
            if Overflow then
               --  A physical line longer than Max_Line: stop scanning this
               --  file so a truncated file never yields a partial tool set.
               Close (F);
               return;
            end if;
            if Ada.Strings.Fixed.Index
                 (Line (1 .. Last), "System_Tools : constant array")
              > 0
            then
               --  This file declares the curated tool table; every entry is
               --  a literal tool name by construction, so references found
               --  here would register every installed tool regardless of
               --  whether the project actually uses it.
               Close (F);
               return;
            end if;
            for T in System_Tools'Range loop
               if Line_Refers_To
                    (Line (1 .. Last),
                     System_Tools (T).Name (1 .. System_Tools (T).Len))
               then
                  Note_Tool (System_Tools (T));
               end if;
            end loop;
         end loop;
         Close (F);
      exception
         when others =>
            if Is_Open (F) then
               Close (F);
            end if;
      end Scan_File;

      --  Whether the project root holds a Makefile variant (implies make).
      function Has_Makefile return Boolean is
      begin
         return
           Ada.Directories.Exists (Target_Dir & "/Makefile")
           or else Ada.Directories.Exists (Target_Dir & "/makefile")
           or else Ada.Directories.Exists (Target_Dir & "/GNUmakefile");
      end Has_Makefile;
   begin
      Push_Dir (Target_Dir);

      while not Dir_Stack.Is_Empty loop
         declare
            Current  : Dir_Entry := Dir_Stack.Last_Element;
            Dir_Path : String renames Current.Path (1 .. Current.Len);
         begin
            Dir_Stack.Delete_Last;

            Start_Search (Search, Dir_Path, "");
            begin
               while More_Entries (Search) loop
                  Get_Next_Entry (Search, Ent);
                  declare
                     N    : constant String := Simple_Name (Ent);
                     Path : constant String := Full_Name (Ent);
                  begin
                     if Kind (Ent) = Directory then
                        if N /= "."
                          and N /= ".."
                          and N /= ".git"
                          and N /= ".jj"
                          and N /= ".hg"
                          and N /= ".svn"
                          and N /= "obj"
                          and N /= "tests"
                          and N /= "config"
                          and N /= ".adacovex"
                          and N /= "alire"
                        then
                           Push_Dir (Path);
                        end if;
                     elsif Kind (Ent) = Ordinary_File then
                        if Should_Scan (N) then
                           Scan_File (Path);
                        end if;
                     end if;
                  end;
               end loop;
            exception
               when others =>
                  End_Search (Search);
                  raise;
            end;
            End_Search (Search);
         end;
      end loop;

      --  A Makefile at the project root implies make even when no recipe
      --  spells out the driver by name.
      if Has_Makefile then
         for T in System_Tools'Range loop
            if System_Tools (T).Len = 4
              and then System_Tools (T).Name (1 .. 4) = "make"
            then
               Note_Tool (System_Tools (T));
               exit;
            end if;
         end loop;
      end if;

      --  Register every referenced tool that is actually installed on PATH
      --  as a dev-scope dependency of the root, probing its version
      --  ("<Tool> <flag>") when possible.  Tools the project does not
      --  reference, or that are not installed, are skipped.  Append_
      --  Dependency also deduplicates against manifest/lockfile/GPR deps
      --  (e.g. gnatprove declared in alire-dev.toml), so a manifest-pinned
      --  tool never appears twice.
      for I in 1 .. Integer (Referenced.Length) loop
         declare
            Name : constant String :=
              Referenced (I).Name (1 .. Referenced (I).Len);
            Exe  : GNAT.OS_Lib.String_Access :=
              GNAT.OS_Lib.Locate_Exec_On_Path (Name);
         begin
            if Exe /= null then
               GNAT.OS_Lib.Free (Exe);
               Append_Dependency
                 (Graph,
                  Name,
                  Probe_Version (Name, Version_Flag (Name)),
                  "",
                  "System tool referenced by the project (dev dependency)",
                  "pkg:generic/" & Name,
                  1,
                  False,
                  Types.Scope_Dev);
            end if;
         end;
      end loop;
   end Discover_System_Dev_Deps;

   --  Fingerprint of the docstring-patch directory (<target>/.adacovex/
   --  patches/), which contributes vendored components to the graph: a
   --  content hash of every .ads file found there.  Adding or removing a
   --  patch changes the digest, so the cached graph is invalidated correctly.
   --  Returns "" when the directory is absent or holds no .ads files.
   --  @param Target_Dir  Project root directory.
   --  @return SHA-256 digest of the patch files, or "" when none exist.
   function Patch_Dir_Hash (Target_Dir : String) return String is
      use Ada.Directories;
      type Dir_Entry is record
         Path : Types.Path_Field;
         Len  : Natural := 0;
      end record;
      package Dir_Stacks is new Ada.Containers.Vectors (Positive, Dir_Entry);
      Dir_Stack : Dir_Stacks.Vector;
      Search    : Search_Type;
      Ent       : Directory_Entry_Type;
      Root      : constant String :=
        (if Target_Dir'Length > 0 and then Target_Dir (Target_Dir'Last) = '/'
         then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
         else Target_Dir)
        & "/.adacovex/patches";
      Comb      : String (1 .. Types.Max_Path);
      CLen      : Natural := 0;

      procedure Push_Dir (Dir : String) is
         Item : Dir_Entry;
      begin
         if Dir'Length <= Types.Max_Path then
            Item.Len := Dir'Length;
            for I in Dir'Range loop
               Item.Path (I - Dir'First + 1) := Dir (I);
            end loop;
            Dir_Stack.Append (Item);
         end if;
      end Push_Dir;

      procedure Add (S : String) is
      begin
         if S'Length > 0 and then CLen + S'Length <= Comb'Last then
            Comb (CLen + 1 .. CLen + S'Length) := S;
            CLen := CLen + S'Length;
         end if;
      end Add;
   begin
      if not Ada.Directories.Exists (Root) then
         return "";
      end if;
      Push_Dir (Root);
      while not Dir_Stack.Is_Empty loop
         declare
            Current  : Dir_Entry := Dir_Stack.Last_Element;
            Dir_Path : String renames Current.Path (1 .. Current.Len);
         begin
            Dir_Stack.Delete_Last;
            Start_Search (Search, Dir_Path, "");
            begin
               while More_Entries (Search) loop
                  Get_Next_Entry (Search, Ent);
                  declare
                     N    : constant String := Simple_Name (Ent);
                     Path : constant String := Full_Name (Ent);
                  begin
                     if Kind (Ent) = Directory then
                        if N /= "." and N /= ".." then
                           Push_Dir (Path);
                        end if;
                     elsif Kind (Ent) = Ordinary_File
                       and then N'Length > 4
                       and then N (N'Last - 3 .. N'Last) = ".ads"
                     then
                        Add (Adacovex.Cache.Hash_File (Path));
                     end if;
                  end;
               end loop;
            exception
               when others =>
                  End_Search (Search);
                  raise;
            end;
            End_Search (Search);
         end;
      end loop;
      if CLen = 0 then
         return "";
      end if;
      return Adacovex.Cache.Hash_String (Comb (1 .. CLen));
   end Patch_Dir_Hash;

   --  Combined content hash of everything that shapes the dependency graph:
   --  the publishing manifest, the dev manifest, the alire.lock, every .gpr
   --  file collected from the project tree, and the .adacovex/patches/ dir
   --  (vendored components).  Returns "" when no input could be hashed
   --  (nothing is cached in that case).
   --  @param Target_Dir  Project root directory (for alire-dev.toml,
   --    alire/alire.lock, and .adacovex/patches/, which live beside it).
   --  @param Manifest_Path  Path to the Alire manifest (may be an override).
   --  @param GPR_Files  Every .gpr file found under the target tree.
   --  @return "graph:" + SHA-256 digest, or "" when inputs are unhashable.
   function Graph_Key
     (Target_Dir    : String;
      Manifest_Path : String;
      GPR_Files     : Path_Vectors.Vector) return String
   is
      T    : constant String :=
        (if Target_Dir'Length > 1 and then Target_Dir (Target_Dir'Last) = '/'
         then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
         else Target_Dir);
      Comb : String (1 .. Types.Max_Path);
      CLen : Natural := 0;

      procedure Add (S : String) is
      begin
         if S'Length > 0 and then CLen + S'Length <= Comb'Last then
            Comb (CLen + 1 .. CLen + S'Length) := S;
            CLen := CLen + S'Length;
         end if;
      end Add;
   begin
      Add (Adacovex.Cache.Hash_File (Manifest_Path));
      Add (Adacovex.Cache.Hash_File (T & "/alire-dev.toml"));
      Add (Adacovex.Cache.Hash_File (T & "/alire/alire.lock"));
      Add (Patch_Dir_Hash (Target_Dir));
      for I in 1 .. Integer (GPR_Files.Length) loop
         Add
           (Adacovex.Cache.Hash_File
              (GPR_Files (I).Path (1 .. GPR_Files (I).Len)));
      end loop;
      if CLen = 0 then
         return "";
      end if;
      return "graph:" & Adacovex.Cache.Hash_String (Comb (1 .. CLen));
   end Graph_Key;

   procedure Build_Dependency_Graph
     (Target_Dir    : String;
      Manifest_Path : String;
      Graph         : out Types.Implementation.Component_Vectors.Vector;
      Success       : out Boolean;
      Use_Cache     : Boolean := False)
   is
      Root_Name        : Types.Desc_Field;
      Root_Name_Len    : Natural := 0;
      Root_Version     : Types.Desc_Field;
      Root_Version_Len : Natural := 0;
      Root_License     : Types.Desc_Field;
      Root_License_Len : Natural := 0;
      Root_Desc        : Types.Path_Field;
      Root_Desc_Len    : Natural := 0;
      Proj_File        : Types.Path_Field;
      Proj_File_Len    : Natural := 0;
      Manifest_OK      : Boolean := False;

      GPR_Files    : Path_Vectors.Vector;
      GPR_Name     : Types.Desc_Field;
      GPR_Name_Len : Natural := 0;
      GPR_Deps     : Name_Vectors.Vector;
      Root_GPR_Len : Natural := 0;
      Root_GPR     : Types.Path_Field;
      Root         : Types.Implementation.Component_Info;
   begin
      Graph := Types.Implementation.Component_Vectors.Empty_Vector;

      --  Reset the package-level dependency-scope sets for this resolution.
      Base_Names.Clear;
      Dev_Names.Clear;

      Read_Manifest
        (Manifest_Path,
         Root_Name,
         Root_Name_Len,
         Root_Version,
         Root_Version_Len,
         Root_License,
         Root_License_Len,
         Root_Desc,
         Root_Desc_Len,
         Proj_File,
         Proj_File_Len,
         Manifest_OK);

      --  Collect the base (publishing manifest) and dev (alire-dev.toml)
      --  dependency crate sets used to classify every resolved component.
      Read_Manifest_Deps (Manifest_Path, Base_Names);
      declare
         T : constant String :=
           (if Target_Dir'Length > 0
              and then Target_Dir (Target_Dir'Last) = '/'
            then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
            else Target_Dir);
      begin
         if T & "/alire-dev.toml" /= Manifest_Path then
            Read_Manifest_Deps (T & "/alire-dev.toml", Dev_Names);
         end if;
      end;

      Collect_GPR_Files (Target_Dir, GPR_Files);

      --  Serve a previously resolved (unchanged) graph straight from the
      --  on-disk result cache instead of re-parsing the lockfile and every
      --  .gpr file.  The directory walk above is cheap; the recursive GPR
      --  and lock parsing it saves is not.
      if Use_Cache then
         declare
            K     : constant String :=
              Graph_Key (Target_Dir, Manifest_Path, GPR_Files);
            Blob  : String (1 .. Adacovex.Cache.Max_Cache_Blob);
            Blen  : Natural;
            Found : Boolean;
         begin
            if K'Length > 0 then
               Adacovex.Cache.Get_Cached (K, Blob, Blen, Found);
               if Found
                 and then Graph_Store.Deserialize (Blob (1 .. Blen), Graph)
               then
                  Success := True;
                  return;
               end if;
            end if;
         end;
      end if;

      --  Locate the root .gpr: the manifest project-files entry if present,
      --  otherwise a .gpr whose project name matches the manifest crate name.
      if Proj_File_Len > 0 then
         declare
            Cand : constant String :=
              Target_Dir & "/" & Proj_File (1 .. Proj_File_Len);
         begin
            if Ada.Directories.Exists (Cand) then
               Root_GPR_Len := Cand'Length;
               for I in Cand'Range loop
                  Root_GPR (I - Cand'First + 1) := Cand (I);
               end loop;
            end if;
         end;
      end if;
      if Root_GPR_Len = 0 then
         if Root_Name_Len > 0 then
            Find_GPR
              (GPR_Files,
               Root_Name (1 .. Root_Name_Len),
               Root_GPR,
               Root_GPR_Len);
         end if;
      end if;

      if Root_GPR_Len > 0 then
         Parse_GPR
           (Root_GPR (1 .. Root_GPR_Len), GPR_Name, GPR_Name_Len, GPR_Deps);
      end if;

      --  Root component (index 1).  Name falls back to the GPR project name.
      if Root_Name_Len = 0 then
         if GPR_Name_Len > 0 then
            Set_Field (Root_Name, Root_Name_Len, GPR_Name (1 .. GPR_Name_Len));
         else
            Set_Field
              (Root_Name,
               Root_Name_Len,
               Ada.Directories.Simple_Name (Target_Dir));
         end if;
      end if;

      declare
         V : constant String :=
           (if Root_Version_Len > 0
            then
              Root_Name (1 .. Root_Name_Len)
              & "@"
              & Root_Version (1 .. Root_Version_Len)
            else Root_Name (1 .. Root_Name_Len));
      begin
         Set_Path (Root.PURL, Root.PURL_Len, "pkg:alire/" & V);
         Set_Path (Root.Ref, Root.Ref_Len, "pkg:alire/" & V);
      end;
      Set_Field (Root.Name, Root.Name_Len, Root_Name (1 .. Root_Name_Len));
      Set_Field
        (Root.Version, Root.Version_Len, Root_Version (1 .. Root_Version_Len));
      Set_Field
        (Root.License, Root.License_Len, Root_License (1 .. Root_License_Len));
      Set_Path
        (Root.Description,
         Root.Description_Len,
         Root_Desc (1 .. Root_Desc_Len));
      Root.Kind := Types.Root_Component;
      Root.Parent := 0;
      Graph.Append (Root);

      --  Resolve alire.lock dependencies (solved crates).
      Read_Alire_Lock (Target_Dir & "/alire/alire.lock", Graph);

      --  Resolve GPR with-clause dependencies, including transitives.
      Resolve_GPR_Deps (Graph, GPR_Files, GPR_Deps, 1, 8);

      --  Add vendored packages overlaid by .adacovex/patches/ docstring
      --  patches (e.g. a third-party copy under demo/deps) as scope=vendored
      --  dependencies of the root.
      Discover_Vendored_Components (Target_Dir, Graph);

      --  Register manifest-declared deps (base from alire.toml, dev from
      --  alire-dev.toml) that no GPR with-clause or lockfile resolved, so the
      --  SBOM captures the declared dependency set even for zero-`with`
      --  projects whose toolchain deps live only in the dev manifest.
      Register_Manifest_Deps (Graph, Base_Names, Dev_Names);

      Success := Root.Name_Len > 0;

      --  Store the freshly resolved graph for the next run (only on success,
      --  so a partial graph is never cached).
      if Use_Cache then
         declare
            K  : constant String :=
              Graph_Key (Target_Dir, Manifest_Path, GPR_Files);
            OK : Boolean;
         begin
            if K'Length > 0 then
               declare
                  S_Blob : constant String := Graph_Store.Serialize (Graph);
               begin
                  if S_Blob'Length > 0 then
                     Adacovex.Cache.Put_Cached (K, S_Blob, OK);
                  end if;
               end;
            end if;
         end;
      end if;
   end Build_Dependency_Graph;

end Adacovex.Parsers.Manifest;
