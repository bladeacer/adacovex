separate (Adacovex.Parsers.Manifest)
--  Collect every module a go.mod's require directives declare, split into
--  the direct set and the `// indirect` set. The parse is structural: a
--  require directive opens the entry (a single-line `require <path>
--  <version>` or a `require (` group), the group ends at its closing
--  parenthesis, and the contents of a replace, exclude, retract, or tool
--  block are never read. A trailing comment is stripped before the entry
--  is tokenised, so `// indirect` classifies the module and never leaks
--  into the version. An entry contributes only when it carries both a
--  module path and a version, so a malformed or partial line adds
--  nothing. A physical line longer than Max_Line stops the read: the
--  entries collected so far stay, and the rest of the file is never
--  trusted. A missing or unreadable file collects nothing.
--  @param Path  Path of the go.mod file.
--  @param Direct  Modules the file requires directly (appended).
--  @param Indirect  Modules the file marks `// indirect` (appended).
procedure Collect_Go_Requires
  (Path     : String;
   Direct   : in out Go_Module_Vectors.Vector;
   Indirect : in out Go_Module_Vectors.Vector)
is
   use Ada.Text_IO;
   F        : File_Type;
   Line     : String (1 .. Types.Max_Line);
   Last     : Natural;
   Overflow : Boolean;
   Line_Num : Natural := 0;
   In_Block : Boolean := False;

   function Is_Blank (C : Character) return Boolean is
   begin
      return C = ' ' or else C = ASCII.HT or else C = ASCII.CR;
   end Is_Blank;

   --  Whether C continues an identifier (a module path, a version token,
   --  or the word "indirect"). The hyphen reads as a boundary here, so
   --  "non-indirect" still counts as indirect.
   --  @param C  Character to classify.
   --  @return True when C is a letter, a digit, or an underscore.
   function Is_Ident_Char (C : Character) return Boolean is
   begin
      return
        (C in 'a' .. 'z')
        or else (C in 'A' .. 'Z')
        or else (C in '0' .. '9')
        or else C = '_';
   end Is_Ident_Char;

   --  Index of the "//" that starts a trailing comment in T, 0 when there
   --  is none. A module path and a version never contain a slash pair, so
   --  the first one on the line always starts the comment.
   --  @param T  Text to scan.
   --  @return The comment start index, or 0.
   function Comment_Start (T : String) return Natural is
   begin
      if T'Length < 2 then
         return 0;
      end if;
      for I in T'First .. T'Last - 1 loop
         if T (I) = '/' and then T (I + 1) = '/' then
            return I;
         end if;
      end loop;
      return 0;
   end Comment_Start;

   --  Whether a stripped comment marks the entry as an indirect module
   --  (`// indirect`), as a whole word on both sides.
   --  @param Cmt  Comment text (may be empty).
   --  @return True when "indirect" appears as a word.
   function Has_Indirect (Cmt : String) return Boolean is
      P : constant Natural := Ada.Strings.Fixed.Index (Cmt, "indirect");
   begin
      if P = 0 or else Cmt'Length = 0 then
         return False;
      end if;
      return
        (P = Cmt'First or else not Is_Ident_Char (Cmt (P - 1)))
        and then (P + 7 >= Cmt'Last or else not Is_Ident_Char (Cmt (P + 8)));
   end Has_Indirect;

   --  Append one require entry: the first whitespace-delimited token of
   --  Text is the module path, the second is the version. Nothing is
   --  appended when either is missing, and the entry lands in the
   --  indirect set exactly when Cmt marks it indirect.
   --  @param Text  Directive text with any trailing comment removed.
   --  @param Cmt  The stripped comment text, or "".
   procedure Add_Entry (Text : String; Cmt : String) is
      E   : Go_Module_Entry;
      I   : Natural;
      P_F : Natural := 0;
      P_L : Natural := 0;
      V_F : Natural := 0;
      V_L : Natural := 0;
   begin
      if Text'Length = 0 then
         return;
      end if;
      I := Text'First;
      while I <= Text'Last and then Is_Blank (Text (I)) loop
         I := I + 1;
      end loop;
      if I > Text'Last then
         return;
      end if;
      P_F := I;
      while I <= Text'Last and then not Is_Blank (Text (I)) loop
         I := I + 1;
      end loop;
      P_L := I - 1;
      while I <= Text'Last and then Is_Blank (Text (I)) loop
         I := I + 1;
      end loop;
      if I > Text'Last then
         return;
      end if;
      V_F := I;
      while I <= Text'Last and then not Is_Blank (Text (I)) loop
         I := I + 1;
      end loop;
      V_L := I - 1;
      if P_L < P_F or else V_L < V_F then
         return;
      end if;
      Set_Field (E.Path, E.PLen, Text (P_F .. P_L));
      Set_Field (E.Ver, E.VLen, Text (V_F .. V_L));
      if E.PLen = 0 or else E.VLen = 0 then
         return;
      end if;
      if Has_Indirect (Cmt) then
         Indirect.Append (E);
      else
         Direct.Append (E);
      end if;
   end Add_Entry;
begin
   if Path'Length = 0 then
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
         Close (F);
         return;
      end if;
      declare
         T : constant String := Trim (Line (1 .. Last));
      begin
         if T'Length = 0 then
            null;
         elsif In_Block then
            if T (T'First) = ')' then
               In_Block := False;
            else
               declare
                  CS : constant Natural := Comment_Start (T);
               begin
                  if CS = 0 then
                     Add_Entry (T, "");
                  else
                     Add_Entry (T (T'First .. CS - 1), T (CS .. T'Last));
                  end if;
               end;
            end if;
         elsif T'Length >= 7
           and then T (T'First .. T'First + 6) = "require"
           and then (T'Length = 7
                     or else T (T'First + 7) = ' '
                     or else T (T'First + 7) = ASCII.HT
                     or else T (T'First + 7) = '(')
         then
            declare
               Rest : constant String := Trim (T (T'First + 7 .. T'Last));
               CS   : Natural := 0;
            begin
               if Rest'Length > 0 and then Rest (Rest'First) = '(' then
                  In_Block := True;
               else
                  CS := Comment_Start (Rest);
                  if CS = 0 then
                     Add_Entry (Rest, "");
                  else
                     Add_Entry
                       (Rest (Rest'First .. CS - 1), Rest (CS .. Rest'Last));
                  end if;
               end if;
            end;
         end if;
      end;
   end loop;
   Close (F);
exception
   when others =>
      if Is_Open (F) then
         Close (F);
      end if;
end Collect_Go_Requires;
