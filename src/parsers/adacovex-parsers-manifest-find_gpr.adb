separate (Adacovex.Parsers.Manifest)
--  Locate the .gpr file for a crate name within the collected files.
procedure Find_GPR
  (Files : Path_Vectors.Vector;
   Crate : String;
   Path  : out Types.Path_Field;
   Len   : out Natural) is
begin
   Len := 0;
   if Crate'Length = 0 then
      return;
   end if;
   for I in 1 .. Integer (Files.Length) loop
      declare
         P    : String renames Files (I).Path (1 .. Files (I).Len);
         Base : constant String := Ada.Directories.Simple_Name (P);
         Dot  : Natural := 0;
      begin
         for J in reverse Base'Range loop
            if Base (J) = '.' then
               Dot := J;
               exit;
            end if;
         end loop;
         if Dot > 0 and then Base (Base'First .. Dot - 1) = Crate then
            Len := Files (I).Len;
            for J in 1 .. Len loop
               Path (J) := Files (I).Path (J);
            end loop;
            return;
         end if;
      end;
   end loop;
end Find_GPR;
