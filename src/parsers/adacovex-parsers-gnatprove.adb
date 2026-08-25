with Ada.Text_IO;
with Ada.Directories;

package body Adacovex.Parsers.GNATprove is

   use Ada.Directories;

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

   --  Return the numeric value in the N-th column of a gnatprove summary row
   --  (1-based, so column 1 is the leading label).  Columns are delimited by
   --  runs of two or more spaces, which is how gnatprove aligns its summary
   --  table regardless of version: every layout since the modern headers
   --  (`Total | Flow | Provers | Justified | Unproved`) pads to at least two
   --  separators between fields, while a single space stays inside a field
   --  (as in `59 (12%)` or `326 (65%)`).  A "." or absent column returns 0.
   --  This reconciles gnatprove v15 vs v16 output: older releases report an
   --  unproved count such as `118 (23%)` in the last column, newer ones
   --  `450 (88%)` with a "Provers" column of ".", but the column positions
   --  (Justified = 5, Unproved = 6) are stable across both.
   --  Count the columns in a gnatprove summary row (same 2+ space run
   --  rule as Get_Column_Number).  Used to tell legacy 3-column category
   --  rows (label, total, proved) from the modern 5+ column layout
   --  (label, total, flow, provers, justified, unproved).
   function Get_Column_Count (Row : String) return Natural;
   function Get_Column_Count (Row : String) return Natural is
      J     : Natural := Row'First;
      Count : Natural := 0;
   begin
      while J <= Row'Last and then Row (J) = ' ' loop
         J := J + 1;
      end loop;
      if J > Row'Last then
         return 0;
      end if;
      Count := 1;
      loop
         while J <= Row'Last and then Row (J) /= ' ' loop
            J := J + 1;
         end loop;
         exit when J > Row'Last;
         --  A run of 2+ spaces separates columns; a single space stays
         --  inside the field (as in `1 (CVC5)`).
         if J + 1 <= Row'Last and then Row (J + 1) = ' ' then
            Count := Count + 1;
         end if;
         while J <= Row'Last and then Row (J) = ' ' loop
            J := J + 1;
         end loop;
      end loop;
      return Count;
   end Get_Column_Count;

   function Get_Column_Number (Row : String; N : Positive) return Natural;
   function Get_Column_Number (Row : String; N : Positive) return Natural is
      Field  : Positive := 1;
      J      : Natural := Row'First;
      Run_Of : Natural;
      FS     : Natural := 0;
      FE     : Natural := 0;
   begin
      --  Skip leading spaces to reach the first column start.
      while J <= Row'Last and then Row (J) = ' ' loop
         J := J + 1;
      end loop;
      if J > Row'Last then
         return 0;
      end if;
      FS := J;
      loop
         --  Scan the current field's non-space run; FE is its last index.
         while J <= Row'Last and then Row (J) /= ' ' loop
            J := J + 1;
         end loop;
         FE := J - 1;
         if Field = N then
            --  Read the number within THIS field only, so a later "." or a
            --  trailing numeric column can never leak into an earlier one.
            return Get_Nth_Number_Raw (Row (FS .. FE), 1);
         end if;
         exit when J > Row'Last;
         --  Consume the separating space run.
         Run_Of := 1;
         while J + Run_Of <= Row'Last and then Row (J + Run_Of) = ' ' loop
            Run_Of := Run_Of + 1;
         end loop;
         if Run_Of >= 2 then
            --  A run of 2+ spaces ends the column and starts the next one.
            Field := Field + 1;
            J := J + Run_Of;
            FS := J;
         else
            --  A single space stays inside the field (e.g. `1 (CVC5)`).
            J := J + Run_Of;
         end if;
      end loop;
      return 0;
   end Get_Column_Number;

   procedure Parse_Prove_Out
     (File_Path : String;
      Summary   : out Types.Proof_Summary;
      Success   : out Boolean)
   is
      use Ada.Text_IO;
      F        : File_Type;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Overflow : Boolean;
      Line_Num : Natural := 0;
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
            Line_Num := Line_Num + 1;
            Adacovex.Parsers.Read_Line
              (F, File_Path, Line_Num, Line, Last, Overflow);
            if Overflow then
               --  A physical line longer than Max_Line is drained and
               --  reported by Read_Line; parsing stops so no partial proof
               --  summary is passed downstream.
               Summary := (others => <>);
               Close (F);
               Success := False;
               return;
            end if;

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

                     --  Per-category rows share the summary's column layout
                     --  (Total | Flow | Provers | Justified | Unproved),
                     --  so the count is column 2 and the proved count is
                     --  Total - Justified - Unproved -- NOT the Flow column:
                     --  gnatprove 16 splits flow analysis into "Data
                     --  Dependencies" (checked) and "Flow Dependencies"
                     --  (proved implicitly), and Run-time/Assertions/
                     --  Functional rows carry their proved VCs in the
                     --  Provers column.  Counting only the Flow column would
                     --  report those as unproved (and Termination as 73 of
                     --  94 on the self-target).
                     --  The checked count is always the Total column
                     --  (column 2), in every summary layout.
                     function Row_Count (Row : String) return Natural is
                     begin
                        return Get_Column_Number (Row, 2);
                     end Row_Count;

                     --  The proved count per category: modern summaries
                     --  (v15/v16, 5+ columns incl. Justified/Unproved) prove
                     --  every category except flow via the Provers column,
                     --  so Proved = Total - Justified - Unproved.  Legacy
                     --  summaries (3 columns: label, total, proved) carry
                     --  the proved count in column 3 directly.
                     function Row_Proved (Row : String) return Natural is
                     begin
                        if Get_Column_Count (Row) >= 5 then
                           return
                             Get_Column_Number (Row, 2)
                             - Get_Column_Number (Row, 5)
                             - Get_Column_Number (Row, 6);
                        else
                           return Get_Column_Number (Row, 3);
                        end if;
                     end Row_Proved;
                  begin
                     if Row'Length >= 17
                       and then Row (Row'First .. Row'First + 4) = "Flow "
                     then
                        --  Additive like the Data row below: the two rows
                        --  share the Flow category and gnatprove prints
                        --  "Data Dependencies" before "Flow Dependencies",
                        --  so a plain assignment would clobber the sum.
                        Summary.Flow_Checks :=
                          Summary.Flow_Checks + Row_Count (Row);
                        Summary.Flow_Proved :=
                          Summary.Flow_Proved + Row_Proved (Row);
                     end if;

                     --  gnatprove 16 reports the checked flow VCs under
                     --  "Data Dependencies" (the "Flow Dependencies" row is
                     --  proved implicitly and shows ".").  Both rows belong
                     --  to the dashboard's single "Flow" category, so they
                     --  are summed -- gnatprove 15 output has no Data row
                     --  and is unchanged.
                     if Row'Length >= 15
                       and then Row (Row'First .. Row'First + 4) = "Data "
                     then
                        Summary.Flow_Checks :=
                          Summary.Flow_Checks + Row_Count (Row);
                        Summary.Flow_Proved :=
                          Summary.Flow_Proved + Row_Proved (Row);
                     end if;

                     if Row'Length >= 15
                       and then Row (Row'First .. Row'First + 3) = "Run-"
                     then
                        Summary.Runtime_Checks := Row_Count (Row);
                        Summary.Runtime_Proved := Row_Proved (Row);
                     end if;

                     if Row'Length >= 10
                       and then Row (Row'First .. Row'First + 3) = "Asse"
                     then
                        Summary.Assertions := Row_Count (Row);
                        Summary.Assert_Proved := Row_Proved (Row);
                     end if;

                     if Row'Length >= 11
                       and then Row (Row'First .. Row'First + 3) = "Func"
                     then
                        Summary.Functional_Ct := Row_Count (Row);
                        Summary.Functional_Proved := Row_Proved (Row);
                     end if;

                     if Row'Length >= 11
                       and then Row (Row'First .. Row'First + 3) = "Term"
                     then
                        Summary.Termination_Ct := Row_Count (Row);
                        Summary.Termination_Proved := Row_Proved (Row);
                     end if;

                     if Row'Length >= 5
                       and then Row (Row'First .. Row'First + 4) = "Total"
                     then
                        --  Column layout (stable across gnatprove v15/v16):
                        --    Total | Flow | Provers | Justified | Unproved
                        --  Columns are aligned with runs of 2+ spaces, so a
                        --  field-split extraction is version-independent:
                        --  v15 fills the Provers column (e.g. `326 (65%)`)
                        --  while v16 may show `.`, but Justified is always
                        --  column 5 and Unproved always column 6.
                        --  Proved = solved-by-flow + solved-by-provers,
                        --  equivalently Total - Justified - Unproved.
                        Summary.Total_VCs := Get_Column_Number (Row, 2);
                        Summary.Justified := Get_Column_Number (Row, 5);
                        Summary.Unproved := Get_Column_Number (Row, 6);
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
                        Summary.Init_Checks := Row_Count (Row);
                        Summary.Init_Proved := Row_Proved (Row);
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
     (Summary : Types.Proof_Summary) return Types.SPARK_Level
   with SPARK_Mode => On
   is
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

   function Find_Prove_Output (Target_Dir : String) return String is
      function Exists_At (P : String) return Boolean is
      begin
         return Exists (P) and then Kind (P) = Ordinary_File;
      end Exists_At;
   begin
      if Exists_At (Target_Dir & "/obj/gnatprove/gnatprove.out") then
         return Target_Dir & "/obj/gnatprove/gnatprove.out";
      end if;
      if Exists_At (Target_Dir & "/gnatprove.out") then
         return Target_Dir & "/gnatprove.out";
      end if;
      if Exists_At (Target_Dir & "/gnatprove/gnatprove.out") then
         return Target_Dir & "/gnatprove/gnatprove.out";
      end if;
      return "";
   end Find_Prove_Output;

   procedure Parse_Prove_JSON
     (File_Path : String;
      Summary   : out Types.Proof_Summary;
      Success   : out Boolean)
   is
      use Ada.Text_IO;
      F        : File_Type;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Overflow : Boolean;
      Line_Num : Natural := 0;
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
            Line_Num := Line_Num + 1;
            Adacovex.Parsers.Read_Line
              (F, File_Path, Line_Num, Line, Last, Overflow);
            if Overflow then
               --  A physical line longer than Max_Line is drained and
               --  reported by Read_Line; parsing stops so no partial proof
               --  summary is passed downstream.
               Summary := (others => <>);
               Close (F);
               Success := False;
               return;
            end if;
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
