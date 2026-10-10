separate (Adacovex.Parsers.Manifest)
procedure Set_Field
  (Field : out Types.Desc_Field; Len : out Natural; S : String) is
begin
   Len := S'Length;
   if Len > Types.Max_Desc_Str then
      Len := Types.Max_Desc_Str;
   end if;
   for I in 1 .. Len loop
      Field (I) := S (S'First + I - 1);
   end loop;
end Set_Field;
