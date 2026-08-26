separate (Adacovex.Parsers.Manifest)
--  Collect the crate names declared in a manifest's [[depends-on]] (or
--  [depends-on]) section.  Missing files are ignored.  A physical line
--  longer than Max_Line clears the collected names.  No partial set is
--  kept.
procedure Read_Manifest_Deps
  (Path : String; Names : in out Name_Vectors.Vector)
is
   use Ada.Text_IO;
   F          : File_Type;
   Line       : String (1 .. Types.Max_Line);
   Last       : Natural;
   Overflow   : Boolean;
   Line_Num   : Natural := 0;
   In_Depends : Boolean := False;
begin
   Names.Clear;

   if not Ada.Directories.Exists (Path) then
      return;
   end if;
   begin
      Open (F, In_File, Path);
   exception
      when others =>
         return;
   end;

   while not End_Of_File (F) loop
      Line_Num := Line_Num + 1;
      Adacovex.Parsers.Read_Line (F, Path, Line_Num, Line, Last, Overflow);
      if Overflow then
         --  No partial dev-dependency set is kept.  Classification falls
         --  back to base/transitive only.
         Names.Clear;
         Close (F);
         return;
      end if;
      declare
         T : constant String := Trim (Line (1 .. Last));
      begin
         if T'Length > 2 and then T (T'First) = '[' and then T (T'Last) = ']'
         then
            declare
               Sec : constant String := T (T'First + 1 .. T'Last - 1);
            begin
               In_Depends :=
                 Trim (Sec) = "depends-on"
                 or else (Sec'Length > 1
                          and then Sec (Sec'First) = '['
                          and then Sec (Sec'Last) = ']'
                          and then Trim (Sec (Sec'First + 1 .. Sec'Last - 1))
                                   = "depends-on");
            end;
         elsif In_Depends then
            declare
               Eq : Natural := 0;
            begin
               for I in T'Range loop
                  if T (I) = '=' then
                     Eq := I;
                     exit;
                  end if;
               end loop;
               if Eq > T'First then
                  Add_Dep_Name (Names, Trim (T (T'First .. Eq - 1)));
               end if;
            end;
         end if;
      end;
   end loop;

   Close (F);
end Read_Manifest_Deps;
