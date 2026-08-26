separate (Adacovex.Parsers.Manifest)
--  Append a crate name to a name vector unless already present.
procedure Add_Dep_Name (Names : in out Name_Vectors.Vector; Name : String) is
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
