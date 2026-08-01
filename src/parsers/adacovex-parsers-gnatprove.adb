with Ada.Text_IO;

package body Adacovex.Parsers.GNATprove is

   function Get_Nth_Number_Raw (S : String; N : Positive) return Natural is
      Val    : Natural := 0;
      Ctr    : Natural := 0;
      In_Num : Boolean := False;
      Paren  : Natural := 0;
   begin
      for I in S'Range loop
         if S (I) = '(' then
            Paren := Paren + 1;
         elsif S (I) = ')' then
            if Paren > 0 then
               Paren := Paren - 1;
            end if;
         elsif Paren = 0 and then S (I) in '0' .. '9' then
            if not In_Num then
               Ctr := Ctr + 1;
               In_Num := True;
               Val := 0;
               if Ctr = N then
                  Val := Character'Pos (S (I)) - Character'Pos ('0');
               end if;
            elsif Ctr = N then
               Val := Val * 10 + (Character'Pos (S (I)) - Character'Pos ('0'));
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

      begin
         while not End_Of_File (F) loop
            Get_Line (F, Line, Last);

            -- Look for "Analyzed N units"
            if Last >= 12 then
               for I in 1 .. Last - 8 loop
                  if Line (I .. I + 7) = "Analyzed" then
                     Summary.Units_Analyzed :=
                       Get_Nth_Number_Raw (Line (I + 8 .. Last), 1);
                  end if;
               end loop;
            end if;
            if Last >= 8 then
               for I in 1 .. Last - 7 loop
                  if Line (I .. I + 6) = "skipped" then
                     Summary.Units_Skipped :=
                       Get_Nth_Number_Raw (Line (I + 7 .. Last), 1);
                  end if;
               end loop;
            end if;

            -- Match data rows by keyword at the start of the line
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
                     if Row'Length >= 17
                       and then Row (Row'First .. Row'First + 4) = "Flow "
                     then
                        Summary.Flow_Checks := Get_Nth_Number_Raw (Row, 1);
                        Summary.Flow_Proved := Get_Nth_Number_Raw (Row, 2);
                     end if;

                     if Row'Length >= 15
                       and then Row (Row'First .. Row'First + 3) = "Run-"
                     then
                        Summary.Runtime_Checks := Get_Nth_Number_Raw (Row, 1);
                        Summary.Runtime_Proved := Get_Nth_Number_Raw (Row, 2);
                     end if;

                     if Row'Length >= 10
                       and then Row (Row'First .. Row'First + 3) = "Asse"
                     then
                        Summary.Assertions := Get_Nth_Number_Raw (Row, 1);
                        Summary.Assert_Proved := Get_Nth_Number_Raw (Row, 2);
                     end if;

                     if Row'Length >= 11
                       and then Row (Row'First .. Row'First + 3) = "Func"
                     then
                        Summary.Functional_Ct := Get_Nth_Number_Raw (Row, 1);
                        Summary.Functional_Proved :=
                          Get_Nth_Number_Raw (Row, 2);
                     end if;

                     if Row'Length >= 11
                       and then Row (Row'First .. Row'First + 3) = "Term"
                     then
                        Summary.Termination_Ct := Get_Nth_Number_Raw (Row, 1);
                        Summary.Termination_Proved :=
                          Get_Nth_Number_Raw (Row, 2);
                     end if;

                     if Row'Length >= 5
                       and then Row (Row'First .. Row'First + 4) = "Total"
                     then
                        Summary.Total_VCs := Get_Nth_Number_Raw (Row, 1);
                        Summary.Justified := Get_Nth_Number_Raw (Row, 4);
                        Summary.Unproved := Get_Nth_Number_Raw (Row, 5);
                        --  Modern summary layout:
                        --    Total | Flow | Provers | Justified | Unproved
                        --  Proved = solved-by-flow + solved-by-provers,
                        --  equivalently Total - Justified - Unproved.
                        if Summary.Total_VCs > 0 then
                           Summary.Proved_VCs :=
                             Summary.Total_VCs
                             - Summary.Justified
                             - Summary.Unproved;
                        end if;
                     end if;

                     if Row'Length >= 14
                       and then Row (Row'First .. Row'First + 3) = "Init"
                     then
                        Summary.Init_Checks := Get_Nth_Number_Raw (Row, 1);
                        Summary.Init_Proved := Get_Nth_Number_Raw (Row, 2);
                     end if;
                  end;
               end if;
            end;
         end loop;
      exception
         when others =>
            Close (F);
            raise;
      end;

      Close (F);

       Summary.Level := Determine_SPARK_Level (Summary);
       Success := Summary.Total_VCs > 0;
    end Parse_Prove_Out;

    function Determine_SPARK_Level
      (Summary : Types.Proof_Summary) return Types.SPARK_Level is
    begin
       --  Empty summary (no gnatprove data) is Stone, not Gold:
       --  a zero-row file must not be mistaken for fully-proved.
       --  Unproved is excluded from the emptiness test: a summary that
       --  reports unproved VCs carries real (Silver-capping) data.
       if Summary.Total_VCs = 0
         and then Summary.Unproved = 0
         and then Summary.Flow_Checks = 0
         and then Summary.Runtime_Checks = 0
         and then Summary.Assertions = 0
         and then Summary.Functional_Ct = 0
         and then Summary.Termination_Ct = 0
       then
          return Types.Stone;
       end if;

       if Summary.Unproved > 0 then
         return Types.Silver;
      end if;

      if Summary.Functional_Ct > 0
        and then Summary.Functional_Proved = Summary.Functional_Ct
      then
         return Types.Platinum;
      end if;

      if Summary.Runtime_Proved >= Summary.Runtime_Checks then
         if Summary.Assert_Proved >= Summary.Assertions then
            return Types.Gold;
         end if;
         return Types.Silver;
      end if;

      if Summary.Flow_Proved >= Summary.Flow_Checks then
         return Types.Bronze;
      end if;

      return Types.Stone;
   end Determine_SPARK_Level;

   procedure Parse_Prove_From_Project
     (Target_Dir : String;
      Summary    : out Types.Proof_Summary;
      Success    : out Boolean)
   is
      Path1 : constant String := Target_Dir & "/obj/gnatprove/gnatprove.out";
      Path2 : constant String := Target_Dir & "/gnatprove.out";
      Path3 : constant String := Target_Dir & "/gnatprove/gnatprove.out";
   begin
      Summary := (others => <>);
      Parse_Prove_Out (Path1, Summary, Success);
      if Success then
         return;
      end if;
      Parse_Prove_Out (Path2, Summary, Success);
      if Success then
         return;
      end if;
      Parse_Prove_Out (Path3, Summary, Success);
   end Parse_Prove_From_Project;

   procedure Parse_Prove_JSON
     (File_Path : String;
      Summary   : out Types.Proof_Summary;
      Success   : out Boolean)
   is
      use Ada.Text_IO;
      F    : File_Type;
      Line : String (1 .. Types.Max_Line);
      Last : Natural;
      --  Simple JSON field extractor: looks for "key": number
      function JSON_Get (S : String; Key : String) return Natural is
         Pos : Natural := 0;
         K   : constant String := '"' & Key & '"';
      begin
         for I in S'Range loop
            if S (I) = '"' and then I + K'Length - 1 <= S'Last then
               --  Check for key match
               declare
                  Match : Boolean := True;
               begin
                  for J in 1 .. K'Length loop
                     if S (I + J - 1) /= K (J) then
                        Match := False;
                        exit;
                     end if;
                  end loop;
                  if Match then
                     Pos := I + K'Length;
                     exit;
                  end if;
               end;
            end if;
         end loop;
         if Pos = 0 then
            return 0;
         end if;
         --  Skip whitespace, colon, whitespace
         while Pos <= S'Last and then S (Pos) in ' ' | ':' | ',' loop
            Pos := Pos + 1;
         end loop;
         --  Read number
         if Pos <= S'Last and then S (Pos) in '0' .. '9' then
            declare
               Val : Natural := 0;
            begin
               while Pos <= S'Last and then S (Pos) in '0' .. '9' loop
                  Val :=
                    Val * 10 + (Character'Pos (S (Pos)) - Character'Pos ('0'));
                  Pos := Pos + 1;
               end loop;
               return Val;
            end;
         end if;
         return 0;
      end JSON_Get;
   begin
      Summary := (others => <>);
      begin
         Open (F, In_File, File_Path);
      exception
         when others =>
            Success := False;
            return;
      end;
      begin
         while not End_Of_File (F) loop
            Get_Line (F, Line, Last);
            declare
               S : String renames Line (1 .. Last);
            begin
               if JSON_Get (S, "total_vcs") > 0 then
                  Summary.Total_VCs := JSON_Get (S, "total_vcs");
               end if;
               if JSON_Get (S, "proved_vcs") > 0 then
                  Summary.Proved_VCs := JSON_Get (S, "proved_vcs");
               end if;
               if JSON_Get (S, "unproved_vcs") > 0 then
                  Summary.Unproved := JSON_Get (S, "unproved_vcs");
               end if;
               if JSON_Get (S, "flow_deps") > 0 then
                  Summary.Flow_Checks := JSON_Get (S, "flow_deps");
               end if;
               if JSON_Get (S, "flow_proved") > 0 then
                  Summary.Flow_Proved := JSON_Get (S, "flow_proved");
               end if;
               if JSON_Get (S, "runtime_checks") > 0 then
                  Summary.Runtime_Checks := JSON_Get (S, "runtime_checks");
               end if;
               if JSON_Get (S, "runtime_proved") > 0 then
                  Summary.Runtime_Proved := JSON_Get (S, "runtime_proved");
               end if;
               if JSON_Get (S, "assertions") > 0 then
                  Summary.Assertions := JSON_Get (S, "assertions");
               end if;
               if JSON_Get (S, "assert_proved") > 0 then
                  Summary.Assert_Proved := JSON_Get (S, "assert_proved");
               end if;
            end;
         end loop;
      exception
         when others =>
            Close (F);
            raise;
      end;
      Close (F);
      Summary.Level := Determine_SPARK_Level (Summary);
      Success := Summary.Total_VCs > 0;
   end Parse_Prove_JSON;

end Adacovex.Parsers.GNATprove;
