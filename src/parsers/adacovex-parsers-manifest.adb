with Ada.Text_IO;
with Ada.Directories;
with Ada.Containers.Vectors;

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

   procedure Build_Dependency_Graph
     (Target_Dir    : String;
      Manifest_Path : String;
      Graph         : out Types.Implementation.Component_Vectors.Vector;
      Success       : out Boolean)
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
   end Build_Dependency_Graph;

end Adacovex.Parsers.Manifest;
