separate (Adacovex.Parsers.Manifest)
--  Register the GitHub Actions workflow actions the project uses as
--  dev-scope dependencies of the root. A workflow action is a declared
--  dependency: `uses: owner/repo@ref` names an owner, a repository, and a
--  ref that the workflow runs, so the SBOM states it the same way a
--  package manifest does. The scan reads .github/workflows/*.yml and
--  *.yaml, and the repository's own composite action.yml, because all
--  three hold the same `uses:` declaration.
--  The version is the ref the workflow pins (a tag such as v4, or a
--  commit SHA). The PURL is `pkg:github/<owner>/<repo>@<ref>`, the type
--  syft uses for an action. A local action (./path) is the project itself
--  and a `docker://` image is not a repository action, so neither becomes
--  a component. A value that is still an expression (${{ ... }}) states no
--  ref, so it is skipped rather than guessed.
--  @param Target_Dir  Project root directory.
--  @param Graph  Dependency graph to extend (root at index 1).
procedure Discover_Workflow_Actions
  (Target_Dir : String;
   Graph      : in out Types.Implementation.Component_Vectors.Vector)
is
   use Ada.Strings.Fixed;

   --  Register one `uses:` reference from a line of YAML.
   --  @param L  One physical line of a workflow or action file.
   procedure Register_Line (L : String) is
      Key : constant String := "uses:";
      Pos : constant Natural := Index (L, Key);
   begin
      if Pos = 0 then
         return;
      end if;
      declare
         V_First : Natural := Pos + Key'Length;
         V_Last  : Natural := V_First - 1;
      begin
         --  Skip the spaces between the key and the value.
         while V_First <= L'Last
           and then (L (V_First) = ' ' or else L (V_First) = Character'Val (9))
         loop
            V_First := V_First + 1;
         end loop;
         if V_First > L'Last then
            return;
         end if;
         --  The value ends at the first space or comment marker.
         V_Last := V_First;
         while V_Last < L'Last
           and then L (V_Last + 1) /= ' '
           and then L (V_Last + 1) /= '#'
           and then L (V_Last + 1) /= Character'Val (9)
         loop
            V_Last := V_Last + 1;
         end loop;
         declare
            V      : constant String := L (V_First .. V_Last);
            Ref_At : Natural := 0;
            Sl     : Natural := 0;
            Nl     : Natural;
         begin
            --  The ref follows the last '@' in the value: a repository path
            --  never carries one.
            for I in reverse V'Range loop
               if V (I) = '@' then
                  Ref_At := I;
                  exit;
               end if;
            end loop;
            if Ref_At = 0 or else Ref_At = V'First or else Ref_At = V'Last then
               return;
            end if;
            --  A local action and a container image are not repository
            --  actions, and an unresolved expression states no ref.
            if (V'Length >= 2 and then V (V'First .. V'First + 1) = "./")
              or else (V'Length >= 6
                       and then V (V'First .. V'First + 5) = "docker")
              or else Index (V, "$") > 0
            then
               return;
            end if;
            --  The name is owner/repo, so a subdirectory path after the
            --  repository name is dropped: the repository is the
            --  dependency, and the subdirectory is a location inside it.
            for I in V'First .. Ref_At - 1 loop
               if V (I) = '/' then
                  if Sl = 0 then
                     Sl := I;
                  else
                     exit;
                  end if;
               end if;
            end loop;
            if Sl = 0 or else Sl = V'First or else Sl = Ref_At - 1 then
               return;
            end if;
            Nl := Sl;
            while Nl < Ref_At - 1 and then V (Nl + 1) /= '/' loop
               Nl := Nl + 1;
            end loop;
            declare
               Name : constant String := V (V'First .. Nl);
               Ref  : constant String := V (Ref_At + 1 .. V'Last);
            begin
               if Name'Length > Types.Max_Desc_Str
                 or else Ref'Length > Types.Max_Desc_Str
               then
                  return;
               end if;
               if Name_In_Graph (Graph, Name) then
                  return;
               end if;
               Append_Dependency
                 (Graph,
                  Name,
                  Ref,
                  "",
                  "GitHub Actions workflow action",
                  "pkg:github/" & Name & "@" & Ref,
                  1,
                  False,
                  Types.Scope_Dev,
                  "YAML");
            end;
         end;
      end;
   end Register_Line;

   --  Scan one workflow or action file for `uses:` references.
   --  @param Path  Path of the YAML file to read.
   procedure Scan (Path : String) is
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
         Adacovex.Parsers.Read_Line (F, Path, Line_Num, Line, Last, Overflow);
         if Overflow then
            --  A line longer than Max_Line stops the scan of this file, so
            --  a truncated file never yields a partial action set.
            Close (F);
            return;
         end if;
         Register_Line (Line (1 .. Last));
      end loop;
      Close (F);
   exception
      when others =>
         if Is_Open (F) then
            Close (F);
         end if;
   end Scan;

   --  Scan every YAML file directly inside Dir.
   --  @param Dir  Directory to scan (not descended into).
   procedure Scan_Dir (Dir : String) is
      use Ada.Directories;
      Search : Search_Type;
      Ent    : Directory_Entry_Type;
   begin
      if Dir'Length = 0 or else not Exists (Dir) then
         return;
      end if;
      Start_Search (Search, Dir, "*");
      while More_Entries (Search) loop
         Get_Next_Entry (Search, Ent);
         if Kind (Ent) = Ordinary_File then
            declare
               N : constant String := Simple_Name (Ent);
            begin
               if N'Length > 4
                 and then (N (N'Last - 3 .. N'Last) = ".yml"
                           or else N (N'Last - 4 .. N'Last) = ".yaml")
               then
                  Scan (Full_Name (Ent));
               end if;
            end;
         end if;
      end loop;
      End_Search (Search);
   exception
      when others =>
         return;
   end Scan_Dir;

begin
   Scan_Dir (Target_Dir & "/.github/workflows");
   --  A composite action declares its steps with the same `uses:` key, so
   --  the repository's own action files are part of the same dependency
   --  set.
   declare
      Yaml : constant String := Target_Dir & "/action.yml";
      Alt  : constant String := Target_Dir & "/action.yaml";
   begin
      if Ada.Directories.Exists (Yaml) then
         Scan (Yaml);
      elsif Ada.Directories.Exists (Alt) then
         Scan (Alt);
      end if;
   end;
end Discover_Workflow_Actions;
