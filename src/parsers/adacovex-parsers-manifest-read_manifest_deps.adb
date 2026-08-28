separate (Adacovex.Parsers.Manifest)
--  Collect the crate names declared in a manifest's [[depends-on]] (or
--  [depends-on]) section into Names, and the crate names declared under a
--  [[test-depends-on]] (or [test-depends-on]) section into Test_Names.
--  Test-depends-on is the manifest label for test-only dependencies: the
--  parser classifies such crates as Scope_Test.  Missing files are ignored.
--  A physical line longer than Max_Line clears the collected names.  No
--  partial set is kept.
procedure Read_Manifest_Deps
  (Path       : String;
   Names      : in out Name_Vectors.Vector;
   Test_Names : in out Name_Vectors.Vector)
is
   use Ada.Text_IO;
   F          : File_Type;
   Line       : String (1 .. Types.Max_Line);
   Last       : Natural;
   Overflow   : Boolean;
   Line_Num   : Natural := 0;
   In_Section : Boolean := False;
   Is_Test    : Boolean := False;
begin
   --  Clear only this procedure's own set.  Test_Names accumulates across
   --  the publishing and dev manifest reads; the caller clears it once
   --  per graph build.
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
         --  No partial dependency set is kept.  Classification falls
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
               Sec   : constant String := T (T'First + 1 .. T'Last - 1);
               Inner : constant String :=
                 (if Sec'Length > 1
                    and then Sec (Sec'First) = '['
                    and then Sec (Sec'Last) = ']'
                  then Trim (Sec (Sec'First + 1 .. Sec'Last - 1))
                  else Trim (Sec));
            begin
               if Inner = "depends-on" then
                  In_Section := True;
                  Is_Test := False;
               elsif Inner = "test-depends-on" then
                  In_Section := True;
                  Is_Test := True;
               else
                  In_Section := False;
               end if;
            end;
         elsif In_Section then
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
                  if Is_Test then
                     Add_Dep_Name (Test_Names, Trim (T (T'First .. Eq - 1)));
                  else
                     Add_Dep_Name (Names, Trim (T (T'First .. Eq - 1)));
                  end if;
               end if;
            end;
         end if;
      end;
   end loop;

   Close (F);
end Read_Manifest_Deps;
