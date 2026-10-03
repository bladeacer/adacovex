separate (Adacovex.Parsers.Manifest)
--  When the word at Line (W_First .. W_Last) names one of the curated
--  system tools, record it via Note_Tool. The match is
--  case-sensitive. Only words whose length equals a tool name are
--  compared, so a line is scored once per word instead of once per
--  tool. "make" matches in "make build". "make" does not match in
--  "Makefile" (capital M), "makefile", or "makefiles". "python"
--  does not match inside "python3".
--  @param Line  Line of text to search.
--  @param W_First  First index of the word in Line.
--  @param W_Last  Last index of the word in Line.
procedure Note_If_Tool
  (Line : String; W_First : Natural; W_Last : Natural) is
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