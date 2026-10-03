separate (Adacovex.Parsers.Manifest)
--  Queue a directory for the system-tool scan. A path longer than
--  Types.Max_Path is dropped, because the bounded scan stack can never
--  represent it and no later step could read it.
--  @param Dir  Directory path to visit.
procedure Push_Scan_Dir (Dir : String) is
   Item : Scan_Dir_Entry;
begin
   if Dir'Length <= Types.Max_Path then
      Item.Len := Dir'Length;
      for I in Dir'Range loop
         Item.Path (I - Dir'First + 1) := Dir (I);
      end loop;
      Scan_Stack.Append (Item);
   end if;
end Push_Scan_Dir;
