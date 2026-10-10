separate (Adacovex.Parsers.Manifest)
--  Extract the first quoted string inside "Key = ["list"]" (project-files).
function First_List_Value (Line : String; Key : String) return String is
   Eq  : Natural := 0;
   Lhs : Natural := 0;
begin
   for I in Line'Range loop
      if Line (I) = '=' then
         Eq := I;
         exit;
      end if;
   end loop;
   if Eq = 0 then
      return "";
   end if;
   Lhs := Eq - 1;
   while Lhs >= Line'First and then Line (Lhs) = ' ' loop
      Lhs := Lhs - 1;
   end loop;
   if Lhs < Line'First
     or else Lhs - Line'First + 1 /= Key'Length
     or else Line (Line'First .. Lhs) /= Key
   then
      return "";
   end if;
   for I in Eq + 1 .. Line'Last loop
      if Line (I) = '"' then
         for J in I + 1 .. Line'Last loop
            if Line (J) = '"' then
               return Line (I + 1 .. J - 1);
            end if;
         end loop;
         exit;
      end if;
   end loop;
   return "";
end First_List_Value;
