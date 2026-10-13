separate (Adacovex.Parsers.Manifest)
--  The version pnpm-lock.yaml's root importer (".") records for Name in
--  its dependencies or devDependencies blocks: the resolved version with
--  the peer-suffix stripped ("4.4.3(supports-color@8.1.1)" gives
--  "4.4.3"), "" when the lockfile lists no such entry, when the value is
--  not a plain version (link:, file:, workspace:, a git URL), or when the
--  file is unreadable. The parse is structural: it walks the YAML by
--  indentation -- the importers header, importer keys, the root
--  importer's dependency sections, dependency keys, and their field
--  lines -- never by substring, so a dependency whose name contains
--  "version" or a section of another importer cannot match. A physical
--  line longer than Max_Line fails loudly through Read_Line and yields
--  "".
--  @param Path  Path of the pnpm-lock.yaml file.
--  @param Name  Dependency name to look up.
--  @return The resolved version, or "" when absent.
function Pnpm_Importer_Version (Path : String; Name : String) return String is
   use Ada.Text_IO;
   F        : File_Type;
   Line     : String (1 .. Types.Max_Line);
   Last     : Natural;
   Overflow : Boolean;
   Line_Num : Natural := 0;

   --  Indentation of the importer keys, of the root importer's dependency
   --  sections, and of the dependency keys, in YAML nesting order. Zero
   --  means the level has not been seen yet.
   A         : Natural := 0;
   B         : Natural := 0;
   C_Indent  : Natural := 0;
   In_Import : Boolean := False;
   In_Root   : Boolean := False;
   In_Deps   : Boolean := False;
   Matched   : Boolean := False;

   function Trim_Spaces (S : String) return String is
   begin
      return Trim (S);
   end Trim_Spaces;

   --  The indentation of T (leading blanks and tabs).
   function Indent_Of (T : String) return Natural is
      N : Natural := 0;
   begin
      for I in T'Range loop
         exit when T (I) /= ' ' and then T (I) /= ASCII.HT;
         N := N + 1;
      end loop;
      return N;
   end Indent_Of;

   --  The mapping key of a key line: the trimmed text without its
   --  trailing colon, with optional surrounding quotes stripped
   --  ('@scope/pkg': and zod: both give the bare name).
   function Strip_Key (T : String) return String is
      R : constant String := T (T'First .. T'Last - 1);
   begin
      if R'Length >= 2
        and then ((R (R'First) = ''' and then R (R'Last) = ''')
                  or else (R (R'First) = '"' and then R (R'Last) = '"'))
      then
         return R (R'First + 1 .. R'Last - 1);
      end if;
      return R;
   end Strip_Key;

   --  Whether T starts with the literal Prefix.
   function Starts_With (T : String; Prefix : String) return Boolean is
   begin
      return
        T'Length >= Prefix'Length
        and then T (T'First .. T'First + Prefix'Length - 1) = Prefix;
   end Starts_With;
begin
   if Name'Length = 0 then
      return "";
   end if;
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
         T   : constant String := Trim_Spaces (Line (Line'First .. Last));
         Ind : constant Natural := Indent_Of (Line (Line'First .. Last));
      begin
         if T'Length = 0 or else T (T'First) = '#' then
            null;
         elsif not In_Import then
            if Ind = 0 and then T = "importers:" then
               In_Import := True;
            end if;
         elsif Ind = 0 then
            --  A top-level key ends the importers section.
            exit;
         elsif A = 0 then
            --  The first indented key line is an importer key.
            A := Ind;
            In_Root := Strip_Key (T) = ".";
         elsif Ind = A then
            --  Another importer key: reset the section state.
            In_Root := Strip_Key (T) = ".";
            In_Deps := False;
            Matched := False;
            C_Indent := 0;
         elsif not In_Root then
            null;
         elsif T (T'Last) = ':' then
            --  A mapping key inside the root importer: a dependency
            --  section header, or a dependency name.
            declare
               K : constant String := Strip_Key (T);
            begin
               if K = "dependencies" or else K = "devDependencies" then
                  B := Ind;
                  In_Deps := True;
                  Matched := False;
                  C_Indent := 0;
               elsif In_Deps and then Ind > B then
                  C_Indent := Ind;
                  Matched := K = Name;
               else
                  --  Any other section (peerDependencies, patches, ...)
                  --  ends the dependency scan.
                  In_Deps := False;
                  Matched := False;
               end if;
            end;
         elsif In_Deps
           and then Matched
           and then Ind > C_Indent
           and then Starts_With (T, "version:")
         then
            --  The version field of the matched dependency: the first
            --  run of non-blank, non-parenthesis characters after the
            --  colon, when it starts with a digit.
            declare
               V1 : Natural := 0;
               V2 : Natural := 0;
            begin
               --  The value starts after the 8-character "version:"
               --  prefix (Starts_With already checked it).
               for I in T'First + 8 .. T'Last loop
                  if T (I) /= ' ' and then T (I) /= ASCII.HT then
                     V1 := I;
                     exit;
                  end if;
               end loop;
               if V1 > 0 and then T (V1) in '0' .. '9' then
                  V2 := V1;
                  for I in V1 + 1 .. T'Last loop
                     exit when
                       T (I) = ' '
                       or else T (I) = ASCII.HT
                       or else T (I) = '(';
                     V2 := I;
                  end loop;
                  Close (F);
                  return T (V1 .. V2);
               end if;
            end;
         end if;
      end;
   end loop;
   Close (F);
   return "";
exception
   when others =>
      if Is_Open (F) then
         Close (F);
      end if;
      return "";
end Pnpm_Importer_Version;
