separate (Adacovex.Parsers.Manifest)
--  Whether a directory holding the detected language counters already
--  contains the given language name.
function Has_Lang (Langs : Lang_Vectors.Vector; L : String) return Boolean is
begin
   for I in 1 .. Integer (Langs.Length) loop
      if Langs (I).Len = L'Length and then Langs (I).Name (1 .. L'Length) = L
      then
         return True;
      end if;
   end loop;
   return False;
end Has_Lang;
