with Ada.Text_IO;

package body Adacovex.Parsers.DO178C is

   procedure Parse_HLR_MD
     (File_Path : String;
      HLRs      : in out HLR_Vectors.Vector;
      Success   : out Boolean)
   is
      use Ada.Text_IO;
      F        : File_Type;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Overflow : Boolean;
      Line_Num : Natural := 0;
   begin
      begin
         Open (F, In_File, File_Path);
      exception
         when others =>
            Success := False;
            return;
      end;

      begin
         while not End_Of_File (F) loop
            Line_Num := Line_Num + 1;
            Adacovex.Parsers.Read_Line
              (F, File_Path, Line_Num, Line, Last, Overflow);
            if Overflow then
               --  A physical line longer than Max_Line is drained and
               --  reported by Read_Line; parsing stops so no partial HLR set
               --  is passed downstream.
               HLRs.Clear;
               Close (F);
               Success := False;
               return;
            end if;

            -- Look for lines matching "- HLR_XXX: description"
            if Last > 6 then
               declare
                  H_Start : Natural := 0;
                  H_End   : Natural := 0;
                  Colon   : Natural := 0;
               begin
                  for I in 1 .. Last - 3 loop
                     if Line (I) = 'H' and then Line (I .. I + 3) = "HLR-" then
                        H_Start := I;
                        exit;
                     end if;
                  end loop;

                  if H_Start > 0 then
                     for I in H_Start + 4 .. Last loop
                        if Line (I) = ' ' or else Line (I) = ':' then
                           H_End := I - 1;
                           if Line (I) = ':' then
                              Colon := I;
                           end if;
                           exit;
                        end if;
                     end loop;

                     if Colon = 0 then
                        for I in H_End + 1 .. Last loop
                           if Line (I) = ':' then
                              Colon := I;
                              exit;
                           end if;
                        end loop;
                     end if;

                     if H_End > H_Start + 3 then
                        HLRs.Append (HLR_Info'(others => <>));
                        declare
                           Elem : HLR_Info := HLRs (Positive (HLRs.Length));
                        begin
                           Elem.Id_Len :=
                             Natural'Min
                               (H_End - (H_Start + 4) + 1, Elem.Id'Length);
                           for I in H_Start + 4 .. H_Start + 3 + Elem.Id_Len
                           loop
                              Elem.Id (I - (H_Start + 4) + 1) := Line (I);
                           end loop;

                           if Colon > 0 and then Colon < Last then
                              declare
                                 D_Start : Natural := Colon + 1;
                              begin
                                 while D_Start <= Last
                                   and then Line (D_Start) = ' '
                                 loop
                                    D_Start := D_Start + 1;
                                 end loop;
                                 Elem.D_Len :=
                                   Natural'Min
                                     (Last - D_Start + 1, Elem.Desc'Length);
                                 for I in D_Start .. D_Start + Elem.D_Len - 1
                                 loop
                                    Elem.Desc (I - D_Start + 1) := Line (I);
                                 end loop;
                              end;
                           end if;
                           HLRs.Replace_Element (Positive (HLRs.Length), Elem);
                        end;
                     end if;
                  end if;
               end;
            end if;
         end loop;
      exception
         when others =>
            Close (F);
            raise;
      end;

      Close (F);
      Success := True;
   end Parse_HLR_MD;

   procedure Parse_LLR_MD
     (File_Path : String;
      LLRs      : in out LLR_Vectors.Vector;
      Success   : out Boolean)
   is
      use Ada.Text_IO;
      F        : File_Type;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Overflow : Boolean;
      Line_Num : Natural := 0;
   begin
      begin
         Open (F, In_File, File_Path);
      exception
         when others =>
            Success := False;
            return;
      end;

      begin
         while not End_Of_File (F) loop
            Line_Num := Line_Num + 1;
            Adacovex.Parsers.Read_Line
              (F, File_Path, Line_Num, Line, Last, Overflow);
            if Overflow then
               --  A physical line longer than Max_Line is drained and
               --  reported by Read_Line; parsing stops so no partial LLR set
               --  is passed downstream.
               LLRs.Clear;
               Close (F);
               Success := False;
               return;
            end if;

            -- Look for lines matching "- LLR_XXX: description [HLR_XXX]"
            if Last > 6 then
               declare
                  L_Start : Natural := 0;
                  L_End   : Natural := 0;
                  Colon   : Natural := 0;
                  H_Start : Natural := 0;
                  H_End   : Natural := 0;
               begin
                  for I in 1 .. Last - 3 loop
                     if Line (I) = 'L'
                       and then I + 3 <= Last
                       and then Line (I .. I + 3) = "LLR-"
                     then
                        L_Start := I;
                        exit;
                     end if;
                  end loop;

                  if L_Start = 0 then
                     for I in 1 .. Last - 3 loop
                        if Line (I) = 'L'
                          and then I + 3 <= Last
                          and then (Line (I .. I + 3) = "LLR-")
                        then
                           L_Start := I;
                           exit;
                        end if;
                     end loop;
                  end if;

                  if L_Start > 0 then
                     for I in L_Start + 4 .. Last loop
                        if Line (I) = ' ' or else Line (I) = ':' then
                           L_End := I - 1;
                           if Line (I) = ':' then
                              Colon := I;
                           end if;
                           exit;
                        end if;
                     end loop;

                     if Colon = 0 then
                        for I in L_End + 1 .. Last loop
                           if Line (I) = ':' then
                              Colon := I;
                              exit;
                           end if;
                        end loop;
                     end if;

                     if Colon > 0 then
                        for I in Colon + 1 .. Last - 3 loop
                           if Line (I) = 'H'
                             and then Line (I .. I + 3) = "HLR-"
                           then
                              H_Start := I;
                              for J in I + 4 .. Last loop
                                 if Line (J) = ' '
                                   or else Line (J) = ']'
                                   or else Line (J) = ')'
                                 then
                                    H_End := J - 1;
                                    exit;
                                 end if;
                              end loop;
                              exit;
                           end if;
                        end loop;
                     end if;

                     if L_End > L_Start + 3 then
                        LLRs.Append (LLR_Info'(others => <>));
                        declare
                           Elem : LLR_Info := LLRs (Positive (LLRs.Length));
                        begin
                           Elem.Id_Len :=
                             Natural'Min
                               (L_End - (L_Start + 4) + 1, Elem.Id'Length);
                           for I in L_Start + 4 .. L_Start + 3 + Elem.Id_Len
                           loop
                              Elem.Id (I - (L_Start + 4) + 1) := Line (I);
                           end loop;

                           if Colon > 0 and then Colon < Last then
                              declare
                                 D_Start : Natural := Colon + 1;
                                 D_End   : Natural := Last;
                              begin
                                 while D_Start <= Last
                                   and then Line (D_Start) = ' '
                                 loop
                                    D_Start := D_Start + 1;
                                 end loop;

                                 if H_Start > D_Start then
                                    D_End := H_Start - 1;
                                    while D_End > D_Start
                                      and then Line (D_End) = ' '
                                    loop
                                       D_End := D_End - 1;
                                    end loop;
                                 end if;

                                 Elem.D_Len :=
                                   Natural'Min
                                     (D_End - D_Start + 1, Elem.Desc'Length);
                                 for I in D_Start .. D_Start + Elem.D_Len - 1
                                 loop
                                    Elem.Desc (I - D_Start + 1) := Line (I);
                                 end loop;
                              end;
                           end if;

                           if H_Start > 0 and then H_End > H_Start + 3 then
                              Elem.HLR_Len :=
                                Natural'Min
                                  (H_End - (H_Start + 4) + 1,
                                   Elem.HLR_Ref'Length);
                              for I in
                                H_Start + 4 .. H_Start + 3 + Elem.HLR_Len
                              loop
                                 Elem.HLR_Ref (I - (H_Start + 4) + 1) :=
                                   Line (I);
                              end loop;
                           end if;
                           LLRs.Replace_Element (Positive (LLRs.Length), Elem);
                        end;
                     end if;
                  end if;
               end;
            end if;
         end loop;
      exception
         when others =>
            Close (F);
            raise;
      end;

      Close (F);
      Success := True;
   end Parse_LLR_MD;

   function Find_HLR_In_Source
     (HLR_Id : String; Packages : Types.Implementation.Package_Vectors.Vector)
      return Boolean is
   begin
      for P in 1 .. Integer (Packages.Length) loop
         for T in 1 .. Integer (Packages (P).HLR_Tags.Length) loop
            declare
               Tag_Len : constant Natural := Packages (P).HLR_Tags (T).Len;
               Match   : Boolean := True;
            begin
               if Tag_Len = HLR_Id'Length then
                  for I in 1 .. Tag_Len loop
                     if Packages (P).HLR_Tags (T).Tag (I)
                       /= HLR_Id (HLR_Id'First + I - 1)
                     then
                        Match := False;
                        exit;
                     end if;
                  end loop;
                  if Match then
                     return True;
                  end if;
               end if;
            end;
         end loop;
      end loop;
      return False;
   end Find_HLR_In_Source;

end Adacovex.Parsers.DO178C;
