separate (Adacovex.Parsers.Manifest)
procedure Set_Path
  (Field : out Types.Path_Field; Len : out Natural; S : String) is
begin
   Len := S'Length;
   if Len > Types.Max_Path then
      Len := Types.Max_Path;
   end if;
   for I in 1 .. Len loop
      Field (I) := S (S'First + I - 1);
   end loop;
end Set_Path;
