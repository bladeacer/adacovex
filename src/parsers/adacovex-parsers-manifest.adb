with Ada.Text_IO;
with Ada.Directories;
with Ada.Containers.Vectors;
with Ada.Strings.Fixed;
with GNAT.OS_Lib; use GNAT.OS_Lib;
with Adacovex.Cache;
with Adacovex.CPUs;

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

   --  On-disk serialization for the resolved dependency graph.  An
   --  unchanged manifest/lockfile/.gpr set is then served from the result
   --  cache without re-parsing (HLR-SBOM: dependency-graph caching).
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
   --  precondition gives the function a contract.  gnatprove analyses the
   --  function as a unit.  gnatprove does not re-prove the body at every
   --  call site.
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
      Root_Website     : out Types.Path_Field;
      Root_Website_Len : out Natural;
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
      Root_Website_Len := 0;
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
            --  A physical line longer than Max_Line is drained and reported by
            --  Read_Line.  The manifest is not resolved.  No partial dependency
            --  graph is produced.
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
            if Root_Website_Len = 0 then
               declare
                  V : constant String := Key_Value (T, "website");
               begin
                  if V'Length > 0 then
                     Set_Path (Root_Website, Root_Website_Len, V);
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

   --  Collect every .gpr file under Target_Dir (excluding obj, alire, and
   --  more).
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
   --  [depends-on]) section.  Missing files are ignored.  A physical line
   --  longer than Max_Line clears the collected names.  No partial set is
   --  kept.
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
            --  No partial dev-dependency set is kept.  Classification falls
            --  back to base/transitive only.
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
   --  manifest sets.  A name in the publishing manifest is base.  A name
   --  declared only in the dev manifest is dev.  Any other name is
   --  transitive.
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
      Scope    : Types.Component_Scope;
      Language : String := "";
      Website  : String := "")
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
      Set_Path (C.Website, C.Website_Len, Website);
      Set_Field (C.Language, C.Language_Len, Language);
      C.Kind := Types.Dependency_Component;
      C.Parent := Parent;
      C.From_GPR := From_GPR;
      C.Scope := Scope;
      Graph.Append (C);
   end Append_Dependency;

   --  Run `alr show <crate>` (optionally `<crate>=<version>`) and extract
   --  the License and Website fields from its output.  Alire's local index
   --  answers without network access, so a manifest-declared Alire dep that
   --  is not in the lockfile still gets its licence and source URL.  Returns
   --  "" for a field when alr is missing, the crate is unknown, or the field
   --  is absent.  The purl stays authority-derived; the website is the
   --  source-repository link the dashboard and SBOM prefer over a guessed
   --  registry link.
   procedure Alr_Show_Crate
     (Crate      : String;
      Show_Ver   : String;
      License    : out Types.Desc_Field;
      Lic_Len    : out Natural;
      Website    : out Types.Path_Field;
      Web_Len    : out Natural;
      Version    : out Types.Desc_Field;
      Version_Ln : out Natural)
   is
      Pid     : constant Integer := Pid_To_Integer (Current_Process_Id);
      Pid_Img : constant String := Integer'Image (Pid);
      Tmp     : constant String :=
        Adacovex.CPUs.Get_Temp_Directory
        & "/adacovex-alr-"
        & Pid_Img (2 .. Pid_Img'Last)
        & ".out";
      Buf     : String (1 .. 16384);
      BLen    : Natural := 0;
      F       : Ada.Text_IO.File_Type;
      Exe     : String_Access := Locate_Exec_On_Path ("alr");
      OK      : Boolean;
      Code    : Integer;

      Args : Argument_List (1 .. 2);
      Arg  : String_Access :=
        new String'
          (Crate & (if Show_Ver'Length > 0 then "=" & Show_Ver else ""));
   begin
      Lic_Len := 0;
      Web_Len := 0;
      Version_Ln := 0;
      if Exe = null then
         return;
      end if;
      Args (1) := new String'("show");
      Args (2) := Arg;
      Spawn (Exe.all, Args, Tmp, OK, Code, Err_To_Out => True);
      Free (Exe);
      Free (Args (1));
      Free (Arg);
      --  alr may return a non-zero exit code while still printing the release
      --  metadata (for example it warns about an index refresh).  Only a
      --  spawn failure is fatal: parse whatever the local index printed.
      if not OK then
         return;
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
            return;
      end;
      begin
         Ada.Directories.Delete_File (Tmp);
      exception
         when others =>
            null;
      end;

      --  Parse "   License: <value>" and "   Website: <value>" lines.
      declare
         S : constant String := Buf (1 .. BLen);
         I : Natural := S'First;
      begin
         while I <= S'Last loop
            declare
               J : Natural := I;
            begin
               while J <= S'Last and then S (J) /= ASCII.LF loop
                  J := J + 1;
               end loop;
               declare
                  Line : constant String :=
                    (if J > S'First then S (I .. J - 1) else "");
                  T    : constant String := Trim (Line);
               begin
                  if Lic_Len = 0
                    and then T'Length > 8
                    and then T (T'First .. T'First + 7) = "License:"
                  then
                     Set_Field
                       (License, Lic_Len, Trim (T (T'First + 8 .. T'Last)));
                  elsif Web_Len = 0
                    and then T'Length > 8
                    and then T (T'First .. T'First + 7) = "Website:"
                  then
                     Set_Path
                       (Website, Web_Len, Trim (T (T'First + 8 .. T'Last)));
                  elsif Version_Ln = 0
                    and then T'Length > 8
                    and then T (T'First .. T'First + 7) = "Version:"
                  then
                     Set_Field
                       (Version, Version_Ln, Trim (T (T'First + 8 .. T'Last)));
                  end if;
               end;
               I := J + 1;
            end;
         end loop;
      end;
   end Alr_Show_Crate;

   --  Resolve a vendored dependency's licence from its package registry when
   --  the local manifest does not carry one.  The dispatch is keyed on the
   --  ecosystem (the PURL type, for example "npm", "pnpm", "cargo", "go"):
   --  each supported ecosystem names the CLI tool that reports the field,
   --  the subcommand, and the registry field to read.  A single static
   --  table drives the dispatch, so adding a language is one row rather than
   --  a new code path -- the design scales to many ecosystems by
   --  construction.  The first non-empty trimmed line (Eco_Bare) or the
   --  value after the "license:" token (Eco_Token) is the SPDX id.  Returns
   --  "" for a field when the tool is missing, the package is unknown, the
   --  field is absent, or the command fails.  Ecosystems with no portable,
   --  reliable registry query leave Tool empty and resolve to "": vendored
   --  packages that ship a licence in their own manifest never hit the
   --  network.  This is a best-effort, online fallback used only after the
   --  offline manifest read finds nothing.
   type Eco_Format is (Eco_Bare, Eco_Token);

   procedure Resolve_Ecosystem_Metadata
     (Ecosystem : String;
      Name      : String;
      License   : out Types.Desc_Field;
      Lic_Len   : out Natural)
   is
      type Eco_Query is record
         Kind   : String (1 .. 7);
         KLen   : Natural;
         Tool   : String (1 .. 8);
         TLen   : Natural;
         Sub    : String (1 .. 8);
         SLen   : Natural;
         Field  : String (1 .. 16);
         FLen   : Natural;
         Format : Eco_Format;
      end record;

      --  One row per supported ecosystem.  Tool = "" means no reliable
      --  registry CLI, so the licence stays empty (the vendored manifest
      --  scanner still reads any in-repo licence file for that ecosystem).
      Table : constant array (1 .. 4) of Eco_Query :=
        (1 =>
           (Kind   => "npm" & (4 .. 7 => ' '),
            KLen   => 3,
            Tool   => "npm" & (4 .. 8 => ' '),
            TLen   => 3,
            Sub    => "view" & (5 .. 8 => ' '),
            SLen   => 4,
            Field  => "license" & (8 .. 16 => ' '),
            FLen   => 7,
            Format => Eco_Bare),
         2 =>
           (Kind   => "pnpm" & (5 .. 7 => ' '),
            KLen   => 4,
            Tool   => "pnpm" & (5 .. 8 => ' '),
            TLen   => 4,
            Sub    => "show" & (5 .. 8 => ' '),
            SLen   => 4,
            Field  => "license" & (8 .. 16 => ' '),
            FLen   => 7,
            Format => Eco_Bare),
         3 =>
           (Kind   => "cargo" & (6 .. 7 => ' '),
            KLen   => 5,
            Tool   => "cargo" & (6 .. 8 => ' '),
            TLen   => 5,
            Sub    => "search" & (7 .. 8 => ' '),
            SLen   => 6,
            Field  => (others => ' '),
            FLen   => 0,
            Format => Eco_Token),
         4 =>
           (Kind   => "go" & (3 .. 7 => ' '),
            KLen   => 2,
            Tool   => (others => ' '),
            TLen   => 0,
            Sub    => (others => ' '),
            SLen   => 0,
            Field  => (others => ' '),
            FLen   => 0,
            Format => Eco_Bare));

      Pid     : constant Integer := Pid_To_Integer (Current_Process_Id);
      Pid_Img : constant String := Integer'Image (Pid);
      Tmp     : constant String :=
        Adacovex.CPUs.Get_Temp_Directory
        & "/adacovex-eco-"
        & Pid_Img (2 .. Pid_Img'Last)
        & ".out";
      Buf     : String (1 .. 16384);
      BLen    : Natural := 0;
      F       : Ada.Text_IO.File_Type;
      OK      : Boolean;
      Code    : Integer;
      Fmt     : Eco_Format := Eco_Bare;
      Ran     : Boolean := False;
   begin
      Lic_Len := 0;
      if Ecosystem'Length = 0 or else Name'Length = 0 then
         return;
      end if;
      for I in Table'Range loop
         if Table (I).KLen = Ecosystem'Length
           and then Table (I).Kind (1 .. Table (I).KLen) = Ecosystem
         then
            Fmt := Table (I).Format;
            if Table (I).TLen = 0 then
               return;  --  no reliable registry CLI for this ecosystem

            end if;
            declare
               Exe  : String_Access :=
                 Locate_Exec_On_Path (Table (I).Tool (1 .. Table (I).TLen));
               Args : Argument_List (1 .. 3);
            begin
               if Exe = null then
                  return;
               end if;
               Args (1) := new String'(Table (I).Sub (1 .. Table (I).SLen));
               if Table (I).FLen > 0 then
                  Args (2) := new String'(Name);
                  Args (3) :=
                    new String'(Table (I).Field (1 .. Table (I).FLen));
                  Spawn (Exe.all, Args, Tmp, OK, Code, Err_To_Out => True);
                  Free (Args (2));
                  Free (Args (3));
               else
                  Args (2) := new String'(Name);
                  Spawn
                    (Exe.all,
                     Args (1 .. 2),
                     Tmp,
                     OK,
                     Code,
                     Err_To_Out => True);
                  Free (Args (2));
               end if;
               Free (Exe);
               Free (Args (1));
            end;
            Ran := OK;
            exit;
         end if;
      end loop;
      if not Ran then
         return;
      end if;
      begin
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Tmp);
         while not Ada.Text_IO.End_Of_File (F) loop
            declare
               Line : constant String := Ada.Text_IO.Get_Line (F);
            begin
               for C in Line'Range loop
                  if BLen < Buf'Last then
                     BLen := BLen + 1;
                     Buf (BLen) := Line (C);
                  end if;
               end loop;
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
      end;
      --  Parse the captured registry output into a licence id.
      declare
         S : constant String := Buf (1 .. BLen);
         P : Natural := S'First;

         procedure Copy (A, B : Natural) is
            L : Natural := B - A + 1;
         begin
            if L > Types.Max_Desc_Str then
               L := Types.Max_Desc_Str;
            end if;
            for K in 1 .. L loop
               License (K) := S (A + K - 1);
            end loop;
            Lic_Len := L;
         end Copy;
      begin
         if Fmt = Eco_Bare then
            while P <= S'Last loop
               declare
                  Q : Natural := P;
               begin
                  while Q <= S'Last and then S (Q) /= ASCII.LF loop
                     Q := Q + 1;
                  end loop;
                  declare
                     A : Natural := P;
                     B : Natural := Q - 1;
                  begin
                     while A <= B
                       and then (S (A) = ' ' or else S (A) = ASCII.HT)
                     loop
                        A := A + 1;
                     end loop;
                     while B >= A
                       and then (S (B) = ' ' or else S (B) = ASCII.HT)
                     loop
                        B := B - 1;
                     end loop;
                     if A <= B then
                        Copy (A, B);
                        exit;
                     end if;
                  end;
                  P := Q + 1;
               end;
            end loop;
         else
            --  Eco_Token: value follows "license:" up to ')'
            while P <= S'Last loop
               if S (P) = 'l'
                 and then P + 7 <= S'Last
                 and then S (P .. P + 7) = "license:"
               then
                  declare
                     J : Natural := P + 8;
                  begin
                     while J <= S'Last and then S (J) = ' ' loop
                        J := J + 1;
                     end loop;
                     declare
                        K : Natural := J;
                     begin
                        while K <= S'Last and then S (K) /= ')' loop
                           K := K + 1;
                        end loop;
                        if K > J then
                           Copy (J, K - 1);
                        end if;
                     end;
                  end;
                  exit;
               end if;
               P := P + 1;
            end loop;
         end if;
      end;
      begin
         Ada.Directories.Delete_File (Tmp);
      exception
         when others =>
            null;
      end;
   end Resolve_Ecosystem_Metadata;

   --  Register manifest-declared dependencies that no GPR with-clause or
   --  lockfile resolved (or fill in missing metadata on entries that were).
   --  These are base deps from the publishing manifest (alire.toml) and dev
   --  deps from alire-dev.toml.  Append_Dependency adds a name-only
   --  "pkg:alire/<name>" purl when the crate is not already in the graph.
   --  For every manifest-declared crate, `alr show` supplies the licence and
   --  source repository URL from Alire's local index -- filling them onto a
   --  freshly appended entry or an existing lockfile/GPR one whose source
   --  could not otherwise be resolved.  No garbage links are produced: a
   --  URL is only ever taken from the release metadata, never guessed.
   procedure Register_Manifest_Deps
     (Graph      : in out Types.Implementation.Component_Vectors.Vector;
      Base_Names : Name_Vectors.Vector;
      Dev_Names  : Name_Vectors.Vector)
   is
      --  Fill missing licence/website/version on an existing graph entry.
      procedure Enrich_Existing
        (Name    : String;
         Lic     : Types.Desc_Field;
         Lic_Len : Natural;
         Web     : Types.Path_Field;
         Web_Len : Natural;
         Ver     : Types.Desc_Field;
         Ver_Len : Natural) is
      begin
         for I in 1 .. Integer (Graph.Length) loop
            if Graph (I).Name_Len = Name'Length
              and then Graph (I).Name (1 .. Name'Length) = Name
            then
               declare
                  C : Types.Implementation.Component_Info := Graph (I);
               begin
                  if Lic_Len > 0 and C.License_Len = 0 then
                     for J in 1 .. Lic_Len loop
                        C.License (J) := Lic (J);
                     end loop;
                     C.License_Len := Lic_Len;
                  end if;
                  if Web_Len > 0 and C.Website_Len = 0 then
                     for J in 1 .. Web_Len loop
                        C.Website (J) := Web (J);
                     end loop;
                     C.Website_Len := Web_Len;
                  end if;
                  if Ver_Len > 0 and C.Version_Len = 0 then
                     for J in 1 .. Ver_Len loop
                        C.Version (J) := Ver (J);
                     end loop;
                     C.Version_Len := Ver_Len;
                  end if;
                  Graph (I) := C;
               end;
               exit;
            end if;
         end loop;
      end Enrich_Existing;

      procedure Register
        (Names : Name_Vectors.Vector; Scope : Types.Component_Scope) is
      begin
         for I in 1 .. Integer (Names.Length) loop
            declare
               Name    : constant String :=
                 Names (I).Name (1 .. Names (I).Len);
               Lic     : Types.Desc_Field;
               Lic_Len : Natural := 0;
               Web     : Types.Path_Field;
               Web_Len : Natural := 0;
               Ver     : Types.Desc_Field;
               Ver_Len : Natural := 0;
               Lic_S   : String (1 .. Types.Max_Desc_Str);
               Lic_SL  : Natural := 0;
               Web_S   : String (1 .. Types.Max_Path);
               Web_SL  : Natural := 0;
               Ver_S   : String (1 .. Types.Max_Desc_Str);
               Ver_SL  : Natural := 0;
            begin
               --  Ask the local index for the crate's licence, version and
               --  source URL (`alr show` answers without network access).
               --  When the crate is not in the graph yet, bundle them into
               --  the new entry; otherwise patch them onto the existing one
               --  so lockfile-resolved dev deps still carry real release
               --  metadata and a real source link.
               Alr_Show_Crate
                 (Name, "", Lic, Lic_Len, Web, Web_Len, Ver, Ver_Len);
               if Lic_Len > 0 then
                  Lic_SL := Lic_Len;
                  for J in 1 .. Lic_Len loop
                     Lic_S (J) := Lic (J);
                  end loop;
               end if;
               if Web_Len > 0 then
                  Web_SL := Web_Len;
                  for J in 1 .. Web_Len loop
                     Web_S (J) := Web (J);
                  end loop;
               end if;
               if Ver_Len > 0 then
                  Ver_SL := Ver_Len;
                  for J in 1 .. Ver_Len loop
                     Ver_S (J) := Ver (J);
                  end loop;
               end if;
               if Name_In_Graph (Graph, Name) then
                  Enrich_Existing
                    (Name, Lic, Lic_Len, Web, Web_Len, Ver, Ver_Len);
               else
                  Append_Dependency
                    (Graph,
                     Name,
                     (if Ver_SL > 0 then Ver_S (1 .. Ver_SL) else ""),
                     (if Lic_SL > 0 then Lic_S (1 .. Lic_SL) else ""),
                     "",
                     "pkg:alire/" & Name,
                     1,
                     False,
                     Scope,
                     "Ada",
                     (if Web_SL > 0 then Web_S (1 .. Web_SL) else ""));
               end if;
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
      Crate_Website     : Types.Path_Field;
      Crate_Website_Len : Natural := 0;

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
                  Classify_Scope (Crate_Name (1 .. Crate_Name_Len)),
                  "Ada",
                  (if Crate_Website_Len > 0
                   then Crate_Website (1 .. Crate_Website_Len)
                   else ""));
            end;
         end if;
         Crate_Name_Len := 0;
         Crate_Version_Len := 0;
         Crate_License_Len := 0;
         Crate_Desc_Len := 0;
         Crate_Website_Len := 0;
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
         declare
            V : constant String := Key_Value (T, "website");
         begin
            if V'Length > 0 then
               Set_Path (Crate_Website, Crate_Website_Len, V);
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
                  --  direct build dependency (base).  The exception is a
                  --  dependency named in a manifest.  Classify_Scope already
                  --  decided those.  Deeper with-clauses are transitive.
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
                     S,
                     "Ada");
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

   --  Language name for a source file, derived from its extension.  The
   --  extension is the source of truth.  A .py file is Python even when a
   --  Cargo.toml sits next to it.  The manifest language only breaks ties.
   --  @param Name  File base name (for example "a.py").
   --  @return Language display name ("Python"), or "" for unknown.
   function Extension_Language (Name : String) return String is
      Dot : Natural := 0;
      Ext : String (1 .. 8) := (others => ' ');
      EL  : Natural := 0;
   begin
      for I in reverse Name'Range loop
         if Name (I) = '.' then
            Dot := I;
            exit;
         end if;
      end loop;
      if Dot = 0 or else Dot = Name'Last or else Name'Last - Dot > Ext'Last
      then
         return "";
      end if;
      EL := Name'Last - Dot;
      for I in 1 .. EL loop
         Ext (I) := Name (Dot + I);
      end loop;

      if Ext (1 .. EL) = "ads"
        or else Ext (1 .. EL) = "adb"
        or else Ext (1 .. EL) = "ada"
        or else Ext (1 .. EL) = "gpr"
      then
         return "Ada";
      elsif Ext (1 .. EL) = "js"
        or else Ext (1 .. EL) = "mjs"
        or else Ext (1 .. EL) = "cjs"
      then
         return "JavaScript";
      elsif Ext (1 .. EL) = "ts" or else Ext (1 .. EL) = "tsx" then
         return "TypeScript";
      elsif Ext (1 .. EL) = "css" then
         return "CSS";
      elsif Ext (1 .. EL) = "html" or else Ext (1 .. EL) = "htm" then
         return "HTML";
      elsif Ext (1 .. EL) = "py" then
         return "Python";
      elsif Ext (1 .. EL) = "go" then
         return "Go";
      elsif Ext (1 .. EL) = "rs" then
         return "Rust";
      elsif Ext (1 .. EL) = "c" or else Ext (1 .. EL) = "h" then
         return "C";
      elsif Ext (1 .. EL) = "cpp"
        or else Ext (1 .. EL) = "cc"
        or else Ext (1 .. EL) = "cxx"
        or else Ext (1 .. EL) = "hpp"
        or else Ext (1 .. EL) = "hh"
        or else Ext (1 .. EL) = "hxx"
      then
         return "C++";
      elsif Ext (1 .. EL) = "cs" then
         return "C#";
      elsif Ext (1 .. EL) = "java" then
         return "Java";
      elsif Ext (1 .. EL) = "rb" then
         return "Ruby";
      elsif Ext (1 .. EL) = "php" then
         return "PHP";
      elsif Ext (1 .. EL) = "swift" then
         return "Swift";
      elsif Ext (1 .. EL) = "kt" or else Ext (1 .. EL) = "kts" then
         return "Kotlin";
      elsif Ext (1 .. EL) = "scala" then
         return "Scala";
      elsif Ext (1 .. EL) = "ml" or else Ext (1 .. EL) = "mli" then
         return "OCaml";
      elsif Ext (1 .. EL) = "lua" then
         return "Lua";
      elsif Ext (1 .. EL) = "pl" then
         return "Perl";
      elsif Ext (1 .. EL) = "hs" then
         return "Haskell";
      elsif Ext (1 .. EL) = "ex" or else Ext (1 .. EL) = "exs" then
         return "Elixir";
      elsif Ext (1 .. EL) = "erl" or else Ext (1 .. EL) = "hrl" then
         return "Erlang";
      elsif Ext (1 .. EL) = "clj" or else Ext (1 .. EL) = "cljs" then
         return "Clojure";
      elsif Ext (1 .. EL) = "dart" then
         return "Dart";
      elsif Ext (1 .. EL) = "sh" or else Ext (1 .. EL) = "bash" then
         return "Shell";
      elsif Ext (1 .. EL) = "ps1" then
         return "PowerShell";
      elsif Ext (1 .. EL) = "sql" then
         return "SQL";
      elsif Ext (1 .. EL) = "f"
        or else Ext (1 .. EL) = "f90"
        or else Ext (1 .. EL) = "f95"
        or else Ext (1 .. EL) = "f03"
      then
         return "Fortran";
      elsif Ext (1 .. EL) = "s" or else Ext (1 .. EL) = "asm" then
         return "Assembly";
      elsif Ext (1 .. EL) = "r" then
         return "R";
      elsif Ext (1 .. EL) = "jl" then
         return "Julia";
      elsif Ext (1 .. EL) = "zig" then
         return "Zig";
      elsif Ext (1 .. EL) = "vhd" or else Ext (1 .. EL) = "vhdl" then
         return "VHDL";
      elsif Ext (1 .. EL) = "tcl" then
         return "Tcl";
      end if;
      return "";
   end Extension_Language;

   --  Per-language file counters used to rank a directory's languages.
   type Lang_Item is record
      Name : String (1 .. 16);
      Len  : Natural := 0;
      Ct   : Natural := 0;
   end record;
   package Lang_Vectors is new Ada.Containers.Vectors (Positive, Lang_Item);

   --  Whether a directory holding the detected language counters already
   --  contains the given language name.
   function Has_Lang (Langs : Lang_Vectors.Vector; L : String) return Boolean
   is
   begin
      for I in 1 .. Integer (Langs.Length) loop
         if Langs (I).Len = L'Length
           and then Langs (I).Name (1 .. L'Length) = L
         then
            return True;
         end if;
      end loop;
      return False;
   end Has_Lang;

   --  Whether a directory base name denotes a vendored-code directory that
   --  adacovex treats as a scope=vendored dependency source.
   --  @param N  Directory base name.
   --  @return True for vendored directory names.
   function Is_Vendor_Dir_Name (N : String) return Boolean is
   begin
      return
        N = "vendor"
        or else N = "vendored"
        or else N = "third_party"
        or else N = "third-party"
        or else N = "extern"
        or else N = "external"
        or else N = "deps"
        or else N = "submodules"
        or else N = ".vendor"
        or else N = "lib"
        or else N = "contrib"
        or else N = "node_modules";
   end Is_Vendor_Dir_Name;

   --  Whether to skip descending into a directory during a source walk:
   --  VCS metadata, the adacovex config dir, installer/build outputs, and
   --  Alire's own dependency cache never carry project source.
   function Skip_Walk_Dir (N : String) return Boolean is
   begin
      return
        N = ".git"
        or else N = ".hg"
        or else N = ".svn"
        or else N = ".adacovex"
        or else N = "alire"
        or else N = "obj"
        or else N = "bin";
   end Skip_Walk_Dir;

   --  Count the source files under Root by language, descending at most
   --  Max_Levels subdirectories (0 = Root's direct children only).  Only
   --  file names are read (no content), so this is cheap.  When Skip_Vend
   --  is True, vendored directories are not descended into -- used for the
   --  root project's own language so vendored code is never attributed to
   --  the owning project.
   procedure Detect_Languages
     (Root          : String;
      Max_Levels    : Natural;
      Langs         : in out Lang_Vectors.Vector;
      Skip_Vendored : Boolean := False)
   is
      use Ada.Directories;
      type Dir_Entry is record
         Path  : Types.Path_Field;
         Len   : Natural := 0;
         Level : Natural := 0;
      end record;
      package Dir_Stacks is new Ada.Containers.Vectors (Positive, Dir_Entry);
      Dir_Stack : Dir_Stacks.Vector;
      Search    : Search_Type;
      Ent       : Directory_Entry_Type;

      procedure Push_Dir (Dir : String; Level : Natural) is
         Item : Dir_Entry;
      begin
         if Dir'Length <= Types.Max_Path then
            Item.Len := Dir'Length;
            for I in Dir'Range loop
               Item.Path (I - Dir'First + 1) := Dir (I);
            end loop;
            Item.Level := Level;
            Dir_Stack.Append (Item);
         end if;
      end Push_Dir;

      procedure Count_File (N : String) is
         L : constant String := Extension_Language (N);
      begin
         if L'Length = 0 then
            return;
         end if;
         for I in 1 .. Integer (Langs.Length) loop
            if Langs (I).Len = L'Length
              and then Langs (I).Name (1 .. L'Length) = L
            then
               Langs (I).Ct := Langs (I).Ct + 1;
               return;
            end if;
         end loop;
         declare
            Item : Lang_Item;
         begin
            Item.Len := L'Length;
            for I in 1 .. L'Length loop
               Item.Name (I) := L (L'First + I - 1);
            end loop;
            Item.Ct := 1;
            Langs.Append (Item);
         end;
      end Count_File;
   begin
      Langs.Clear;
      Push_Dir (Root, 0);
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
                          and then N /= ".."
                          and then Current.Level < Max_Levels
                          and then not Skip_Walk_Dir (N)
                          and then (not Skip_Vendored
                                    or else not Is_Vendor_Dir_Name (N))
                        then
                           Push_Dir (Path, Current.Level + 1);
                        end if;
                     elsif Kind (Ent) = Ordinary_File then
                        Count_File (N);
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
   end Detect_Languages;

   --  Rank a detected language counter vector.  The primary language is
   --  first.  The primary language is the ecosystem manifest's language (for
   --  example Rust for Cargo.toml).  The remaining languages follow by file
   --  count descending.  Ties follow by name ascending.  Join up to 3 with
   --  " - ".  Mixed-language sources list the top ~3 languages.  This keeps
   --  "Ada; C; C++" style labels bounded.
   --  @param Langs  Detected language counters (must be sorted into rank).
   --  @param Primary  Ecosystem language, or "" to rank by file count only.
   --  @return Joined language summary (for example "Ada; C; C++").
   function Language_Summary
     (Langs : Lang_Vectors.Vector; Primary : String) return String
   is
      Vec   : Lang_Vectors.Vector := Langs;
      Buf   : String (1 .. 128);
      BLen  : Natural := 0;
      Taken : Natural := 0;
      J     : Integer := 0;
      I     : Integer := 0;

      procedure Add_One (L : String) is
      begin
         if BLen + L'Length + 2 > Buf'Last then
            return;
         end if;
         if BLen > 0 then
            Buf (BLen + 1 .. BLen + 2) := "; ";
            BLen := BLen + 2;
         end if;
         Buf (BLen + 1 .. BLen + L'Length) := L;
         BLen := BLen + L'Length;
      end Add_One;
   begin
      --  Bubble sort the counter vector (small): file count descending.
      --  Ties keep their detection order (the walk is deterministic).
      --  The primary language is added first regardless of its file count,
      --  then the remaining top languages up to 3 labels total.
      I := Integer (Vec.Length);
      while I > 1 loop
         J := 2;
         while J <= I loop
            if Vec (J).Ct > Vec (J - 1).Ct then
               declare
                  T : Lang_Item := Vec (J);
               begin
                  Vec (J) := Vec (J - 1);
                  Vec (J - 1) := T;
               end;
            end if;
            J := J + 1;
         end loop;
         I := I - 1;
      end loop;

      if Primary'Length > 0 then
         Add_One (Primary);
         Taken := 1;
      end if;
      for I in 1 .. Integer (Vec.Length) loop
         exit when Taken >= 3;
         if Primary'Length = 0
           or else Vec (I).Len /= Primary'Length
           or else Vec (I).Name (1 .. Vec (I).Len) /= Primary
         then
            Add_One (Vec (I).Name (1 .. Vec (I).Len));
            Taken := Taken + 1;
         end if;
      end loop;
      return Buf (1 .. BLen);
   end Language_Summary;

   --  Everything needed to turn a vendored directory into a graph component:
   --  ecosystem PURL kind, canonical name/version, and the ecosystem's
   --  primary language.
   type Vendor_Manifest is record
      Found            : Boolean := False;
      Name             : Types.Desc_Field;
      Name_Len         : Natural := 0;
      Version          : Types.Desc_Field;
      Version_Len      : Natural := 0;
      License          : Types.Desc_Field;
      License_Len      : Natural := 0;
      PURL_Kind        : String (1 .. 16);
      PURL_Kind_Len    : Natural := 0;
      Primary_Lang     : String (1 .. 16);
      Primary_Lang_Len : Natural := 0;
   end record;

   --  Read the first "<Key>" quoted value from a key=value or key:value
   --  file (TOML or JSON, quoted key or bare): locate Key followed by '='
   --  or ':', then the next double-quoted string.  "" when absent.
   function File_Quoted_Value (Path : String; Key : String) return String is
      use Ada.Text_IO;
      F        : File_Type;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Overflow : Boolean;
      Line_Num : Natural := 0;

      function Is_Word_Char (C : Character) return Boolean is
      begin
         return
           (C in 'a' .. 'z')
           or else (C in 'A' .. 'Z')
           or else (C in '0' .. '9')
           or else C = '_'
           or else C = '-';
      end Is_Word_Char;

      function Line_Value (T : String) return String is
         Sep : Natural := 0;
      begin
         --  Locate Key as a whole word, then find the '=' or ':' separator
         --  right after it (spaces allowed between key and separator).
         for I in T'First .. T'Last - Key'Length + 1 loop
            if T (I .. I + Key'Length - 1) = Key
              and then (I = T'First or else not Is_Word_Char (T (I - 1)))
              and then (I + Key'Length > T'Last
                        or else not Is_Word_Char (T (I + Key'Length)))
            then
               declare
                  J : Natural := I + Key'Length;
               begin
                  while J <= T'Last and then T (J) /= '=' and then T (J) /= ':'
                  loop
                     J := J + 1;
                  end loop;
                  if J <= T'Last then
                     Sep := J;
                     exit;
                  end if;
               end;
            end if;
         end loop;
         if Sep = 0 then
            return "";
         end if;
         --  Find the next quoted string after the separator.
         for Q in Sep + 1 .. T'Last loop
            if T (Q) = '"' then
               for Q2 in Q + 1 .. T'Last loop
                  if T (Q2) = '"' then
                     return T (Q + 1 .. Q2 - 1);
                  end if;
               end loop;
               return "";
            end if;
         end loop;
         return "";
      end Line_Value;
   begin
      begin
         Open (F, In_File, Path);
      exception
         when others =>
            return "";
      end;
      while not End_Of_File (F) loop
         Line_Num := Line_Num + 1;
         Adacovex.Parsers.Read_Line (F, Path, Line_Num, Line, Last, Overflow);
         if Overflow then
            Close (F);
            return "";
         end if;
         declare
            V : constant String := Line_Value (Trim (Line (1 .. Last)));
         begin
            if V'Length > 0 then
               Close (F);
               return V;
            end if;
         end;
      end loop;
      Close (F);
      return "";
   end File_Quoted_Value;

   --  Read the first "module <path>" line of a go.mod (the module path is
   --  the Go component's canonical name).
   function Go_Module_Path (Path : String) return String is
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
            return "";
      end;
      while not End_Of_File (F) loop
         Line_Num := Line_Num + 1;
         Adacovex.Parsers.Read_Line (F, Path, Line_Num, Line, Last, Overflow);
         if Overflow then
            Close (F);
            return "";
         end if;
         declare
            T : constant String := Trim (Line (1 .. Last));
         begin
            if T'Length > 7 and then T (T'First .. T'First + 6) = "module "
            then
               Close (F);
               return Trim (T (T'First + 7 .. T'Last));
            end if;
         end;
      end loop;
      Close (F);
      return "";
   end Go_Module_Path;

   --  First "gem " entry of a Gemfile: name and cleaned version.
   procedure Gem_Entry
     (Path    : String;
      Name    : out String;
      NLen    : out Natural;
      Version : out String;
      VLen    : out Natural)
   is
      use Ada.Text_IO;
      F        : File_Type;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Overflow : Boolean;
      Line_Num : Natural := 0;
      N        : String (1 .. 64) := (others => ' ');
      V        : String (1 .. 64) := (others => ' ');
   begin
      NLen := 0;
      VLen := 0;
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
            Close (F);
            return;
         end if;
         declare
            T : constant String := Trim (Line (1 .. Last));
         begin
            if T'Length > 4 and then T (T'First .. T'First + 3) = "gem " then
               --  Extract the quoted strings (name, then version).
               declare
                  Got : Natural := 0;
                  I   : Natural := T'First + 4;
               begin
                  while I <= T'Last and Got < 2 loop
                     if T (I) = '"' then
                        declare
                           J : Natural := I + 1;
                        begin
                           while J <= T'Last and then T (J) /= '"' loop
                              J := J + 1;
                           end loop;
                           if J <= T'Last then
                              Got := Got + 1;
                              if Got = 1 then
                                 NLen := J - I - 1;
                                 if NLen > 64 then
                                    NLen := 64;
                                 end if;
                                 N (1 .. NLen) := T (I + 1 .. I + NLen);
                              else
                                 VLen := J - I - 1;
                                 if VLen > 64 then
                                    VLen := 64;
                                 end if;
                                 V (1 .. VLen) := T (I + 1 .. I + VLen);
                              end if;
                              I := J;
                           end if;
                        end;
                     end if;
                     I := I + 1;
                  end loop;
               end;
               if NLen > 0 then
                  Close (F);
                  --  Trim non-version decoration from the version (for example
                  --  ">= 12" -> "12").
                  begin
                     while VLen > 0 and then V (1) not in '0' .. '9' loop
                        --  Skip "v" prefixes too but keep 'v' starts
                        V (1 .. VLen - 1) := V (2 .. VLen);
                        VLen := VLen - 1;
                     end loop;
                  end;
                  Name := N;
                  Version := V;
                  return;
               end if;
            end if;
         end;
      end loop;
      Close (F);
   end Gem_Entry;

   --  First non-comment requirement line of a requirements*.txt:
   --  "requests==2.28.1" -> name "requests", version "2.28.1".
   procedure Req_Entry
     (Path    : String;
      Name    : out String;
      NLen    : out Natural;
      Version : out String;
      VLen    : out Natural)
   is
      use Ada.Text_IO;
      F        : File_Type;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Overflow : Boolean;
      Line_Num : Natural := 0;
      N        : String (1 .. 64) := (others => ' ');
      V        : String (1 .. 64) := (others => ' ');
   begin
      NLen := 0;
      VLen := 0;
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
            Close (F);
            return;
         end if;
         declare
            T : constant String := Trim (Line (1 .. Last));
         begin
            if T'Length > 0 and then T (T'First) /= '#' then
               declare
                  Stop : Natural := T'First - 1;
                  I    : Natural := T'First;
               begin
                  while I <= T'Last
                    and then T (I) /= ' '
                    and then T (I) /= '='
                    and then T (I) /= '<'
                    and then T (I) /= '>'
                    and then T (I) /= '~'
                  loop
                     I := I + 1;
                  end loop;
                  Stop := I - 1;
                  if Stop >= T'First then
                     NLen := Stop - T'First + 1;
                     if NLen > 64 then
                        NLen := 64;
                     end if;
                     N (1 .. NLen) := T (T'First .. T'First + NLen - 1);
                     --  Skip operators and spaces, then take the version
                     --  token (up to whitespace, a comment, or end).
                     while I <= T'Last
                       and then T (I) in ' ' | '=' | '<' | '>' | '~' | '!'
                     loop
                        I := I + 1;
                     end loop;
                     begin
                        while I <= T'Last
                          and then T (I) /= ' '
                          and then T (I) /= '#'
                        loop
                           if VLen < 64 then
                              VLen := VLen + 1;
                              V (VLen) := T (I);
                           end if;
                           I := I + 1;
                        end loop;
                     end;
                     Close (F);
                     if NLen > 0 then
                        Name := N;
                        Version := V;
                        return;
                     end if;
                  end if;
               end;
            end if;
         end;
      end loop;
      Close (F);
   end Req_Entry;

   --  First <Tag>...</Tag> occurrence on a single line of an XML file
   --  (pom.xml).  Returns the inner text, "" when absent.
   function Xml_Tag_Value (Path : String; Tag : String) return String is
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
            return "";
      end;
      while not End_Of_File (F) loop
         Line_Num := Line_Num + 1;
         Adacovex.Parsers.Read_Line (F, Path, Line_Num, Line, Last, Overflow);
         if Overflow then
            Close (F);
            return "";
         end if;
         declare
            T  : constant String := Line (1 .. Last);
            O  : constant String := "<" & Tag & ">";
            C  : constant String := "</" & Tag & ">";
            OI : constant Natural := Ada.Strings.Fixed.Index (T, O);
            CI : constant Natural := Ada.Strings.Fixed.Index (T, C);
         begin
            if OI > T'First - 1 and then CI >= OI + O'Length then
               Close (F);
               return T (OI + O'Length .. CI - 1);
            end if;
         end;
      end loop;
      Close (F);
      return "";
   end Xml_Tag_Value;

   --  Probe Dir for the first recognised ecosystem manifest (in the defined
   --  priority order): package.json (npm), Cargo.toml (cargo), go.mod
   --  (golang), pyproject.toml (pypi), composer.json (composer), Gemfile
   --  (gem), pom.xml (maven), requirements*.txt (pypi), Package.swift
   --  (swift).  Name and version come from the manifest when present.  The
   --  caller falls back to the directory name or "" otherwise.
   procedure Read_Vendor_Manifest (Dir : String; Info : out Vendor_Manifest) is
      use Ada.Directories;

      procedure Set_Text
        (DST : out Types.Desc_Field; DST_Len : out Natural; S : String) is
      begin
         DST_Len := S'Length;
         if DST_Len > Types.Max_Desc_Str then
            DST_Len := Types.Max_Desc_Str;
         end if;
         for I in 1 .. DST_Len loop
            DST (I) := S (S'First + I - 1);
         end loop;
      end Set_Text;

      procedure Set_Kind (K : String) is
      begin
         if K'Length <= Info.PURL_Kind'Last then
            Info.PURL_Kind_Len := K'Length;
            Info.PURL_Kind (1 .. K'Length) := K;
         end if;
      end Set_Kind;

      procedure Set_Lang (L : String) is
      begin
         if L'Length <= Info.Primary_Lang'Last then
            Info.Primary_Lang_Len := L'Length;
            Info.Primary_Lang (1 .. L'Length) := L;
         end if;
      end Set_Lang;

      function Path (N : String) return String is
      begin
         return Dir & "/" & N;
      end Path;
   begin
      Info.Found := False;
      Info.PURL_Kind_Len := 0;
      Info.Primary_Lang_Len := 0;
      Info.Name_Len := 0;
      Info.Version_Len := 0;
      Info.License_Len := 0;

      if Exists (Path ("package.json")) then
         Set_Text
           (Info.Name,
            Info.Name_Len,
            File_Quoted_Value (Path ("package.json"), "name"));
         Set_Text
           (Info.Version,
            Info.Version_Len,
            File_Quoted_Value (Path ("package.json"), "version"));
         Set_Text
           (Info.License,
            Info.License_Len,
            File_Quoted_Value (Path ("package.json"), "license"));
         Set_Kind ("npm");
         Set_Lang ("JavaScript");
         Info.Found := True;
      elsif Exists (Path ("Cargo.toml")) then
         Set_Text
           (Info.Name,
            Info.Name_Len,
            File_Quoted_Value (Path ("Cargo.toml"), "name"));
         Set_Text
           (Info.Version,
            Info.Version_Len,
            File_Quoted_Value (Path ("Cargo.toml"), "version"));
         Set_Text
           (Info.License,
            Info.License_Len,
            File_Quoted_Value (Path ("Cargo.toml"), "license"));
         Set_Kind ("cargo");
         Set_Lang ("Rust");
         Info.Found := True;
      elsif Exists (Path ("go.mod")) then
         Set_Text (Info.Name, Info.Name_Len, Go_Module_Path (Path ("go.mod")));
         Set_Kind ("golang");
         Set_Lang ("Go");
         Info.Found := True;
      elsif Exists (Path ("pyproject.toml")) then
         Set_Text
           (Info.Name,
            Info.Name_Len,
            File_Quoted_Value (Path ("pyproject.toml"), "name"));
         Set_Text
           (Info.Version,
            Info.Version_Len,
            File_Quoted_Value (Path ("pyproject.toml"), "version"));
         Set_Text
           (Info.License,
            Info.License_Len,
            File_Quoted_Value (Path ("pyproject.toml"), "license"));
         Set_Kind ("pypi");
         Set_Lang ("Python");
         Info.Found := True;
      elsif Exists (Path ("composer.json")) then
         Set_Text
           (Info.Name,
            Info.Name_Len,
            File_Quoted_Value (Path ("composer.json"), "name"));
         Set_Text
           (Info.Version,
            Info.Version_Len,
            File_Quoted_Value (Path ("composer.json"), "version"));
         Set_Text
           (Info.License,
            Info.License_Len,
            File_Quoted_Value (Path ("composer.json"), "license"));
         Set_Kind ("composer");
         Set_Lang ("PHP");
         Info.Found := True;
      elsif Exists (Path ("Gemfile")) then
         declare
            G_N : String (1 .. 64) := (others => ' ');
            G_V : String (1 .. 64) := (others => ' ');
            N_L : Natural := 0;
            V_L : Natural := 0;
         begin
            Gem_Entry (Path ("Gemfile"), G_N, N_L, G_V, V_L);
            Set_Text (Info.Name, Info.Name_Len, G_N (1 .. N_L));
            Set_Text (Info.Version, Info.Version_Len, G_V (1 .. V_L));
         end;
         Set_Kind ("gem");
         Set_Lang ("Ruby");
         Info.Found := True;
      elsif Exists (Path ("pom.xml")) then
         declare
            A : constant String :=
              Xml_Tag_Value (Path ("pom.xml"), "artifactId");
            G : constant String := Xml_Tag_Value (Path ("pom.xml"), "groupId");
            V : constant String := Xml_Tag_Value (Path ("pom.xml"), "version");
         begin
            if G'Length > 0 then
               Set_Text (Info.Name, Info.Name_Len, G & ":" & A);
            else
               Set_Text (Info.Name, Info.Name_Len, A);
            end if;
            Set_Text (Info.Version, Info.Version_Len, V);
         end;
         Set_Kind ("maven");
         Set_Lang ("Java");
         Info.Found := True;
      elsif Exists (Path ("Package.swift")) then
         Set_Kind ("swift");
         Set_Lang ("Swift");
         Info.Found := True;
      else
         --  requirements*.txt (pick the first match).
         declare
            Search : Search_Type;
            Ent    : Directory_Entry_Type;
            Found  : Boolean := False;
         begin
            Start_Search (Search, Dir, "requirements*.txt");
            while not Found and then More_Entries (Search) loop
               Get_Next_Entry (Search, Ent);
               if Kind (Ent) = Ordinary_File then
                  declare
                     R_N : String (1 .. 64) := (others => ' ');
                     R_V : String (1 .. 64) := (others => ' ');
                     N_L : Natural := 0;
                     V_L : Natural := 0;
                  begin
                     Req_Entry (Full_Name (Ent), R_N, N_L, R_V, V_L);
                     Set_Text (Info.Name, Info.Name_Len, R_N (1 .. N_L));
                     Set_Text (Info.Version, Info.Version_Len, R_V (1 .. V_L));
                     Found := True;
                  end;
               end if;
            end loop;
            End_Search (Search);
            if Found then
               Set_Kind ("pypi");
               Set_Lang ("Python");
               Info.Found := True;
            end if;
         end;
      end if;
   end Read_Vendor_Manifest;

   --  Language summary of the source files under a directory.  The primary
   --  (ecosystem) language is first when given.  The top detected languages
   --  follow by file count.  Join them with "; " (max 3 labels).
   --  @param Root  Directory tree to scan (file names only, no content).
   --  @param Max_Levels  Subdirectory depth to descend into.
   --  @param Primary_Kind  Ecosystem primary language or "".
   --  @return Language summary (for example "Ada; C; C++"), "" when nothing.
   function Language_Of_Dir
     (Root : String; Max_Levels : Natural; Primary_Kind : String := "")
      return String
   is
      Langs : Lang_Vectors.Vector;
   begin
      Detect_Languages (Root, Max_Levels, Langs);
      if Langs.Is_Empty and Primary_Kind'Length = 0 then
         return "";
      end if;
      if Primary_Kind'Length > 0 and then not Has_Lang (Langs, Primary_Kind)
      then
         --  Manifest language always leads the label even when no
         --  matching source files were counted.
         declare
            Item : Lang_Item;
         begin
            Item.Len := Primary_Kind'Length;
            for I in 1 .. Primary_Kind'Length loop
               Item.Name (I) := Primary_Kind (Primary_Kind'First + I - 1);
            end loop;
            Langs.Append (Item);
         end;
      end if;
      return Language_Summary (Langs, Primary_Kind);
   end Language_Of_Dir;

   --  Add a component for every vendored package overlaid by a docstring
   --  patch under <target>/.adacovex/patches/.  Add a component for every
   --  web asset under resources/ or assets/.  Add a component for every
   --  source file under vendor/ (the classic Alire-era vendored roots).
   --  Each file becomes a scope=vendored component named after its base
   --  name.  The language comes from the file extension.  Such packages
   --  have no manifest entry and no .gpr of their own.  They are recorded
   --  as Scope_Vendored dependencies of the root.
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
            Types.Scope_Vendored,
            "Ada");
      end Add_Vendored;

      subtype Lib_Name_Field is String (1 .. 32);
      --  Return the upstream npm package name and version for a bundled
      --  dashboard asset, or False for an unknown asset.  The dashboard
      --  vendors exactly four third-party libraries into the binary
      --  (resources/*.js|css); their versions are stable build-time
      --  constants (also listed in the Credits tab and docs/dashboard.md).
      --  adacovex's own dashboard sources match none of these and never
      --  become packages.
      function Bundled_Library
        (Raw      : String;
         Npm_Name : out Lib_Name_Field;
         NN       : out Natural;
         Lib_Ver  : out Lib_Name_Field;
         VN       : out Natural;
         Lib_Lic  : out Lib_Name_Field;
         LL       : out Natural) return Boolean
      is
         N : String (1 .. 32) := (others => ' ');
         V : String (1 .. 32) := (others => ' ');
         L : String (1 .. 32) := (others => ' ');
      begin
         if Raw = "flexsearch" then
            N (1 .. 10) := "flexsearch";
            NN := 10;
            V (1 .. 6) := "0.7.31";
            VN := 6;
            L (1 .. 10) := "Apache-2.0";
            LL := 10;
         elsif Raw = "nomnoml" then
            N (1 .. 7) := "nomnoml";
            NN := 7;
            V (1 .. 5) := "1.7.0";
            VN := 5;
            L (1 .. 3) := "MIT";
            LL := 3;
         elsif Raw = "graphre" then
            N (1 .. 7) := "graphre";
            NN := 7;
            V (1 .. 5) := "0.1.3";
            VN := 5;
            L (1 .. 3) := "MIT";
            LL := 3;
         elsif Raw = "charts.min" then
            N (1 .. 10) := "charts.css";
            NN := 10;
            V (1 .. 5) := "1.2.0";
            VN := 5;
            L (1 .. 3) := "MIT";
            LL := 3;
         else
            return False;
         end if;
         Npm_Name := N;
         Lib_Ver := V;
         Lib_Lic := L;
         return True;
      end Bundled_Library;

      procedure Add_Vendored_Asset (Asset_Path : String) is
         Base    : constant String := Simple_Name (Asset_Path);
         Dot     : Natural := 0;
         Raw     : String (1 .. 64) := (others => ' ');
         Raw_Len : Natural := 0;
         Name    : String (1 .. 64) := (others => ' ');
         NLen    : Natural := 0;
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
         Raw_Len := Dot - Base'First;
         if Raw_Len > 64 then
            Raw_Len := 64;
         end if;
         for I in 1 .. Raw_Len loop
            Raw (I) := Base (Base'First + I - 1);
         end loop;
         --  adacovex's own dashboard sources are not a package and never
         --  become SBOM components.
         if Raw_Len = 9 and then Raw (1 .. 9) = "dashboard" then
            return;
         end if;
         --  The component name is the raw base name, bounded to 64.
         NLen := Raw_Len;
         Name (1 .. NLen) := Raw (1 .. NLen);
         --  Known bundled libraries get their upstream npm name, version
         --  and PURL; everything else keeps the generic fallback.  The
         --  language comes from the asset's extension (.js -> JavaScript,
         --  .css -> CSS), like every other vendored file.
         declare
            NN       : Natural := 0;
            VN       : Natural := 0;
            LN       : Natural := 0;
            Npm_Name : Lib_Name_Field := (others => ' ');
            Lib_Ver  : Lib_Name_Field := (others => ' ');
            Lib_Lic  : Lib_Name_Field := (others => ' ');
         begin
            if Bundled_Library
                 (Raw (1 .. Raw_Len), Npm_Name, NN, Lib_Ver, VN, Lib_Lic, LN)
            then
               Append_Dependency
                 (Graph,
                  Npm_Name (1 .. NN),
                  Lib_Ver (1 .. VN),
                  Lib_Lic (1 .. LN),
                  "",
                  "pkg:npm/" & Npm_Name (1 .. NN) & "@" & Lib_Ver (1 .. VN),
                  1,
                  False,
                  Types.Scope_Vendored,
                  Extension_Language (Base));
            else
               Append_Dependency
                 (Graph,
                  Name (1 .. NLen),
                  "",
                  "",
                  "",
                  "pkg:generic/" & Name (1 .. NLen),
                  1,
                  False,
                  Types.Scope_Vendored,
                  Extension_Language (Base));
            end if;
         end;
      end Add_Vendored_Asset;

      procedure Scan_One_Vendored_Root (Root : String) is
      begin
         if not Ada.Directories.Exists (Root) then
            return;
         end if;
         Dir_Stack.Clear;
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
                           elsif N'Length > 3
                             and then (N (N'Last - 2 .. N'Last) = ".js"
                                       or else N (N'Last - 3 .. N'Last)
                                               = ".css")
                           then
                              Add_Vendored_Asset (Path);
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
      end Scan_One_Vendored_Root;

      Patches_Root   : constant String :=
        (if Target_Dir'Length > 0 and then Target_Dir (Target_Dir'Last) = '/'
         then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
         else Target_Dir)
        & "/.adacovex/patches";
      Resources_Root : constant String :=
        (if Target_Dir'Length > 0 and then Target_Dir (Target_Dir'Last) = '/'
         then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
         else Target_Dir)
        & "/resources";
      --  The vendor/ root itself is not scanned here.  Loose files under it
      --  must never become components.  Discover_Generic_Vendored turns each
      --  manifest-carrying or source-carrying vendor subdirectory into one
      --  component.  The component carries its top-3 language summary.
      Assets_Root    : constant String :=
        (if Target_Dir'Length > 0 and then Target_Dir (Target_Dir'Last) = '/'
         then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
         else Target_Dir)
        & "/assets";
   begin
      Scan_One_Vendored_Root (Patches_Root);
      Scan_One_Vendored_Root (Resources_Root);
      Scan_One_Vendored_Root (Assets_Root);
   end Discover_Vendored_Components;

   --  Language-agnostic vendored-component discovery.  Walk the target tree
   --  (excluding VCS, build, and installer noise).  Treat every directory
   --  whose base name is a known vendor directory as a vendored source.
   --  Scan it shallowly (max 2 levels):
   --    * A directory that carries an ecosystem manifest (package.json,
   --      Cargo.toml, go.mod, pyproject.toml, composer.json, Gemfile,
   --      pom.xml, Package.swift, requirements*.txt) becomes one
   --      Scope_Vendored component.  The manifest names and versions it.
   --      Its ecosystem PURL is pkg:npm/... or pkg:cargo/... and more.
   --    * A directory that holds Ada sources (.ads/.adb) without a manifest
   --      becomes a Scope_Vendored Ada component.  It is named after the
   --      directory (for example a hand-vendored Ada library under
   --      third_party/).  npm scope containers (node_modules/@scope without
   --      a manifest) never become components; the scoped package below
   --      them does.  pnpm store and shim dirs (.pnpm, .bin) are skipped
   --      entirely -- they are not packages.
   --  Every component carries its language or languages.  The languages are
   --  detected from file extensions.  The ecosystem language is first.  The
   --  top 3 are used and mixed sources list the leading languages.
   procedure Discover_Generic_Vendored
     (Target_Dir : String;
      Graph      : in out Types.Implementation.Component_Vectors.Vector)
   is
      use Ada.Directories;
      type Dir_Entry is record
         Path  : Types.Path_Field;
         Len   : Natural := 0;
         Level : Natural := 0;
      end record;
      package Dir_Stacks is new Ada.Containers.Vectors (Positive, Dir_Entry);
      Tree_Stack : Dir_Stacks.Vector;
      Scan_Stack : Dir_Stacks.Vector;
      Search     : Search_Type;
      Ent        : Directory_Entry_Type;

      procedure Push_Dir
        (S : in out Dir_Stacks.Vector; Dir : String; Level : Natural)
      is
         Item : Dir_Entry;
      begin
         if Dir'Length <= Types.Max_Path then
            Item.Len := Dir'Length;
            for I in Dir'Range loop
               Item.Path (I - Dir'First + 1) := Dir (I);
            end loop;
            Item.Level := Level;
            S.Append (Item);
         end if;
      end Push_Dir;

      --  Directory names inside a vendor root that never represent a
      --  package: pnpm's virtual store (.pnpm holds lock.yaml + the
      --  resolved store, not a dependency) and the .bin shim dir.  They are
      --  skipped entirely -- never descended into, never componentised.
      function Skip_Vendor_Scan_Dir (N : String) return Boolean is
      begin
         return N = ".pnpm" or else N = ".bin";
      end Skip_Vendor_Scan_Dir;

      --  One component per manifest-carrying (or Ada-source-carrying)
      --  directory inside a matched vendor root.  The scan is shallow.  It
      --  uses its own directory-search handles.  It can run while the
      --  caller's tree walk is mid-search.
      procedure Scan_Vendor_Root (Root : String; Max_Levels : Natural) is
         S2 : Search_Type;
         E2 : Directory_Entry_Type;
      begin
         Scan_Stack.Clear;
         Push_Dir (Scan_Stack, Root, 0);
         while not Scan_Stack.Is_Empty loop
            declare
               Current  : Dir_Entry := Scan_Stack.Last_Element;
               Dir_Path : String renames Current.Path (1 .. Current.Len);
            begin
               Scan_Stack.Delete_Last;
               --  Subdirectory bookkeeping: descend up to Max_Levels.
               Start_Search (S2, Dir_Path, "");
               begin
                  while More_Entries (S2) loop
                     Get_Next_Entry (S2, E2);
                     declare
                        N    : constant String := Simple_Name (E2);
                        Path : constant String := Full_Name (E2);
                     begin
                        if Kind (E2) = Directory then
                           if N /= "."
                             and then N /= ".."
                             and then not Skip_Vendor_Scan_Dir (N)
                             and then Current.Level < Max_Levels
                           then
                              Push_Dir (Scan_Stack, Path, Current.Level + 1);
                           end if;
                        end if;
                     end;
                  end loop;
               exception
                  when others =>
                     End_Search (S2);
                     raise;
               end;
               End_Search (S2);

               --  Component source: ecosystem manifest or source files.
               --  The vendor root itself (level 0) is not a component.  Only
               --  its children are components.
               if Current.Level > 0 then
                  declare
                     M : Vendor_Manifest;
                  begin
                     Read_Vendor_Manifest (Dir_Path, M);
                     if M.Found then
                        declare
                           N       : String :=
                             (if M.Name_Len > 0
                              then M.Name (1 .. M.Name_Len)
                              else Simple_Name (Dir_Path));
                           V       : String :=
                             (if M.Version_Len > 0
                              then M.Version (1 .. M.Version_Len)
                              else "");
                           Lic_Buf : Types.Desc_Field;
                           Lic_Len : Natural := 0;
                           Pur     : String :=
                             "pkg:"
                             & M.PURL_Kind (1 .. M.PURL_Kind_Len)
                             & "/"
                             & N
                             & (if V'Length > 0 then "@" & V else "");
                           L       : constant String :=
                             Language_Of_Dir
                               (Dir_Path,
                                2,
                                M.Primary_Lang (1 .. M.Primary_Lang_Len));
                        begin
                           --  Prefer the licence read from the local manifest
                           --  (offline, reliable).  Fall back to the package
                           --  registry for any ecosystem the resolver supports
                           --  (npm, pnpm, and cargo today; add a row to the
                           --  dispatch table to cover more) when the component
                           --  ships no licence file.  Ecosystems with no
                           --  reliable registry CLI keep an empty licence.
                           if M.License_Len > 0 then
                              Lic_Len := M.License_Len;
                              Lic_Buf (1 .. Lic_Len) :=
                                M.License (1 .. Lic_Len);
                           else
                              Resolve_Ecosystem_Metadata
                                (M.PURL_Kind (1 .. M.PURL_Kind_Len),
                                 N,
                                 Lic_Buf,
                                 Lic_Len);
                           end if;
                           Append_Dependency
                             (Graph,
                              N,
                              V,
                              Lic_Buf (1 .. Lic_Len),
                              "",
                              Pur,
                              1,
                              False,
                              Types.Scope_Vendored,
                              L);
                        end;
                     else
                        --  Library vendored without a manifest.  The directory
                        --  itself is the component.  The language is the top-3
                        --  summary of its source-file extensions.  Ada-only
                        --  directories are included.  npm scope containers
                        --  (a node_modules/@scope directory without its own
                        --  package.json) are never components themselves --
                        --  only the scoped package below them is.
                        declare
                           Dir_N : constant String := Simple_Name (Dir_Path);
                           L     : constant String :=
                             Language_Of_Dir (Dir_Path, 2);
                        begin
                           if L'Length > 0
                             and then (Dir_N'Length = 0
                                       or else Dir_N (Dir_N'First) /= '@')
                           then
                              Append_Dependency
                                (Graph,
                                 Dir_N,
                                 "",
                                 "",
                                 "",
                                 "pkg:generic/" & Dir_N,
                                 1,
                                 False,
                                 Types.Scope_Vendored,
                                 L);
                           end if;
                        end;
                     end if;
                  end;
               end if;
            end;
         end loop;
      end Scan_Vendor_Root;
   begin
      Push_Dir (Tree_Stack, Target_Dir, 0);
      while not Tree_Stack.Is_Empty loop
         declare
            Current  : Dir_Entry := Tree_Stack.Last_Element;
            Dir_Path : String renames Current.Path (1 .. Current.Len);
         begin
            Tree_Stack.Delete_Last;
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
                          and then N /= ".."
                          and then not Skip_Walk_Dir (N)
                        then
                           if Is_Vendor_Dir_Name (N) then
                              --  node_modules needs depth 2 so scoped
                              --  packages (node_modules/@scope/pkg) resolve;
                              --  the pnpm store (.pnpm) and .bin are skipped
                              --  inside the scan itself.
                              Scan_Vendor_Root (Path, 2);
                           else
                              Push_Dir (Tree_Stack, Path, 0);
                           end if;
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
   end Discover_Generic_Vendored;
   type Tool_Entry is record
      Name : String (1 .. 16);
      Len  : Natural := 0;
      Flag : String (1 .. 16);
      FLen : Natural := 0;
   end record;

   --  Build a Tool_Entry from a string literal.  The System_Tools table
   --  stays readable.  VFlag is the version-probe flag or subcommand.
   --  Every tool here accepts "--version" except fossil and git-lfs.  Those
   --  two use the "version" subcommand.
   --  @param S  Tool name (lowercase, for example "python3").
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

   System_Tools : constant array (1 .. 60) of Tool_Entry :=
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
      Make_Tool ("pandoc"),
      Make_Tool ("npm"),
      Make_Tool ("node"),
      Make_Tool ("yarn"),
      Make_Tool ("pnpm"),
      Make_Tool ("cargo"),
      Make_Tool ("rustc"),
      Make_Tool ("go"),
      Make_Tool ("gcc"),
      Make_Tool ("g++"),
      Make_Tool ("clang"),
      Make_Tool ("javac"),
      Make_Tool ("mvn"),
      Make_Tool ("gradle"),
      Make_Tool ("ruby"),
      Make_Tool ("dotnet"),
      Make_Tool ("tsc"),
      Make_Tool ("sass"),
      Make_Tool ("scss"),
      Make_Tool ("rustup"),
      Make_Tool ("cargo-hack"),
      Make_Tool ("cargo-watch"),
      Make_Tool ("ada"),
      Make_Tool ("alire"));

   --  Probe a tool's version by running "<Tool> <Flag>" and extracting the
   --  first whitespace-separated token that contains a digit from the
   --  captured output (for example "2.55.0" from "git version 2.55.0",
   --  "4.4.1" from "GNU Make 4.4.1").  Returns "" when the tool is missing,
   --  when the probe fails, or when no digit token is found.  A tool that
   --  does not understand its version flag then reports no version.
   --  @param Tool  Executable name (must be on PATH).
   --  @param Flag  Version-probe flag or subcommand.
   --  @return The extracted version string, or "".
   function Probe_Version (Tool : String; Flag : String) return String is
      Pid     : constant Integer := Pid_To_Integer (Current_Process_Id);
      Pid_Img : constant String := Integer'Image (Pid);
      Tmp     : constant String :=
        Adacovex.CPUs.Get_Temp_Directory
        & "/adacovex-ver-"
        & Pid_Img (2 .. Pid_Img'Last)
        & ".out";
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
      --  stray trailing punctuation (for example the ")" of "7.2.4)")
      --  trimmed.
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
   --  Walk the project tree and read dev-facing files.  These files are
   --  Makefile variants, shell scripts, Python tools, Alire manifests, CI
   --  workflows, GNAT project files, and Ada sources.  Register every known
   --  system tool that the files reference and that is actually installed on
   --  PATH.  Register it as a dev-scope dependency of the root.  A Makefile
   --  at the project root implies make.  This applies even when no recipe
   --  spells out the driver by name.
   --  Docstrings (.md prose) are not scanned.  Prose is not tool
   --  interaction.  Words like "make" are common in prose.  The source file
   --  that declares the System_Tools table itself is skipped.  It references
   --  every curated tool by construction.  Scanning it can register every
   --  installed tool as a self-reference.
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

      --  "tool=version" pairs observed for the referenced tools.  Populated
      --  on a scan (from the version probe) or restored from the tools
      --  cache blob on a hit, so the SBOM does not need to re-run probes
      --  for an unchanged project.
      type Probe_Pair is record
         Name : Types.Name_Field;
         NLen : Natural := 0;
         Ver  : Types.Desc_Field;
         VLen : Natural := 0;
      end record;
      package Probe_Vectors is new
        Ada.Containers.Vectors (Positive, Probe_Pair);
      Probes : Probe_Vectors.Vector;

      --  Record a probe result for a referenced tool (deduplicated).
      --  Forward-declared so Deserialize_Set can call it.
      procedure Add_Probe (Name : String; Version : String);

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

      --  Whether to scan a file for tool references.  Makefile variants are
      --  scanned by name.  Dev-facing text files are scanned by extension.
      function Should_Scan (Name : String) return Boolean is
         Dot : Natural := 0;
      begin
         if Name = "makefile"
           or else Name = "Makefile"
           or else Name = "GNUmakefile"
         then
            return True;
         end if;
         if Name = "package.json"
           or else Name = "tsconfig.json"
           or else Name = "jsconfig.json"
           or else Name = "Cargo.toml"
           or else Name = "Cargo.lock"
           or else Name = "go.mod"
           or else Name = "go.sum"
           or else Name = "Gemfile"
           or else Name = "requirements.txt"
           or else Name = "pyproject.toml"
           or else Name = "pom.xml"
           or else Name = "build.gradle"
           or else Name = "build.gradle.kts"
           or else Name = "settings.gradle"
           or else Name = "settings.gradle.kts"
           or else Name = "*.csproj"
           or else Name = "*.sln"
           or else Name = "Makefile"
           or else Name = "makefile"
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
              or else Ext = ".adb"
              or else Ext = ".c"
              or else Ext = ".h"
              or else Ext = ".cpp"
              or else Ext = ".hpp"
              or else Ext = ".cc"
              or else Ext = ".cxx"
              or else Ext = ".rb"
              or else Ext = ".cs"
              or else Ext = ".java"
              or else Ext = ".rs"
              or else Ext = ".go"
              or else Ext = ".js"
              or else Ext = ".mjs"
              or else Ext = ".cjs"
              or else Ext = ".ts"
              or else Ext = ".mts"
              or else Ext = ".cts"
              or else Ext = ".scss"
              or else Ext = ".css"
              or else Ext = ".json";
         end;
      end Should_Scan;

      --  Record Tool as referenced by the project's files.
      procedure Note_Tool (Tool : Tool_Entry) is
      begin
         Add_Dep_Name (Referenced, Tool.Name (1 .. Tool.Len));
      end Note_Tool;

      --  Serialize the referenced-tool set and its probe results to a
      --  cache blob.  Format: comma-separated tool names, then a ';'
      --  separator, then comma-separated "name=version" probe pairs (both
      --  bounded by the 8192-char blob).  The probe section lets a cache
      --  hit skip re-running version probes and PATH lookups.
      function Serialize_Set return String is
         S : String (1 .. 8192);
         L : Natural := 0;

         procedure Add (Txt : String) is
         begin
            if L + Txt'Length <= S'Last then
               S (L + 1 .. L + Txt'Length) := Txt;
               L := L + Txt'Length;
            end if;
         end Add;
      begin
         for I in 1 .. Integer (Referenced.Length) loop
            declare
               Nm : constant String :=
                 Referenced (I).Name (1 .. Referenced (I).Len);
            begin
               if L > 0 then
                  Add (",");
               end if;
               Add (Nm);
            end;
         end loop;
         Add ("|");
         for I in 1 .. Integer (Probes.Length) loop
            declare
               Nm : constant String := Probes (I).Name (1 .. Probes (I).NLen);
               Vr : constant String := Probes (I).Ver (1 .. Probes (I).VLen);
            begin
               if L > 0 and then S (L) /= '|' then
                  Add (",");
               end if;
               Add (Nm);
               Add ("=");
               Add (Vr);
            end;
         end loop;
         return S (1 .. L);
      end Serialize_Set;

      --  Deserialize the cache blob into Referenced and Probes.
      procedure Deserialize_Set (Blob : String) is
         Sep   : Natural := 0;
         Start : Natural := Blob'First;

         procedure Add_Name (Nm : String) is
         begin
            if Nm'Length > 0 then
               Add_Dep_Name (Referenced, Nm);
            end if;
         end Add_Name;
      begin
         --  Split on the '|' separator: names before, probe pairs after.
         for I in Blob'First .. Blob'Last loop
            if Blob (I) = '|' then
               Sep := I;
               exit;
            end if;
         end loop;
         if Sep = 0 then
            --  Old-format blob (names only).
            Start := Blob'First;
            for I in Blob'First .. Blob'Last loop
               if Blob (I) = ',' then
                  Add_Name (Blob (Start .. I - 1));
                  Start := I + 1;
               end if;
            end loop;
            if Start <= Blob'Last then
               Add_Name (Blob (Start .. Blob'Last));
            end if;
            return;
         end if;

         --  Names section.
         Start := Blob'First;
         for I in Blob'First .. Sep - 1 loop
            if Blob (I) = ',' then
               Add_Name (Blob (Start .. I - 1));
               Start := I + 1;
            end if;
         end loop;
         if Start <= Sep - 1 then
            Add_Name (Blob (Start .. Sep - 1));
         end if;

         --  Probe section: parse "name=version" comma-separated pairs.
         Start := Sep + 1;
         for I in Sep + 1 .. Blob'Last loop
            if Blob (I) = ',' then
               declare
                  Nm : constant String := Blob (Start .. I - 1);
                  Eq : Natural := 0;
               begin
                  for J in Nm'Range loop
                     if Nm (J) = '=' then
                        Eq := J;
                        exit;
                     end if;
                  end loop;
                  if Eq > Nm'First then
                     Add_Probe
                       (Nm (Nm'First .. Eq - 1), Nm (Eq + 1 .. Nm'Last));
                  end if;
               end;
               Start := I + 1;
            end if;
         end loop;
         if Start <= Blob'Last then
            declare
               Nm : constant String := Blob (Start .. Blob'Last);
               Eq : Natural := 0;
            begin
               for J in Nm'Range loop
                  if Nm (J) = '=' then
                     Eq := J;
                     exit;
                  end if;
               end loop;
               if Eq > Nm'First then
                  Add_Probe (Nm (Nm'First .. Eq - 1), Nm (Eq + 1 .. Nm'Last));
               end if;
            end;
         end if;
      end Deserialize_Set;

      --  Record a probe result for a referenced tool (deduplicated).
      procedure Add_Probe (Name : String; Version : String) is
      begin
         if Name'Length = 0 then
            return;
         end if;
         for I in 1 .. Integer (Probes.Length) loop
            if Probes (I).NLen = Name'Length
              and then Probes (I).Name (1 .. Name'Length) = Name
            then
               return;
            end if;
         end loop;
         declare
            P : Probe_Pair;
         begin
            P.NLen := Name'Length;
            P.Name (1 .. Name'Length) := Name (Name'First .. Name'Last);
            P.VLen := Version'Length;
            P.Ver (1 .. Version'Length) :=
              Version (Version'First .. Version'Last);
            Probes.Append (P);
         end;
      end Add_Probe;

      --  Whether C bounds a tool-name word in a line.  A word is a maximal
      --  run of lowercase letters, digits, underscore, and hyphen
      --  ([a-z0-9_-]).  Uppercase letters do not start or continue a word,
      --  so "Makefile" and "MAKE" never match the lowercase tool "make".
      function Is_Word_Char (C : Character) return Boolean is
      begin
         return
           (C in 'a' .. 'z')
           or else (C in '0' .. '9')
           or else C = '_'
           or else C = '-';
      end Is_Word_Char;

      --  When the word at Line (W_First .. W_Last) names one of the curated
      --  system tools, record it via Note_Tool.  The match is
      --  case-sensitive.  Only words whose length equals a tool name are
      --  compared, so a line is scored once per word instead of once per
      --  tool.  "make" matches in "make build".  "make" does not match in
      --  "Makefile" (capital M), "makefile", or "makefiles".  "python"
      --  does not match inside "python3".
      --  @param Line  Line of text to search.
      --  @param W_First  First index of the word in Line.
      --  @param W_Last  Last index of the word in Line.
      procedure Note_If_Tool
        (Line : String; W_First : Natural; W_Last : Natural)
      is
         W_Len : constant Natural := W_Last - W_First + 1;
      begin
         for T in System_Tools'Range loop
            if System_Tools (T).Len = W_Len then
               declare
                  Is_Tool : Boolean := True;
               begin
                  for J in 1 .. W_Len loop
                     if Line (W_First + J - 1) /= System_Tools (T).Name (J)
                     then
                        Is_Tool := False;
                        exit;
                     end if;
                  end loop;
                  if Is_Tool then
                     Note_Tool (System_Tools (T));
                     return;
                  end if;
               end;
            end if;
         end loop;
      end Note_If_Tool;

      --  Record every system tool that Line references as a whole word.
      --  The line is walked once, extracting maximal [a-z0-9_-] words, and
      --  each word is compared against the tool table by length first.
      --  This replaces a per-tool substring scan (60 tools x line length)
      --  with a per-word scan (a few words x 60 length checks), which was
      --  the dominant CPU cost of the SBOM system-dev-dependency discovery
      --  on every run.
      --  @param Line  Line of text to search.
      procedure Note_Referenced_Tools (Line : String) is
         W_First : Natural := Line'First;
         W_Last  : Natural;
      begin
         if Line'Length < 2 then
            --  No tool name is one character long; a shorter line cannot
            --  reference any tool.
            return;
         end if;
         while W_First <= Line'Last loop
            --  Skip non-word characters (whitespace, quotes, punctuation).
            while W_First <= Line'Last
              and then not Is_Word_Char (Line (W_First))
            loop
               W_First := W_First + 1;
            end loop;
            exit when W_First > Line'Last;
            W_Last := W_First;
            while W_Last < Line'Last and then Is_Word_Char (Line (W_Last + 1))
            loop
               W_Last := W_Last + 1;
            end loop;
            Note_If_Tool (Line, W_First, W_Last);
            W_First := W_Last + 1;
         end loop;
      end Note_Referenced_Tools;

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
               --  A physical line longer than Max_Line.  Stop scanning this
               --  file.  A truncated file then never yields a partial tool
               --  set.
               Close (F);
               return;
            end if;
            if Ada.Strings.Fixed.Index
                 (Line (1 .. Last), "System_Tools : constant array")
              > 0
            then
               --  This file declares the curated tool table.  Every entry is
               --  a literal tool name by construction.  References found
               --  here can register every installed tool.  This happens
               --  regardless of whether the project actually uses the tool.
               Close (F);
               return;
            end if;
            Note_Referenced_Tools (Line (1 .. Last));
         end loop;
         Close (F);
      exception
         when others =>
            if Is_Open (F) then
               Close (F);
            end if;
      end Scan_File;

      --  Input key for the referenced-tools cache.  It combines the same
      --  content hashes that Graph_Key uses (manifest, dev manifest, lock,
      --  vendored hash, language summary, GPR files) with the source-tree
      --  content hash.  The system-tool reference scan reads the same
      --  project files, so an unchanged project has an unchanged key and the
      --  cached set is served without re-walking the tree or re-reading a
      --  file.
      --  Forward declaration so Tools_Key can call Source_Tree_Hash.
      function Source_Tree_Hash (Dir : String) return String;

      function Tools_Key (Target_Dir : String) return String is
         T    : constant String :=
           (if Target_Dir'Length > 1
              and then Target_Dir (Target_Dir'Last) = '/'
            then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
            else Target_Dir);
         Comb : String (1 .. Types.Max_Path * 2);
         CLen : Natural := 0;
         procedure Add (S : String) is
         begin
            if S'Length > 0 and then CLen + S'Length <= Comb'Last then
               Comb (CLen + 1 .. CLen + S'Length) := S;
               CLen := CLen + S'Length;
            end if;
         end Add;
      begin
         --  Source_Tree_Hash covers every file the scan reads, so it alone
         --  determines the referenced-tool set.  The tool-table fingerprint
         --  (every curated tool name, salted) invalidates the key when the
         --  System_Tools constant changes within a release.  The "|tools-v2|"
         --  salt separates this cache namespace from the graph cache and
         --  from the 1.27-era blob layout.
         Add (Source_Tree_Hash (T));
         for I in System_Tools'Range loop
            Add (System_Tools (I).Name (1 .. System_Tools (I).Len));
         end loop;
         Add ("|tools-v2|");
         if CLen = 0 then
            return "";
         end if;
         return "tools:" & Adacovex.Cache.Hash_String (Comb (1 .. CLen));
      end Tools_Key;

      --  Source-tree content hash used by Tools_Key.  Walks the same
      --  directories and files that Discover_System_Dev_Deps scans and
      --  combines per-file digests.  This is what makes the tool-set cache
      --  sound: a file edit that adds or removes a tool reference changes
      --  the hash, so the next run re-scans instead of serving a stale
      --  set.  The directory-exclusion list matches the main walk exactly.
      function Source_Tree_Hash (Dir : String) return String is
         use Ada.Directories;
         type Dir_Entry is record
            Path : Types.Path_Field;
            Len  : Natural := 0;
         end record;
         package Hash_Dir_Stacks is new
           Ada.Containers.Vectors (Positive, Dir_Entry);
         Stack : Hash_Dir_Stacks.Vector;
         H     : String (1 .. Types.Max_Path * 8);
         HLen  : Natural := 0;

         procedure Add (S : String) is
         begin
            if S'Length > 0 and then HLen + S'Length <= H'Last then
               H (HLen + 1 .. HLen + S'Length) := S;
               HLen := HLen + S'Length;
            end if;
         end Add;
      begin
         if not Ada.Directories.Exists (Dir) then
            return "";
         end if;
         declare
            D : Dir_Entry;
         begin
            D.Len := Dir'Length;
            D.Path (1 .. D.Len) := Dir (Dir'First .. Dir'First + D.Len - 1);
            Stack.Append (D);
         end;
         while not Stack.Is_Empty loop
            declare
               C  : Dir_Entry := Stack.Last_Element;
               CP : String renames C.Path (1 .. C.Len);
               S  : Search_Type;
               E  : Directory_Entry_Type;
            begin
               Stack.Delete_Last;
               if not Ada.Directories.Exists (CP) then
                  null;
               else
                  Start_Search (S, CP, "");
                  while More_Entries (S) loop
                     Get_Next_Entry (S, E);
                     declare
                        N : constant String := Simple_Name (E);
                     begin
                        if Kind (E) = Directory then
                           if N /= "."
                             and then N /= ".."
                             and then N /= ".git"
                             and then N /= ".jj"
                             and then N /= ".hg"
                             and then N /= ".svn"
                             and then N /= "obj"
                             and then N /= "tests"
                             and then N /= "config"
                             and then N /= ".adacovex"
                             and then N /= "alire"
                             and then N /= "gnatprove"
                             and then N /= "__pycache__"
                             and then N /= "node_modules"
                             and then N /= ".headroom"
                             and then N /= ".lccst"
                           then
                              declare
                                 NP : constant String := Full_Name (E);
                                 I  : Dir_Entry;
                              begin
                                 I.Len := NP'Length;
                                 I.Path (1 .. I.Len) :=
                                   NP (NP'First .. NP'First + I.Len - 1);
                                 Stack.Append (I);
                              end;
                           end if;
                        elsif Kind (E) = Ordinary_File then
                           if Should_Scan (Simple_Name (E)) then
                              Add (Adacovex.Cache.Hash_File (Full_Name (E)));
                           end if;
                        end if;
                     end;
                  end loop;
                  End_Search (S);
               end if;
            end;
         end loop;
         if HLen = 0 then
            return "";
         end if;
         return Adacovex.Cache.Hash_String (H (1 .. HLen));
      end Source_Tree_Hash;

      --  Whether the project root holds a Makefile variant (implies make).
      function Has_Makefile return Boolean is
      begin
         return
           Ada.Directories.Exists (Target_Dir & "/Makefile")
           or else Ada.Directories.Exists (Target_Dir & "/makefile")
           or else Ada.Directories.Exists (Target_Dir & "/GNUmakefile");
      end Has_Makefile;

      --  Whether the referenced-tool set (and its probe results) came from
      --  the on-disk cache.  Used to skip the PATH walk and version probes.
      From_Cache : Boolean := False;

      --  Cache key (and its image) for the miss-store below.  Kept at
      --  procedure level so the store can run after the probe loop.
      Key_Img : String (1 .. 128) := (others => ' ');
      Key_Len : Natural := 0;
   begin
      --  Serve the referenced-tool set from the on-disk cache when the
      --  project's inputs are unchanged.  The key covers every file the
      --  scan reads, so an unchanged project skips the tree walk and the
      --  per-file word scan entirely; an edit invalidates the key and the
      --  next run re-scans.  The key value is kept for the store step that
      --  runs after a scan.
      declare
         K     : constant String := Tools_Key (Target_Dir);
         Blob  : String (1 .. 8192) := (others => ' ');
         BLen  : Natural := 0;
         Found : Boolean := False;
      begin
         if K'Length > 0 then
            if K'Length <= Key_Img'Last then
               Key_Img (1 .. K'Length) := K;
               Key_Len := K'Length;
            end if;
            Adacovex.Cache.Get_Cached (K, Blob, BLen, Found);
            if Found and then BLen > 0 then
               Deserialize_Set (Blob (1 .. BLen));
               From_Cache := True;
            end if;
         end if;

         if not From_Cache then
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
                                and N /= "gnatprove"
                                and N /= "__pycache__"
                                and N /= "node_modules"
                                and N /= ".headroom"
                                and N /= ".lccst"
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

         end if;
      end;

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

      --  Register every referenced tool that is actually installed on PATH.
      --  Register it as a dev-scope dependency of the root.  Probe its
      --  version ("<Tool> <flag>") when possible.  Tools the project does
      --  not reference, or that are not installed, are skipped.
      --  Append_Dependency also deduplicates against manifest, lockfile, and
      --  GPR deps (for example gnatprove declared in alire-dev.toml).  A
      --  manifest-pinned tool never appears twice.
      --
      --  Cache hit: the probe results were restored with the set, so
      --  rebuild the graph from Probes without PATH lookups or subprocess
      --  probes.
      if From_Cache then
         for PI in 1 .. Integer (Probes.Length) loop
            Append_Dependency
              (Graph,
               Probes (PI).Name (1 .. Probes (PI).NLen),
               Probes (PI).Ver (1 .. Probes (PI).VLen),
               "",
               "System tool referenced by the project (dev dependency)",
               "pkg:generic/" & Probes (PI).Name (1 .. Probes (PI).NLen),
               1,
               False,
               Types.Scope_System);
         end loop;
      else
         for I in 1 .. Integer (Referenced.Length) loop
            declare
               Name : constant String :=
                 Referenced (I).Name (1 .. Referenced (I).Len);
               Exe  : GNAT.OS_Lib.String_Access :=
                 GNAT.OS_Lib.Locate_Exec_On_Path (Name);
            begin
               if Exe /= null then
                  GNAT.OS_Lib.Free (Exe);
                  --  Version probing spawns a subprocess per tool.  Cache the
                  --  result on disk (7-day TTL).  Unchanged toolchains then do
                  --  not pay tens of milliseconds per referenced tool on every
                  --  run.
                  declare
                     Probe : String (1 .. 512) := (others => ' ');
                     PLen  : Natural := 0;
                     Found : Boolean := False;
                     --  Version text (up to the 4096-char Probe_Version reader
                     --  cap).  It is copied into a fixed buffer.  The cache-hit
                     --  and cache-miss paths then share one Append_Dependency
                     --  call.
                     VBuf  : String (1 .. 4096);
                     VLen  : Natural := 0;
                  begin
                     Adacovex.Cache.Get_Probe (Name, Probe, PLen, Found);
                     if Found then
                        VLen := PLen;
                        VBuf (1 .. VLen) := Probe (1 .. VLen);
                     else
                        declare
                           V : constant String :=
                             Probe_Version (Name, Version_Flag (Name));
                        begin
                           VLen := V'Length;
                           if VLen > VBuf'Last then
                              VLen := VBuf'Last;
                           end if;
                           VBuf (1 .. VLen) :=
                             V (V'First .. V'First + VLen - 1);
                        end;
                        Adacovex.Cache.Put_Probe (Name, VBuf (1 .. VLen));
                     end if;
                     Add_Probe (Name, VBuf (1 .. VLen));
                     Append_Dependency
                       (Graph,
                        Name,
                        VBuf (1 .. VLen),
                        "",
                        "System tool referenced by the project (dev dependency)",
                        "pkg:generic/" & Name,
                        1,
                        False,
                        Types.Scope_System);
                  end;
               end if;
            end;
         end loop;
      end if;

      --  Store the freshly scanned set (now including probe results) for
      --  the next run.  On a cache hit nothing is stored (the entry is
      --  still current and complete).
      if not From_Cache and then Key_Len > 0 then
         declare
            S  : constant String := Serialize_Set;
            OK : Boolean;
         begin
            if S'Length > 0 then
               Adacovex.Cache.Put_Cached (Key_Img (1 .. Key_Len), S, OK);
            end if;
         end;
      end if;
   end Discover_System_Dev_Deps;

   --  Fingerprint of everything that contributes vendored components to
   --  the graph.  Every file under the classic vendored roots
   --  (<target>/.adacovex/patches, resources, vendor, assets) is included.
   --  Every file under the language-agnostic vendored directories that
   --  Discover_Generic_Vendored discovers is included (deps, third_party,
   --  node_modules, and more, hashed to depth 3).  Adding, removing, or
   --  editing any of those files changes the digest.  The cached graph is
   --  then invalidated correctly.
   --  Returns "" when no vendored input exists.
   --  @param Target_Dir  Project root directory.
   --  @return SHA256 of the vendored inputs, or "" when none exist.
   function Vendored_Hash (Target_Dir : String) return String is
      use Ada.Directories;
      type Dir_Entry is record
         Path  : Types.Path_Field;
         Len   : Natural := 0;
         Level : Natural := 0;
      end record;
      package Dir_Stacks is new Ada.Containers.Vectors (Positive, Dir_Entry);
      Dir_Stack : Dir_Stacks.Vector;
      Search    : Search_Type;
      Ent       : Directory_Entry_Type;
      T         : constant String :=
        (if Target_Dir'Length > 0 and then Target_Dir (Target_Dir'Last) = '/'
         then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
         else Target_Dir);
      Comb      : String (1 .. Types.Max_Path);
      CLen      : Natural := 0;

      procedure Push_Dir
        (S         : in out Dir_Stacks.Vector;
         Dir       : String;
         Level     : Natural;
         Max_Depth : Natural)
      is
         Item : Dir_Entry;
      begin
         if Dir'Length <= Types.Max_Path and then Level <= Max_Depth then
            Item.Len := Dir'Length;
            for I in Dir'Range loop
               Item.Path (I - Dir'First + 1) := Dir (I);
            end loop;
            Item.Level := Level;
            S.Append (Item);
         end if;
      end Push_Dir;

      procedure Add (S : String) is
      begin
         if S'Length > 0 and then CLen + S'Length <= Comb'Last then
            Comb (CLen + 1 .. CLen + S'Length) := S;
            CLen := CLen + S'Length;
         end if;
      end Add;

      --  Hash every regular file under Root, descending at most Max_Levels
      --  subdirectories.  It uses its own stack.  The outer vendor walk is
      --  then unaffected.
      procedure Hash_Tree (Root : String; Max_Levels : Natural) is
         H_Stack  : Dir_Stacks.Vector;
         H_Search : Search_Type;
         H_Ent    : Directory_Entry_Type;
      begin
         if not Exists (Root) then
            return;
         end if;
         Push_Dir (H_Stack, Root, 0, Max_Levels);
         while not H_Stack.Is_Empty loop
            declare
               Current  : Dir_Entry := H_Stack.Last_Element;
               Dir_Path : String renames Current.Path (1 .. Current.Len);
            begin
               H_Stack.Delete_Last;
               Start_Search (H_Search, Dir_Path, "");
               begin
                  while More_Entries (H_Search) loop
                     Get_Next_Entry (H_Search, H_Ent);
                     declare
                        N    : constant String := Simple_Name (H_Ent);
                        Path : constant String := Full_Name (H_Ent);
                     begin
                        if Kind (H_Ent) = Directory then
                           if N /= "." and N /= ".." then
                              Push_Dir
                                (H_Stack, Path, Current.Level + 1, Max_Levels);
                           end if;
                        elsif Kind (H_Ent) = Ordinary_File then
                           Add (Adacovex.Cache.Hash_File (Path));
                        end if;
                     end;
                  end loop;
               exception
                  when others =>
                     End_Search (H_Search);
                     raise;
               end;
               End_Search (H_Search);
            end;
         end loop;
      end Hash_Tree;
   begin
      --  Classic doc roots (.adacovex/patches, resources, vendor, assets).
      --  Every regular file counts, at any depth (curated and small).
      Hash_Tree (T & "/.adacovex/patches", 99);
      Hash_Tree (T & "/resources", 99);
      Hash_Tree (T & "/vendor", 99);
      Hash_Tree (T & "/assets", 99);

      --  Language-agnostic vendored directories anywhere in the tree (same
      --  discovery walk as Discover_Generic_Vendored, shallow).
      Dir_Stack.Clear;
      Push_Dir (Dir_Stack, Target_Dir, 0, 99);
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
                          and then N /= ".."
                          and then not Skip_Walk_Dir (N)
                        then
                           if Is_Vendor_Dir_Name (N) then
                              Hash_Tree
                                (Path, (if N = "node_modules" then 1 else 3));
                           else
                              Push_Dir (Dir_Stack, Path, 0, 99);
                           end if;
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

      if CLen = 0 then
         return "";
      end if;
      return Adacovex.Cache.Hash_String (Comb (1 .. CLen));
   end Vendored_Hash;

   --  Combined content hash of everything that shapes the dependency graph.
   --  The publishing manifest, the dev manifest, and the alire.lock are
   --  included.  Every .gpr file collected from the project tree is
   --  included.  The vendored directories (classic roots and language-
   --  agnostic vendor dirs) are included.  The root project's detected
   --  language mix is included.  It is a cheap probe of the source tree's
   --  file-name distribution.  A source-language change then invalidates
   --  the cached graph too.  Returns "" when no input could be hashed.
   --  Nothing is cached in that case.
   --  @param Target_Dir  Project root directory (for alire-dev.toml,
   --    alire/alire.lock, the vendored dirs, and the root language probe,
   --    which live beside or under it).
   --  @param Manifest_Path  Path to the Alire manifest (can be an override).
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
      Add (Vendored_Hash (Target_Dir));
      declare
         Langs : Lang_Vectors.Vector;
      begin
         Detect_Languages (T, 3, Langs, Skip_Vendored => True);
         Add ("rl:" & Language_Summary (Langs, ""));
      end;
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
      Root_Website     : Types.Path_Field;
      Root_Website_Len : Natural := 0;
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
         Root_Website,
         Root_Website_Len,
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
      --  .gpr file.  The directory walk above is cheap.  The recursive GPR
      --  and lock parsing that it saves is not cheap.
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

      --  Locate the root .gpr.  Use the manifest project-files entry if
      --  present.  Otherwise use a .gpr whose project name matches the
      --  manifest crate name.
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
      --  Root language.  The top languages of the project's own sources are
      --  used (vendored directories excluded).  The SBOM root component then
      --  records the language mix that created it (top 3 for mixed trees).
      declare
         Root_T     : constant String :=
           (if Target_Dir'Length > 0
              and then Target_Dir (Target_Dir'Last) = '/'
            then Target_Dir (Target_Dir'First .. Target_Dir'Last - 1)
            else Target_Dir);
         Root_Langs : Lang_Vectors.Vector;
      begin
         Detect_Languages (Root_T, 3, Root_Langs, Skip_Vendored => True);
         if not Root_Langs.Is_Empty then
            declare
               RL : constant String := Language_Summary (Root_Langs, "");
            begin
               if RL'Length > 0 then
                  Set_Field (Root.Language, Root.Language_Len, RL);
               end if;
            end;
         end if;
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
      if Root_Website_Len > 0 then
         Set_Path
           (Root.Website,
            Root.Website_Len,
            Root_Website (1 .. Root_Website_Len));
      end if;
      Root.Kind := Types.Root_Component;
      Root.Parent := 0;
      Graph.Append (Root);

      --  Resolve alire.lock dependencies (solved crates).
      Read_Alire_Lock (Target_Dir & "/alire/alire.lock", Graph);

      --  Resolve GPR with-clause dependencies, including transitives.
      Resolve_GPR_Deps (Graph, GPR_Files, GPR_Deps, 1, 8);

      --  Add vendored packages overlaid by .adacovex/patches/ docstring
      --  patches (for example a third-party copy under demo/deps) as
      --  scope=vendored dependencies of the root.
      Discover_Vendored_Components (Target_Dir, Graph);

      --  Add language-agnostic vendored components.  These are ecosystem
      --  manifests (package.json, Cargo.toml, and more) and Ada library dirs
      --  under any vendor-named directory (third_party, deps, node_modules,
      --  and more).  Each has its ecosystem PURL and detected language or
      --  languages.
      Discover_Generic_Vendored (Target_Dir, Graph);

      --  Register manifest-declared deps (base from alire.toml, dev from
      --  alire-dev.toml) that no GPR with-clause or lockfile resolved.  The
      --  SBOM captures the declared dependency set.  This applies even for
      --  zero-`with` projects whose toolchain deps live only in the dev
      --  manifest.
      Register_Manifest_Deps (Graph, Base_Names, Dev_Names);

      Success := Root.Name_Len > 0;

      --  Store the freshly resolved graph for the next run.  Store it only on
      --  success.  A partial graph is then never cached.
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
