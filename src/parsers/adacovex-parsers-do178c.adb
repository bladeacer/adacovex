with Ada.Text_IO;

package body Adacovex.Parsers.DO178C is

   procedure Parse_HLR_MD
     (File_Path : String;
      HLRs      : out HLR_Array;
      HLR_Count : out Natural;
      Success   : out Boolean)
   is
      use Ada.Text_IO;
      F    : File_Type;
      Line : String (1 .. Types.Max_Line);
      Last : Natural;
   begin
      HLR_Count := 0;

      begin
         Open (F, In_File, File_Path);
      exception
         when others =>
            Success := False;
            return;
      end;

      while not End_Of_File (F) loop
         Get_Line (F, Line, Last);

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

                  if H_End > H_Start + 3 and then
                    HLR_Count < Types.Max_Hlrs then
                     HLR_Count := HLR_Count + 1;

                     -- Extract HLR ID (skip "HLR-" prefix)
                     HLRs (HLR_Count).Id_Len := H_End - (H_Start + 4) + 1;
                     for I in H_Start + 4 .. H_End loop
                        HLRs (HLR_Count).Id (I - (H_Start + 4) + 1) := Line (I);
                     end loop;

                     -- Extract description after colon
                     if Colon > 0 and then Colon < Last then
                        declare
                           D_Start : Natural := Colon + 1;
                        begin
                           while D_Start <= Last and then
                             Line (D_Start) = ' ' loop
                              D_Start := D_Start + 1;
                           end loop;
                           HLRs (HLR_Count).D_Len := Last - D_Start + 1;
                           for I in D_Start .. Last loop
                              HLRs (HLR_Count).Desc
                                (I - D_Start + 1) := Line (I);
                           end loop;
                        end;
                     end if;
                  end if;
               end if;
            end;
         end if;
      end loop;

      Close (F);
      Success := True;
   end Parse_HLR_MD;

   procedure Parse_LLR_MD
     (File_Path : String;
      LLRs      : out LLR_Array;
      LLR_Count : out Natural;
      Success   : out Boolean)
   is
      use Ada.Text_IO;
      F    : File_Type;
      Line : String (1 .. Types.Max_Line);
      Last : Natural;
   begin
      LLR_Count := 0;

      begin
         Open (F, In_File, File_Path);
      exception
         when others =>
            Success := False;
            return;
      end;

      while not End_Of_File (F) loop
         Get_Line (F, Line, Last);

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
                  if Line (I) = 'L' and then
                    I + 3 <= Last and then
                    Line (I .. I + 3) = "LLR-" then
                     L_Start := I;
                     exit;
                  end if;
               end loop;

               if L_Start = 0 then
                  for I in 1 .. Last - 3 loop
                     if Line (I) = 'L' and then
                       I + 3 <= Last and then
                       (Line (I .. I + 3) = "LLR-") then
                        L_Start := I;
                        exit;
                     end if;
                  end loop;
               end if;

               if L_Start > 0 then
                  -- Find end of LLR ID
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

                  -- Find HLR reference
                  if Colon > 0 then
                     for I in Colon + 1 .. Last - 3 loop
                        if Line (I) = 'H' and then Line (I .. I + 3) = "HLR-" then
                           H_Start := I;
                           for J in I + 4 .. Last loop
                              if Line (J) = ' ' or else Line (J) = ']' or else
                                Line (J) = ')' then
                                 H_End := J - 1;
                                 exit;
                              end if;
                           end loop;
                           exit;
                        end if;
                     end loop;
                  end if;

                  if L_End > L_Start + 3 and then
                    LLR_Count < Types.Max_Llrs then
                     LLR_Count := LLR_Count + 1;

                     LLRs (LLR_Count).Id_Len := L_End - (L_Start + 4) + 1;
                     for I in L_Start + 4 .. L_End loop
                        LLRs (LLR_Count).Id (I - (L_Start + 4) + 1) := Line (I);
                     end loop;

                     if Colon > 0 and then Colon < Last then
                        declare
                           D_Start : Natural := Colon + 1;
                           D_End   : Natural := Last;
                        begin
                           while D_Start <= Last and then
                             Line (D_Start) = ' ' loop
                              D_Start := D_Start + 1;
                           end loop;

                           -- Truncate at HLR reference
                           if H_Start > D_Start then
                              D_End := H_Start - 1;
                              while D_End > D_Start and then
                                Line (D_End) = ' ' loop
                                 D_End := D_End - 1;
                              end loop;
                           end if;

                           LLRs (LLR_Count).D_Len := D_End - D_Start + 1;
                           for I in D_Start .. D_End loop
                              LLRs (LLR_Count).Desc
                                (I - D_Start + 1) := Line (I);
                           end loop;
                        end;
                     end if;

                     if H_Start > 0 and then H_End > H_Start + 3 then
                        LLRs (LLR_Count).HLR_Len := H_End - (H_Start + 4) + 1;
                        for I in H_Start + 4 .. H_End loop
                           LLRs (LLR_Count).HLR_Ref (I - (H_Start + 4) + 1) := Line (I);
                        end loop;
                     end if;
                  end if;
               end if;
            end;
         end if;
      end loop;

      Close (F);
      Success := True;
   end Parse_LLR_MD;

    function Find_HLR_In_Source
      (HLR_Id   : String;
       Packages : Types.Package_Array;
       Pkg_Count: Natural) return Boolean
    is
    begin
       for P in 1 .. Pkg_Count loop
          for T in 1 .. Packages (P).Total_HLR_Tags loop
             declare
                Tag_Len : constant Natural := Packages (P).HLR_Tags (T).Len;
                Match   : Boolean := True;
             begin
                if Tag_Len = HLR_Id'Length then
                   for I in 1 .. Tag_Len loop
                      if Packages (P).HLR_Tags (T).Tag (I) /= HLR_Id (HLR_Id'First + I - 1) then
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
