with Ada.Text_IO;

package body Adacovex.Parsers.Tests is

   procedure Parse_Test_Result
     (File_Path : String;
      Summary   : out Types.Test_Summary;
      Success   : out Boolean)
   is
      use Ada.Text_IO;
      F    : File_Type;
      Line : String (1 .. Types.Max_Line);
      Last : Natural;
   begin
      Summary := (others => <>);

      begin
         Open (F, In_File, File_Path);
      exception
         when others =>
            Success := False;
            return;
      end;

      while not End_Of_File (F) loop
         Get_Line (F, Line, Last);

         -- Find first '|' character (skip leading spaces)
         declare
            First_Pipe : Natural := 0;
         begin
            for I in 1 .. Last loop
               if Line (I) = '|' then
                  First_Pipe := I;
                  exit;
               end if;
            end loop;

            if First_Pipe > 0 then
               declare
                  Parts    : array (1 .. 5) of String (1 .. Types.Max_Desc_Str);
                  Part_Len : array (1 .. 5) of Natural := (others => 0);
                  Part_Ct  : Natural := 0;
                  In_Part  : Boolean := False;
                  PIdx     : Natural := 0;
               begin
                  for I in First_Pipe + 1 .. Last loop
                     if Line (I) = '|' then
                        In_Part := False;
                     elsif not In_Part then
                        if Line (I) /= ' ' then
                           Part_Ct := Part_Ct + 1;
                           PIdx := 1;
                           In_Part := True;
                           if Part_Ct <= 5 then
                              Part_Len (Part_Ct) := 1;
                              Parts (Part_Ct) (1) := Line (I);
                           end if;
                        end if;
                     else
                        if Part_Ct <= 5 and then
                          Part_Len (Part_Ct) < Types.Max_Desc_Str then
                           Part_Len (Part_Ct) := Part_Len (Part_Ct) + 1;
                           Parts (Part_Ct) (Part_Len (Part_Ct)) := Line (I);
                        end if;
                     end if;
                  end loop;

                  if Part_Ct >= 3 then
                     -- Check if third column is a number (test count)
                     declare
                        Is_Number : Boolean := True;
                        TCount    : Natural := 0;
                     begin
                        for I in 1 .. Part_Len (3) loop
                           if Parts (3) (I) in '0' .. '9' then
                              TCount := TCount * 10 +
                                (Character'Pos (Parts (3) (I)) - Character'Pos ('0'));
                           else
                              Is_Number := False;
                           end if;
                        end loop;

                        if Is_Number and then TCount > 0 and then
                          Summary.Category_Count < 32 then
                           Summary.Category_Count := Summary.Category_Count + 1;
                           declare
                              CI : constant Natural := Summary.Category_Count;
                           begin
                              Summary.Categories (CI).Cat_Len := Part_Len (2);
                              for I in 1 .. Part_Len (2) loop
                                 Summary.Categories (CI).Category (I) := Parts (2) (I);
                              end loop;
                              Summary.Categories (CI).Test_Count := TCount;

                              if Part_Ct >= 4 and then
                                Part_Len (4) >= 4 then
                                 if Parts (4) (1 .. 4) = "PASS" then
                                    Summary.Categories (CI).Status := Types.Pass;
                                    Summary.Total_Passed := Summary.Total_Passed + TCount;
                                 else
                                    Summary.Categories (CI).Status := Types.Fail;
                                    Summary.Total_Failed := Summary.Total_Failed + TCount;
                                 end if;
                              end if;
                           end;
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;

         -- Look for "Passed:" keyword anywhere in line
         for I in 1 .. Last - 6 loop
            if Line (I .. I + 6) = "Passed:" then
               declare
                  Num : Natural := 0;
                  J   : Natural := I + 7;
               begin
                  while J <= Last and then Line (J) = ' ' loop
                     J := J + 1;
                  end loop;
                  while J <= Last and then Line (J) in '0' .. '9' loop
                     Num := Num * 10 +
                       (Character'Pos (Line (J)) - Character'Pos ('0'));
                     J := J + 1;
                  end loop;
                  Summary.Total_Passed := Num;
               end;
            end if;

            if Line (I .. I + 6) = "Failed:" then
               declare
                  Num : Natural := 0;
                  J   : Natural := I + 7;
               begin
                  while J <= Last and then Line (J) = ' ' loop
                     J := J + 1;
                  end loop;
                  while J <= Last and then Line (J) in '0' .. '9' loop
                     Num := Num * 10 +
                       (Character'Pos (Line (J)) - Character'Pos ('0'));
                     J := J + 1;
                  end loop;
                  Summary.Total_Failed := Num;
               end;
            end if;
         end loop;
      end loop;

      Close (F);
      Success := True;
   end Parse_Test_Result;

   procedure Parse_Test_Stdout
     (Summary : out Types.Test_Summary)
   is
   begin
      Summary := (others => <>);
   end Parse_Test_Stdout;

end Adacovex.Parsers.Tests;
