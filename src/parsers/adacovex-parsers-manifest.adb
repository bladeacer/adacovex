with Ada.Text_IO;
with Ada.Directories;
with Ada.Containers.Vectors;

package body Adacovex.Parsers.Manifest is

   use type Types.Component_Kind;

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

   function Starts_With (S : String; Pre : String) return Boolean
   with SPARK_Mode => On
   is
   begin
      if Pre'Length > S'Length then
         return False;
      end if;
      for I in Pre'Range loop
         if Pre (I) /= S (S'First + (I - Pre'First)) then
            return False;
         end if;
      end loop;
      return True;
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
      F    : File_Type;
      Line : String (1 .. Types.Max_Line);
      Last : Natural;
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
         Get_Line (F, Line, Last);
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
         Get_Line (F, Line, Last);
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

   procedure Append_Dependency
     (Graph    : in out Types.Implementation.Component_Vectors.Vector;
      Name     : String;
      Version  : String;
      License  : String;
      Desc     : String;
      PURL     : String;
      Parent   : Natural;
      From_GPR : Boolean)
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
      Graph.Append (C);
   end Append_Dependency;

   procedure Read_Alire_Lock
     (Lock_Path : String;
      Graph     : in out Types.Implementation.Component_Vectors.Vector)
   is
      use Ada.Text_IO;
      F                 : File_Type;
      Line              : String (1 .. Types.Max_Line);
      Last              : Natural;
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
                  False);
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
         Get_Line (F, Line, Last);
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
               Append_Dependency
                 (Graph, Name, "", "", "", "pkg:gpr/" & Name, Parent, True);
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

      Success := Root.Name_Len > 0;
   end Build_Dependency_Graph;

end Adacovex.Parsers.Manifest;
