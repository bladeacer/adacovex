with Ada.Text_IO;
--  SPDX-License-Identifier: Apache-2.0

package body Adacovex.Parsers.GNATprove is

   function Get_Nth_Number_Raw (S : String; N : Positive) return Natural is
      Val  : Natural := 0;
      Ctr  : Natural := 0;
      In_Num : Boolean := False;
   begin
      for I in S'Range loop
         if S (I) in '0' .. '9' then
            if not In_Num then
               Ctr := Ctr + 1;
               In_Num := True;
               Val := 0;
               if Ctr = N then
                  -- Start counting this number
                  Val := Character'Pos (S (I)) - Character'Pos ('0');
               end if;
            elsif Ctr = N then
               Val := Val * 10 +
                 (Character'Pos (S (I)) - Character'Pos ('0'));
            end if;
         else
            In_Num := False;
            if Ctr = N then
               return Val;
            end if;
         end if;
      end loop;
      if In_Num and then Ctr = N then
         return Val;
      end if;
      return 0;
   end Get_Nth_Number_Raw;

   procedure Parse_Prove_Out
     (File_Path : String;
      Summary   : out Types.Proof_Summary;
      Success   : out Boolean)
   is
      use Ada.Text_IO;
      F     : File_Type;
      Line  : String (1 .. Types.Max_Line);
      Last  : Natural;
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

         -- Look for "Analyzed N units" 
         if Last >= 12 then
            for I in 1 .. Last - 8 loop
               if Line (I .. I + 7) = "Analyzed" then
                  Summary.Units_Analyzed := Get_Nth_Number_Raw
                    (Line (I + 8 .. Last), 1);
               end if;
            end loop;
         end if;
         if Last >= 8 then
            for I in 1 .. Last - 7 loop
               if Line (I .. I + 6) = "skipped" then
                  Summary.Units_Skipped := Get_Nth_Number_Raw
                    (Line (I + 7 .. Last), 1);
               end if;
            end loop;
         end if;

         -- Match data rows by keyword at the start of the line (first non-space)
         declare
            First_Char : Natural := 0;
         begin
            for I in 1 .. Last loop
               if Line (I) /= ' ' then
                  First_Char := I;
                  exit;
               end if;
            end loop;

            if First_Char > 0 then
               declare
                  Row : String renames Line (First_Char .. Last);
               begin
                  -- Check for "Flow Dependencies"
                  if Row'Length >= 17 and then
                    Row (Row'First .. Row'First + 4) = "Flow " then
                     Summary.Flow_Checks := Get_Nth_Number_Raw (Row, 1);
                     Summary.Flow_Proved := Get_Nth_Number_Raw (Row, 2);
                  end if;

                  -- Check for "Run-time Checks"
                  if Row'Length >= 15 and then
                    Row (Row'First .. Row'First + 3) = "Run-" then
                     Summary.Runtime_Checks := Get_Nth_Number_Raw (Row, 1);
                     Summary.Runtime_Proved := Get_Nth_Number_Raw (Row, 2);
                  end if;

                  -- Check for "Assertions"
                  if Row'Length >= 10 and then
                    Row (Row'First .. Row'First + 3) = "Asse" then
                     Summary.Assertions := Get_Nth_Number_Raw (Row, 1);
                     Summary.Assert_Proved := Get_Nth_Number_Raw (Row, 2);
                  end if;

                  -- Check for "Functional"
                  if Row'Length >= 11 and then
                    Row (Row'First .. Row'First + 3) = "Func" then
                     Summary.Functional_Ct := Get_Nth_Number_Raw (Row, 1);
                     Summary.Functional_Proved := Get_Nth_Number_Raw (Row, 2);
                  end if;

                  -- Check for "Termination"
                  if Row'Length >= 11 and then
                    Row (Row'First .. Row'First + 3) = "Term" then
                     Summary.Termination_Ct := Get_Nth_Number_Raw (Row, 1);
                     Summary.Termination_Proved := Get_Nth_Number_Raw (Row, 2);
                  end if;

                  -- Check for "Total" line
                  if Row'Length >= 5 and then
                    Row (Row'First .. Row'First + 4) = "Total" then
                     Summary.Total_VCs := Get_Nth_Number_Raw (Row, 1);
                     Summary.Proved_VCs := Get_Nth_Number_Raw (Row, 2);
                     Summary.Justified := Get_Nth_Number_Raw (Row, 3);
                     Summary.Unproved := Get_Nth_Number_Raw (Row, 4);
                  end if;

                  -- Check for "Initialization"
                  if Row'Length >= 14 and then
                    Row (Row'First .. Row'First + 3) = "Init" then
                     Summary.Flow_Checks := Get_Nth_Number_Raw (Row, 1);
                     Summary.Flow_Proved := Get_Nth_Number_Raw (Row, 2);
                  end if;
               end;
            end if;
         end;
      end loop;

      Close (F);

      Summary.Level := Determine_SPARK_Level (Summary);
      Success := True;
   end Parse_Prove_Out;

   function Determine_SPARK_Level
     (Summary : Types.Proof_Summary) return Types.SPARK_Level
   is
   begin
      if Summary.Unproved > 0 then
         return Types.Silver;
      end if;

      if Summary.Functional_Ct > 0 and then
        Summary.Functional_Proved = Summary.Functional_Ct then
         return Types.Platinum;
      end if;

      if Summary.Runtime_Proved > 0 and then
        Summary.Runtime_Proved >= Summary.Runtime_Checks then
         if Summary.Assert_Proved > 0 and then
           Summary.Assert_Proved >= Summary.Assertions then
            return Types.Gold;
         end if;
         return Types.Silver;
      end if;

      if Summary.Flow_Proved > 0 and then
        Summary.Flow_Proved >= Summary.Flow_Checks then
         return Types.Bronze;
      end if;

      return Types.Stone;
   end Determine_SPARK_Level;

end Adacovex.Parsers.GNATprove;
