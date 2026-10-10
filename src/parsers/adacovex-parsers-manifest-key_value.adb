separate (Adacovex.Parsers.Manifest)
--  Extract the quoted value of "Key = "value"" from a line of TOML.
--  Returns "" when the key is not present or not a quoted string.
function Key_Value (Line : String; Key : String) return String is
   Eq : Natural := 0;
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
   if Trim (Line (Line'First .. Eq - 1)) /= Key then
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
end Key_Value;
