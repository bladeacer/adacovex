separate (Adacovex.Parsers.Manifest)
function Name_In_Graph
  (Graph : Types.Implementation.Component_Vectors.Vector; Name : String)
   return Boolean is
begin
   for I in 1 .. Integer (Graph.Length) loop
      if Graph (I).Name_Len = Name'Length
        and then Graph (I).Name (1 .. Name'Length) = Name
      then
         return True;
      end if;
   end loop;
   return False;
end Name_In_Graph;
