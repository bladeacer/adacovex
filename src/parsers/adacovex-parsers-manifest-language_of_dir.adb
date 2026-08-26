separate (Adacovex.Parsers.Manifest)
--  Language summary of the source files under a directory.  The primary
--  (ecosystem) language is first when given.  The top detected languages
--  follow by file count.  Join them with "; " (max 3 labels).
--  @param Root  Directory tree to scan (file names only, no content).
--  @param Max_Levels  Subdirectory depth to descend into.
--  @param Primary_Kind  Ecosystem primary language or "".
--  @return Language summary (for example "Ada; C; C++"), "" when nothing.
function Language_Of_Dir
  (Root : String; Max_Levels : Natural; Primary_Kind : String := "")
   return String
is
   Langs : Lang_Vectors.Vector;
begin
   Detect_Languages (Root, Max_Levels, Langs);
   if Langs.Is_Empty and Primary_Kind'Length = 0 then
      return "";
   end if;
   if Primary_Kind'Length > 0 and then not Has_Lang (Langs, Primary_Kind) then
      --  Manifest language always leads the label even when no
      --  matching source files were counted.
      declare
         Item : Lang_Item;
      begin
         Item.Len := Primary_Kind'Length;
         for I in 1 .. Primary_Kind'Length loop
            Item.Name (I) := Primary_Kind (Primary_Kind'First + I - 1);
         end loop;
         Langs.Append (Item);
      end;
   end if;
   return Language_Summary (Langs, Primary_Kind);
end Language_Of_Dir;
