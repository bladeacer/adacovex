separate (Adacovex.Parsers.Manifest)
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
      -- reference any tool.
      return;
   end if;
   while W_First <= Line'Last loop
      --  Skip non-word characters (whitespace, quotes, punctuation).
      while W_First <= Line'Last and then not Is_Word_Char (Line (W_First))
      loop
         W_First := W_First + 1;
      end loop;
      exit when W_First > Line'Last;
      W_Last := W_First;
      while W_Last < Line'Last and then Is_Word_Char (Line (W_Last + 1)) loop
         W_Last := W_Last + 1;
      end loop;
      Note_If_Tool (Line, W_First, W_Last);
      W_First := W_Last + 1;
   end loop;
end Note_Referenced_Tools;
