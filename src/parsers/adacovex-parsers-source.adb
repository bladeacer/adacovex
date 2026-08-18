with Ada.Text_IO;
with Ada.Directories;
with Ada.Containers.Vectors;
with Adacovex.Cache;

package body Adacovex.Parsers.Source is

   package Package_Store is new
     Adacovex.Cache.Serialization (Types.Implementation.Package_Info);

   --  True when S, starting at Pos, equals the keyword Kw and is followed by
   --  a non-identifier character (or end of string), so `procedure_X` and
   --  `functionality` never match `procedure` / `function`.
   function Match_Keyword
     (S : String; Pos : Natural; Kw : String) return Boolean
   is
      Nxt : Natural;
   begin
      if Pos < S'First or else Pos + Kw'Length - 1 > S'Last then
         return False;
      end if;
      if S (Pos .. Pos + Kw'Length - 1) /= Kw then
         return False;
      end if;
      Nxt := Pos + Kw'Length;
      if Nxt > S'Last then
         return True;
      end if;
      return
        S (Nxt) not in 'a' .. 'z'
        and then S (Nxt) not in 'A' .. 'Z'
        and then S (Nxt) not in '0' .. '9'
        and then S (Nxt) /= '_';
   end Match_Keyword;

   --  Advance Pos past blanks (space or tab); stops at the first non-blank
   --  character or at the end of S.
   procedure Skip_Blanks (S : String; Pos : in out Natural) is
   begin
      while Pos <= S'Last and then (S (Pos) = ' ' or else S (Pos) = ASCII.HT)
      loop
         Pos := Pos + 1;
      end loop;
   end Skip_Blanks;

   function Is_Subprogram_Decl (Line : String) return Boolean is
      Pos : Natural := Line'First;
   begin
      Skip_Blanks (Line, Pos);

      --  Optional object-oriented modifiers.
      if Match_Keyword (Line, Pos, "overriding") then
         Pos := Pos + 10;
         Skip_Blanks (Line, Pos);
      elsif Match_Keyword (Line, Pos, "not") then
         Pos := Pos + 3;
         Skip_Blanks (Line, Pos);
         if Match_Keyword (Line, Pos, "overriding") then
            Pos := Pos + 10;
            Skip_Blanks (Line, Pos);
         end if;
      end if;

      --  Optional single-line generic keyword.
      if Match_Keyword (Line, Pos, "generic") then
         Pos := Pos + 7;
         Skip_Blanks (Line, Pos);
      end if;

      return
        Match_Keyword (Line, Pos, "procedure")
        or else Match_Keyword (Line, Pos, "function");
   end Is_Subprogram_Decl;

   function Has_HLR_Tag
     (Line : String; Tag : out String; Tag_Len : out Natural) return Boolean
   is
      In_Comment : Boolean := False;
      H_Start    : Natural := 0;
      H_End      : Natural := 0;
   begin
      Tag_Len := 0;
      for I in Line'Range loop
         if not In_Comment then
            if I < Line'Last - 1
              and then Line (I) = '-'
              and then Line (I + 1) = '-'
            then
               In_Comment := True;
            end if;
         else
            if Line (I) = '-' then
               null;
            elsif Line (I) = ' ' then
               null;
            else
               for J in I .. Line'Last - 3 loop
                  if J > I and then Line (J - 1) in 'A' .. 'Z' then
                     null;
                  elsif Line (J) = 'H' and then Line (J .. J + 3) = "HLR-" then
                     H_Start := J;
                     exit;
                  end if;
               end loop;

               if H_Start > 0 then
                  for J in H_Start + 4 .. Line'Last loop
                     if Line (J) = ' ' or else Line (J) = ':' then
                        H_End := J - 1;
                        exit;
                     end if;
                     if J = Line'Last then
                        H_End := J;
                     end if;
                  end loop;

                  if H_End > H_Start + 3 then
                     --  Clamp to the caller's fixed buffer (Max_Id_Str) so a
                     --  malformed tag longer than the buffer never overruns;
                     --  Tag_Len reflects the clamped length so downstream
                     --  comparisons stay in bounds.
                     Tag_Len :=
                       Natural'Min (H_End - (H_Start + 4) + 1, Tag'Length);
                     declare
                        Valid : Boolean := True;
                     begin
                        for CI in 1 .. Tag_Len loop
                           declare
                              C : constant Character :=
                                Line (H_Start + 4 + CI - 1);
                           begin
                              if C not in 'A' .. 'Z'
                                and then C not in '0' .. '9'
                                and then C /= '-'
                              then
                                 Valid := False;
                                 exit;
                              end if;
                           end;
                        end loop;
                        if not Valid then
                           return False;
                        end if;
                     end;
                     for J in 1 .. Tag_Len loop
                        Tag (J) := Line (H_Start + 4 + J - 1);
                     end loop;
                     return True;
                  end if;
               end if;
               return False;
            end if;
         end if;
      end loop;
      return False;
   end Has_HLR_Tag;

   function Has_Docstring_Tag
     (Line    : String;
      Dtype   : out String;
      Dtype_L : out Natural;
      Value   : out String;
      Val_L   : out Natural) return Boolean
   is
      In_Comment : Boolean := False;
      Start      : Natural := 0;
   begin
      Dtype_L := 0;
      Val_L := 0;
      for I in Line'Range loop
         if not In_Comment then
            if I < Line'Last - 1
              and then Line (I) = '-'
              and then Line (I + 1) = '-'
            then
               In_Comment := True;
            end if;
         else
            if Line (I) = '@' then
               Start := I + 1;
               for J in Start .. Line'Last loop
                  if Line (J) = ' ' then
                     Dtype_L := Natural'Min (J - Start, Dtype'Length);
                     for K in 1 .. Dtype_L loop
                        Dtype (K) := Line (Start + K - 1);
                     end loop;
                     for K in J + 1 .. Line'Last loop
                        if Line (K) /= ' ' then
                           Val_L :=
                             Natural'Min (Line'Last - K + 1, Value'Length);
                           for L in 1 .. Val_L loop
                              Value (L) := Line (K + L - 1);
                           end loop;
                           exit;
                        end if;
                     end loop;
                     return True;
                  end if;
                  if J = Line'Last then
                     Dtype_L := Natural'Min (J - Start + 1, Dtype'Length);
                     for K in 1 .. Dtype_L loop
                        Dtype (K) := Line (Start + K - 1);
                     end loop;
                     return True;
                  end if;
               end loop;
            end if;
         end if;
      end loop;
      return False;
   end Has_Docstring_Tag;

   --  True when Line is a docstring summary line: an Ada comment (`--`)
   --  followed by at least one space or tab and then at least one non-blank
   --  character.  Accepts both the canonical `--  ` prefix and the common
   --  single-space `-- ` / tab-separated styles found in generated code.
   --  A bare `--` or `---` (three dashes) is not a docstring.
   function Is_Docstring_Line (Line : String) return Boolean is
   begin
      for I in Line'First .. Line'Last - 1 loop
         if Line (I) = '-' and then Line (I + 1) = '-' then
            if I + 1 < Line'Last then
               if Line (I + 2) /= ' ' and then Line (I + 2) /= ASCII.HT then
                  return False;
               end if;
               for J in I + 2 .. Line'Last loop
                  if Line (J) /= ' ' and then Line (J) /= ASCII.HT then
                     return True;
                  end if;
               end loop;
            end if;
            return False;
         end if;
      end loop;
      return False;
   end Is_Docstring_Line;

   --  True when the comment portion of Line contains a Sphinx
   --  (reStructuredText) field-list entry of the form ":Keyword" where
   --  Keyword is followed by a space (":param name:") or a colon
   --  (":returns:").  The scan is restricted to Ada comment text.
   function Has_Sphinx_Field (Line : String; Keyword : String) return Boolean
   is
      In_Comment : Boolean := False;
   begin
      for I in Line'First .. Line'Last - 1 loop
         if not In_Comment then
            if Line (I) = '-' and then Line (I + 1) = '-' then
               In_Comment := True;
            end if;
         elsif I + Keyword'Length <= Line'Last then
            if Line (I) = ':'
              and then Line (I + 1 .. I + Keyword'Length) = Keyword
            then
               declare
                  Nxt : constant Natural := I + Keyword'Length + 1;
               begin
                  if Nxt > Line'Last
                    or else Line (Nxt) = ' '
                    or else Line (Nxt) = ':'
                  then
                     return True;
                  end if;
               end;
            end if;
         end if;
      end loop;
      return False;
   end Has_Sphinx_Field;

   --  True when the comment portion of Line contains a Google-style section
   --  header, i.e. "Section:" (Args:, Returns:, ...) as comment text.
   function Has_Google_Section (Line : String; Section : String) return Boolean
   is
      In_Comment : Boolean := False;
   begin
      for I in Line'First .. Line'Last - 1 loop
         if not In_Comment then
            if Line (I) = '-' and then Line (I + 1) = '-' then
               In_Comment := True;
            end if;
         elsif I + Section'Length <= Line'Last then
            if Line (I .. I + Section'Length - 1) = Section
              and then Line (I + Section'Length) = ':'
            then
               return True;
            end if;
         end if;
      end loop;
      return False;
   end Has_Google_Section;

   --  Number of leading space/tab characters between the `--` marker and the
   --  first non-blank character of an Ada comment line, or -1 when Line is
   --  not such a comment line.  A canonical `--  text` line yields 2.
   function Comment_Indent (Line : String) return Integer is
   begin
      for I in Line'First .. Line'Last - 1 loop
         if Line (I) = '-' and then Line (I + 1) = '-' then
            if I + 2 > Line'Last then
               return -1;
            end if;
            declare
               J : Natural := I + 2;
            begin
               while J <= Line'Last
                 and then (Line (J) = ' ' or else Line (J) = ASCII.HT)
               loop
                  J := J + 1;
               end loop;
               if J > Line'Last then
                  return -1;
               end if;
               return J - (I + 2);
            end;
         end if;
      end loop;
      return -1;
   end Comment_Indent;

   procedure Scan_Ads_File
     (File_Path : String;
      Pkg       : out Types.Implementation.Package_Info;
      Success   : out Boolean)
   is
      use Ada.Text_IO;
      F        : File_Type;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Overflow : Boolean;
      Pkg_Name : Types.Name_Field;
      Pkg_NLen : Natural := 0;
      HLR_Buf  : String (1 .. Types.Max_Id_Str);
      HLR_Len  : Natural;
      DT_Type  : String (1 .. 64);
      DT_Len   : Natural;
      DT_Value : String (1 .. Types.Max_Desc_Str);
      DV_Len   : Natural;
      Line_Num : Natural := 0;
      In_Subp  : Boolean := False;

      Pending_Has_Doc    : Boolean := False;
      Pending_Param_Ct   : Natural := 0;
      Pending_Has_Return : Boolean := False;

      In_Google_Args     : Boolean := False;
      Google_Args_Indent : Integer := 0;

      procedure Flush_Pending is
      begin
         if Pending_Has_Doc and then Integer (Pkg.Subprograms.Length) > 0 then
            declare
               Idx : constant Positive := Positive (Pkg.Subprograms.Length);
            begin
               declare
                  Subp : Types.Subprogram_Info := Pkg.Subprograms (Idx);
               begin
                  Subp.Has_Docstring := True;
                  Subp.Doc_Param_Ct := Subp.Doc_Param_Ct + Pending_Param_Ct;
                  if Pending_Has_Return then
                     Subp.Doc_Return := True;
                  end if;
                  Pkg.Subprograms.Replace_Element (Idx, Subp);
               end;
            end;
            Pending_Has_Doc := False;
            Pending_Param_Ct := 0;
            Pending_Has_Return := False;
         end if;
      end Flush_Pending;
   begin
      Pkg := (others => <>);

      -- Extract package name from path
      declare
         Base : constant String := Ada.Directories.Simple_Name (File_Path);
      begin
         Pkg_NLen := 0;
         for I in Base'Range loop
            if Base (I) = '.' then
               exit;
            end if;
            Pkg_NLen := Pkg_NLen + 1;
            Pkg_Name (Pkg_NLen) := Base (I);
         end loop;
      end;

      Pkg.Name_Len := Pkg_NLen;
      for I in 1 .. Pkg_NLen loop
         Pkg.Name (I) := Pkg_Name (I);
      end loop;
      Pkg.Path_Len := File_Path'Length;
      for I in File_Path'Range loop
         Pkg.File_Path (I - File_Path'First + 1) := File_Path (I);
      end loop;

      begin
         Open (F, In_File, File_Path);
      exception
         when others =>
            Success := False;
            return;
      end;

      begin
         while not End_Of_File (F) loop
            Line_Num := Line_Num + 1;
            Adacovex.Parsers.Read_Line
              (F, File_Path, Line_Num, Line, Last, Overflow);
            if Overflow then
               --  A physical line longer than Max_Line is drained and
               --  reported by Read_Line; parsing stops so no partial AST is
               --  passed downstream.
               Close (F);
               Success := False;
               return;
            end if;

            if Has_HLR_Tag (Line (1 .. Last), HLR_Buf, HLR_Len) then
               if not In_Subp then
                  declare
                     Elem : Types.HLR_Tag_Entry;
                  begin
                     for I in 1 .. HLR_Len loop
                        Elem.Tag (I) := HLR_Buf (I);
                     end loop;
                     Elem.Len := HLR_Len;
                     Pkg.HLR_Tags.Append (Elem);
                  end;
               end if;
            end if;

            if Is_Subprogram_Decl (Line (1 .. Last)) then
               Pkg.Subprograms.Append
                 (New_Item => Types.Subprogram_Info'(others => <>));
               declare
                  Subp_Idx : constant Positive :=
                    Positive (Pkg.Subprograms.Length);
               begin
                  Pkg.Subprograms (Subp_Idx).Line_Number := Line_Num;
                  Flush_Pending;
                  In_Subp := True;

                  declare
                     L     : constant String := Line (1 .. Last);
                     Pos   : Natural := L'First;
                     SName : String (1 .. Types.Max_Desc_Str);
                     SNLen : Natural := 0;
                  begin
                     --  Skip the leading keywords Is_Subprogram_Decl already
                     --  validated (modifiers, generic, procedure/function) to
                     --  reach the subprogram name.  Working on the raw line
                     --  (blanks intact) keeps the name from merging with a
                     --  following `return` keyword.
                     Skip_Blanks (L, Pos);
                     if Match_Keyword (L, Pos, "overriding") then
                        Pos := Pos + 10;
                        Skip_Blanks (L, Pos);
                     end if;
                     if Match_Keyword (L, Pos, "not") then
                        Pos := Pos + 3;
                        Skip_Blanks (L, Pos);
                        if Match_Keyword (L, Pos, "overriding") then
                           Pos := Pos + 10;
                           Skip_Blanks (L, Pos);
                        end if;
                     end if;
                     if Match_Keyword (L, Pos, "generic") then
                        Pos := Pos + 7;
                        Skip_Blanks (L, Pos);
                     end if;
                     if Match_Keyword (L, Pos, "procedure") then
                        Pos := Pos + 9;
                     elsif Match_Keyword (L, Pos, "function") then
                        Pos := Pos + 8;
                     end if;
                     Skip_Blanks (L, Pos);

                     --  Collect the identifier at Pos, clamped to the fixed
                     --  buffer; the scan still consumes the full identifier
                     --  so following tokens are not misparsed.
                     while Pos <= L'Last
                       and then L (Pos)
                                in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_'
                     loop
                        if SNLen < SName'Length then
                           SNLen := SNLen + 1;
                           SName (SNLen) := L (Pos);
                        end if;
                        Pos := Pos + 1;
                     end loop;

                     Pkg.Subprograms (Subp_Idx).Name_Len := SNLen;
                     for J in 1 .. SNLen loop
                        Pkg.Subprograms (Subp_Idx).Name (J) := SName (J);
                     end loop;
                  end;
               end;
            end if;

            if Has_Docstring_Tag
                 (Line (1 .. Last), DT_Type, DT_Len, DT_Value, DV_Len)
            then
               if DT_Len >= 5 and then DT_Type (1 .. 5) = "param" then
                  Pending_Has_Doc := True;
                  Pending_Param_Ct := Pending_Param_Ct + 1;
               elsif DT_Len >= 6 and then DT_Type (1 .. 6) = "return" then
                  Pending_Has_Doc := True;
                  Pending_Has_Return := True;
               elsif DT_Len >= 5 and then DT_Type (1 .. 5) = "field" then
                  Pending_Has_Doc := True;
               elsif DT_Len >= 6 and then DT_Type (1 .. 6) = "formal" then
                  null;
               elsif DT_Len >= 5 and then DT_Type (1 .. 5) = "brief" then
                  Pending_Has_Doc := True;
               elsif DT_Len >= 7 and then DT_Type (1 .. 7) = "summary" then
                  Pending_Has_Doc := True;
               end if;
            elsif Is_Docstring_Line (Line (1 .. Last)) then
               Pending_Has_Doc := True;
            end if;

            --  Sphinx-style reST field lists: ":param X: ..." and
            --  ":returns: ..." inside comments.
            if Has_Sphinx_Field (Line (1 .. Last), "param")
              or else Has_Sphinx_Field (Line (1 .. Last), "parameter")
            then
               Pending_Has_Doc := True;
               Pending_Param_Ct := Pending_Param_Ct + 1;
            elsif Has_Sphinx_Field (Line (1 .. Last), "return")
              or else Has_Sphinx_Field (Line (1 .. Last), "returns")
            then
               Pending_Has_Doc := True;
               Pending_Has_Return := True;
            elsif Has_Sphinx_Field (Line (1 .. Last), "type")
              or else Has_Sphinx_Field (Line (1 .. Last), "rtype")
            then
               Pending_Has_Doc := True;
            end if;

            --  Google-style "Args:" / "Returns:" sections.  An "Args:"
            --  header opens a block; deeper-indented comment lines within
            --  it count as parameter entries until the indent returns to
            --  the header level (or the block is closed by a declaration).
            declare
               Ind : constant Integer := Comment_Indent (Line (1 .. Last));
            begin
               if Has_Google_Section (Line (1 .. Last), "Args") then
                  Pending_Has_Doc := True;
                  In_Google_Args := True;
                  Google_Args_Indent := Ind;
               elsif In_Google_Args and then Ind > Google_Args_Indent then
                  Pending_Has_Doc := True;
                  Pending_Param_Ct := Pending_Param_Ct + 1;
               elsif In_Google_Args then
                  In_Google_Args := False;
               end if;
            end;
            if Has_Google_Section (Line (1 .. Last), "Returns") then
               Pending_Has_Doc := True;
               Pending_Has_Return := True;
            end if;
         end loop;
         Flush_Pending;
         Close (F);
      exception
         when others =>
            Close (F);
            raise;
      end;

      Success := True;
   end Scan_Ads_File;

   function Is_Skipped_Dir (Name : String; Skip_List : String) return Boolean
   is
      Start : Natural := Skip_List'First;
   begin
      if Name'Length = 0 or else Skip_List'Length = 0 then
         return False;
      end if;
      loop
         declare
            End_Pos : Natural := Start;
            Seg     : String (1 .. Types.Max_Filename);
            Seg_Len : Natural := 0;
         begin
            while End_Pos <= Skip_List'Last and then Skip_List (End_Pos) /= ','
            loop
               if Seg_Len < Types.Max_Filename then
                  Seg_Len := Seg_Len + 1;
                  Seg (Seg_Len) := Skip_List (End_Pos);
               end if;
               End_Pos := End_Pos + 1;
            end loop;
            if Seg_Len = Name'Length then
               declare
                  Match : Boolean := True;
               begin
                  for I in 1 .. Seg_Len loop
                     if Seg (I) /= Name (Name'First + I - 1) then
                        Match := False;
                        exit;
                     end if;
                  end loop;
                  if Match then
                     return True;
                  end if;
               end;
            end if;
            exit when End_Pos >= Skip_List'Last;
            Start := End_Pos + 1;
         end;
      end loop;
      return False;
   end Is_Skipped_Dir;

   procedure Scan_Project
     (Target_Dir : String;
      Skip_List  : String;
      Packages   : in out Types.Implementation.Package_Vectors.Vector;
      Skipped_Ct : out Natural)
   is
      type Dir_Entry is record
         Path : Types.Path_Field;
         Len  : Natural := 0;
      end record;
      package Dir_Stacks is new Ada.Containers.Vectors (Positive, Dir_Entry);
      Dir_Stack : Dir_Stacks.Vector;

      use Ada.Directories;
      Search : Search_Type;
      Ent    : Directory_Entry_Type;
      Pkg    : Types.Implementation.Package_Info;
      OK     : Boolean;

      procedure Push_Dir (Dir : String) is
      begin
         if Dir'Length <= Types.Max_Path then
            declare
               Item : Dir_Entry;
            begin
               Item.Len := Dir'Length;
               for I in Dir'Range loop
                  Item.Path (I - Dir'First + 1) := Dir (I);
               end loop;
               Dir_Stack.Append (Item);
            end;
         else
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "Error: "
               & Dir
               & ": directory path exceeds Max_Path buffer; subtree not scanned");
         end if;
      end Push_Dir;

   begin
      Skipped_Ct := 0;
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
                  begin
                     if Kind (Ent) = Directory then
                        if Name /= "."
                          and Name /= ".."
                          and Name /= ".git"
                          and Name /= "obj"
                          and Name /= "tests"
                          and Name /= "config"
                          and Name /= ".adacovex"
                          and not Is_Skipped_Dir (Name, Skip_List)
                        then
                           Push_Dir (Path);
                        end if;
                     elsif Kind (Ent) = Ordinary_File then
                        declare
                           Dot : Natural := 0;
                        begin
                           for I in reverse Name'Range loop
                              if Name (I) = '.' then
                                 Dot := I;
                                 exit;
                              end if;
                           end loop;
                           if Dot > 0
                             and then Name (Dot .. Name'Last) = ".ads"
                             and then (Name'Length < 3
                                       or else Name
                                                 (Name'First .. Name'First + 2)
                                               /= "b__")
                           then
                              if Path'Length > Types.Max_Path then
                                 Ada.Text_IO.Put_Line
                                   (Ada.Text_IO.Standard_Error,
                                    "Error: "
                                    & Path
                                    & ": file path exceeds Max_Path buffer; "
                                    & "file not scanned");
                                 Skipped_Ct := Skipped_Ct + 1;
                              else
                                 Scan_Ads_File (Path, Pkg, OK);
                                 if OK then
                                    Packages.Append (Pkg);
                                 else
                                    Skipped_Ct := Skipped_Ct + 1;
                                 end if;
                              end if;
                           end if;
                        end;
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
   end Scan_Project;

   function Is_Prefix (Pre, S : String) return Boolean is
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
   end Is_Prefix;

   function Relative_Path (Full_Path, Root : String) return String is
   begin
      if Is_Prefix (Root, Full_Path)
        and then Full_Path'Length > Root'Length + 1
        and then Full_Path (Root'Length + 1) = '/'
      then
         return Full_Path (Root'Length + 2 .. Full_Path'Last);
      end if;
      return "";
   end Relative_Path;

   procedure Apply_Patches
     (Target_Dir : String;
      Packages   : in out Types.Implementation.Package_Vectors.Vector)
   is
      Patch_Dir : constant String := Target_Dir & "/.adacovex/patches";
      OK        : Boolean;
   begin
      if not Ada.Directories.Exists (Patch_Dir) then
         return;
      end if;
      for P in 1 .. Integer (Packages.Length) loop
         declare
            Pkg_Path : String renames
              Packages (P).File_Path (1 .. Packages (P).Path_Len);
            Rel      : constant String := Relative_Path (Pkg_Path, Target_Dir);
            Tmp_Pkg  : Types.Implementation.Package_Info;
            Pkg_Copy : Types.Implementation.Package_Info := Packages (P);
         begin
            if Rel'Length > 0 then
               declare
                  Patch : constant String := Patch_Dir & "/" & Rel;
               begin
                  if Ada.Directories.Exists (Patch) then
                     Scan_Ads_File (Patch, Tmp_Pkg, OK);
                     if OK and then Integer (Tmp_Pkg.Subprograms.Length) > 0
                     then
                        for S in 1 .. Integer (Tmp_Pkg.Subprograms.Length) loop
                           for O in 1 .. Integer (Pkg_Copy.Subprograms.Length)
                           loop
                              if Tmp_Pkg.Subprograms (S).Name_Len
                                = Pkg_Copy.Subprograms (O).Name_Len
                              then
                                 declare
                                    Matches : Boolean := True;
                                 begin
                                    for C in
                                      1 .. Tmp_Pkg.Subprograms (S).Name_Len
                                    loop
                                       if Tmp_Pkg.Subprograms (S).Name (C)
                                         /= Pkg_Copy.Subprograms (O).Name (C)
                                       then
                                          Matches := False;
                                          exit;
                                       end if;
                                    end loop;
                                    if Matches
                                      and then not Pkg_Copy.Subprograms (O)
                                                     .Has_Docstring
                                    then
                                       if Tmp_Pkg.Subprograms (S).Has_Docstring
                                       then
                                          Pkg_Copy.Subprograms (O)
                                            .Has_Docstring :=
                                            True;
                                          Pkg_Copy.Subprograms (O)
                                            .Doc_Param_Ct :=
                                            Tmp_Pkg.Subprograms (S)
                                              .Doc_Param_Ct;
                                          Pkg_Copy.Subprograms (O)
                                            .Doc_Return :=
                                            Tmp_Pkg.Subprograms (S).Doc_Return;
                                       end if;
                                       exit;
                                    end if;
                                 end;
                              end if;
                           end loop;
                        end loop;
                        Packages.Replace_Element (P, Pkg_Copy);
                     end if;
                  end if;
               end;
            end if;
         end;
      end loop;
   end Apply_Patches;

   function Compute_Docstring_Metrics
     (Packages : Types.Implementation.Package_Vectors.Vector)
      return Types.Docstring_Metrics
   is
      Metrics : Types.Docstring_Metrics;
   begin
      for P in 1 .. Integer (Packages.Length) loop
         for S in 1 .. Integer (Packages (P).Subprograms.Length) loop
            Metrics.Total_Subprograms := Metrics.Total_Subprograms + 1;
            if Packages (P).Subprograms (S).Has_Docstring then
               Metrics.Documented_Subprogs := Metrics.Documented_Subprogs + 1;
            end if;
         end loop;
      end loop;

      if Metrics.Total_Subprograms > 0 then
         Metrics.Coverage_Pct :=
           (Metrics.Documented_Subprogs * 100) / Metrics.Total_Subprograms;
      end if;

      return Metrics;
   end Compute_Docstring_Metrics;

   procedure Scan_Project_Cached
     (Target_Dir : String;
      Skip_List  : String;
      Packages   : in out Types.Implementation.Package_Vectors.Vector;
      Skipped_Ct : out Natural;
      Hits       : out Natural;
      Misses     : out Natural;
      Use_Cache  : Boolean := True)
   is
      type Dir_Entry is record
         Path : Types.Path_Field;
         Len  : Natural := 0;
      end record;
      package Dir_Stacks is new Ada.Containers.Vectors (Positive, Dir_Entry);
      Dir_Stack : Dir_Stacks.Vector;

      use Ada.Directories;
      Search : Search_Type;
      Ent    : Directory_Entry_Type;
      Pkg    : Types.Implementation.Package_Info;
      OK     : Boolean;
      Key    : String (1 .. 72);
      Key_L  : Natural;
      Blob   : String (1 .. Adacovex.Cache.Max_Cache_Blob);
      Blen   : Natural;
      Found  : Boolean;

      procedure Push_Dir (Dir : String) is
      begin
         if Dir'Length <= Types.Max_Path then
            declare
               Item : Dir_Entry;
            begin
               Item.Len := Dir'Length;
               for I in Dir'Range loop
                  Item.Path (I - Dir'First + 1) := Dir (I);
               end loop;
               Dir_Stack.Append (Item);
            end;
         else
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "Error: "
               & Dir
               & ": directory path exceeds Max_Path buffer; subtree not scanned");
         end if;
      end Push_Dir;

   begin
      Hits := 0;
      Misses := 0;
      Skipped_Ct := 0;
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
                  begin
                     if Kind (Ent) = Directory then
                        if Name /= "."
                          and Name /= ".."
                          and Name /= ".git"
                          and Name /= "obj"
                          and Name /= "tests"
                          and Name /= "config"
                          and Name /= ".adacovex"
                          and not Is_Skipped_Dir (Name, Skip_List)
                        then
                           Push_Dir (Path);
                        end if;
                     elsif Kind (Ent) = Ordinary_File then
                        declare
                           Dot : Natural := 0;
                        begin
                           for I in reverse Name'Range loop
                              if Name (I) = '.' then
                                 Dot := I;
                                 exit;
                              end if;
                           end loop;
                           if Dot > 0
                             and then Name (Dot .. Name'Last) = ".ads"
                             and then (Name'Length < 3
                                       or else Name
                                                 (Name'First .. Name'First + 2)
                                               /= "b__")
                           then
                              if Path'Length > Types.Max_Path then
                                 Ada.Text_IO.Put_Line
                                   (Ada.Text_IO.Standard_Error,
                                    "Error: "
                                    & Path
                                    & ": file path exceeds Max_Path buffer; "
                                    & "file not scanned");
                                 Skipped_Ct := Skipped_Ct + 1;
                              else
                                 if Use_Cache then
                                    declare
                                       F_Hash : constant String :=
                                         Adacovex.Cache.Hash_File (Path);
                                    begin
                                       if F_Hash'Length >= 3 then
                                          --  Sized cache key: "scan:" + sha256.
                                          Key (1 .. 5) := "scan:";
                                          Key (6 .. 5 + F_Hash'Length) :=
                                            F_Hash;
                                          Key_L := 5 + F_Hash'Length;
                                          Adacovex.Cache.Get_Cached
                                            (Key (1 .. Key_L),
                                             Blob,
                                             Blen,
                                             Found);
                                          if Found then
                                             if Package_Store.Deserialize
                                                  (Blob (1 .. Blen), Pkg)
                                             then
                                                --  The blob is keyed by file
                                                --  content, so it may have
                                                --  been cached from a different
                                                --  directory (e.g. a
                                                --  --compare-base /
                                                --  --coverage-delta base
                                                --  snapshot). Rewrite the
                                                --  embedded absolute path to
                                                --  the file being scanned:
                                                --  Relative_Path consumers
                                                --  (patch application, HLR
                                                --  traceability, report paths)
                                                --  depend on it.
                                                Pkg.Path_Len :=
                                                  Path'Length;
                                                for I in Path'Range loop
                                                   Pkg.File_Path
                                                     (I - Path'First + 1) :=
                                                     Path (I);
                                                end loop;
                                                Packages.Append (Pkg);
                                                Hits := Hits + 1;
                                             else
                                                --  Corrupt blob: fall back to a
                                                --  fresh scan.
                                                Scan_Ads_File (Path, Pkg, OK);
                                                if OK then
                                                   Packages.Append (Pkg);
                                                   Misses := Misses + 1;
                                                else
                                                   Skipped_Ct :=
                                                     Skipped_Ct + 1;
                                                end if;
                                             end if;
                                          else
                                             Scan_Ads_File (Path, Pkg, OK);
                                             if OK then
                                                Packages.Append (Pkg);
                                                Misses := Misses + 1;
                                                declare
                                                   S_Blob : constant String :=
                                                     Package_Store.Serialize
                                                       (Pkg);
                                                begin
                                                   if S_Blob'Length > 0 then
                                                      Adacovex.Cache.Put_Cached
                                                        (Key (1 .. Key_L),
                                                         S_Blob,
                                                         OK);
                                                   end if;
                                                end;
                                             else
                                                Skipped_Ct := Skipped_Ct + 1;
                                             end if;
                                          end if;
                                       else
                                          --  Unhashable file (e.g. unreadable):
                                          --  scan directly.
                                          Scan_Ads_File (Path, Pkg, OK);
                                          if OK then
                                             Packages.Append (Pkg);
                                             Misses := Misses + 1;
                                          else
                                             Skipped_Ct := Skipped_Ct + 1;
                                          end if;
                                       end if;
                                    end;
                                 else
                                    --  Cache disabled (--no-cache): rescan.
                                    Scan_Ads_File (Path, Pkg, OK);
                                    if OK then
                                       Packages.Append (Pkg);
                                       Misses := Misses + 1;
                                    else
                                       Skipped_Ct := Skipped_Ct + 1;
                                    end if;
                                 end if;
                              end if;
                           end if;
                        end;
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
   end Scan_Project_Cached;

end Adacovex.Parsers.Source;
