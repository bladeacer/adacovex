separate (Adacovex.Parsers.Manifest)
--  Scan one dev-facing build file for every known system tool. A file that
--  cannot be opened is skipped. A physical line longer than Types.Max_Line
--  stops the scan of that file, so a truncated file never yields a partial
--  tool set. Comment text is never scanned: a build file that mentions a
--  tool only in a comment does not depend on it.
--  @param Path  Path of the file to read.
procedure Scan_File (Path : String) is
   use Ada.Text_IO;
   F        : File_Type;
   Line     : String (1 .. Types.Max_Line);
   Last     : Natural;
   Overflow : Boolean;
   Line_Num : Natural := 0;

   --  Last index of the command text on a line. An unquoted '#' that starts
   --  a word opens a comment, and a leading "#!" shebang stays command text
   --  (a shell script depends on its interpreter). Double quotes protect a
   --  '#' inside a manifest string. A line that is all comment returns the
   --  index before its first character, so the caller scans nothing.
   --  @param S  Line text (Line (1 .. Last)).
   --  @return Last index of command text.
   function Code_Last (S : String) return Natural is
      In_Quote : Boolean := False;
   begin
      if S'Length >= 2
        and then S (S'First) = '#'
        and then S (S'First + 1) = '!'
      then
         return S'Last;
      end if;
      for I in S'Range loop
         if S (I) = '"' then
            In_Quote := not In_Quote;
         elsif not In_Quote
           and then S (I) = '#'
           and then (I = S'First
                     or else S (I - 1) = ' '
                     or else S (I - 1) = ASCII.HT)
         then
            return I - 1;
         end if;
      end loop;
      return S'Last;
   end Code_Last;
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
         --  A physical line longer than Max_Line. Stop scanning this
         --  file. A truncated file then never yields a partial tool
         --  set.
         Close (F);
         return;
      end if;
      if Ada.Strings.Fixed.Index
           (Line (1 .. Last), "System_Tools : constant array")
        > 0
      then
         --  This file declares the curated tool table. Every entry is
         --  a literal tool name by construction. References found
         --  here can register every installed tool. This happens
         --  regardless of whether the project actually uses the tool.
         Close (F);
         return;
      end if;
      declare
         Code : constant Natural := Code_Last (Line (1 .. Last));
      begin
         Note_Referenced_Tools (Line (1 .. Code));
      end;
   end loop;
   Close (F);
exception
   when others =>
      if Is_Open (F) then
         Close (F);
      end if;
end Scan_File;
