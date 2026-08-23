with Ada.Text_IO;
with Ada.Directories;

package body Adacovex.Parsers.Tests is

   use Ada.Directories;

   --  Strip leading spaces from a string slice.
   function Trim_Left (S : String) return String
   with SPARK_Mode => On, Pre => S'First >= 1 and S'Last < Natural'Last
   is
      F : Natural := S'First;
   begin
      while F <= S'Last and then S (F) = ' ' loop
         pragma Loop_Invariant (F >= S'First);
         pragma Loop_Variant (Increases => F);
         F := F + 1;
      end loop;
      if F > S'Last then
         return "";
      end if;
      return S (F .. S'Last);
   end Trim_Left;

   function Starts_With (S : String; Pre : String) return Boolean is
   begin
      if Pre'Length > S'Length then
         return False;
      end if;
      for I in Pre'Range loop
         if S (S'First + (I - Pre'First)) /= Pre (I) then
            return False;
         end if;
      end loop;
      return True;
   end Starts_With;

   --  Numeric value of a decimal digit character (0 .. 9).  A case
   --  statement avoids the Character'Pos subtraction so the range check is
   --  discharged by plain case analysis instead of character arithmetic.
   function Digit_Value (C : Character) return Natural
   with
     SPARK_Mode => On,
     Pre        => C in '0' .. '9',
     Post       => Digit_Value'Result <= 9
   is
   begin
      case C is
         when '0'    =>
            return 0;

         when '1'    =>
            return 1;

         when '2'    =>
            return 2;

         when '3'    =>
            return 3;

         when '4'    =>
            return 4;

         when '5'    =>
            return 5;

         when '6'    =>
            return 6;

         when '7'    =>
            return 7;

         when '8'    =>
            return 8;

         when '9'    =>
            return 9;

         when others =>
            return 0;
      end case;
   end Digit_Value;

   --  Parse the integer that immediately follows a keyword in a line,
   --  skipping any intervening spaces.  Returns 0 when absent.  Digit runs
   --  longer than the Natural capacity stop accumulating (previously the
   --  unguarded accumulation raised Constraint_Error at runtime).
   function Number_After (S : String; Key : String) return Natural
   with
     SPARK_Mode => On,
     Pre        => S'First >= 1 and S'Last < Natural'Last and Key'Length >= 1
   is
      I : Natural := S'First;
   begin
      if Key'Length <= S'Length then
         while I <= S'Last - Key'Length + 1 loop
            pragma Loop_Invariant (I in S'First .. S'Last - Key'Length + 2);
            pragma Loop_Variant (Increases => I);
            if S (I .. I + Key'Length - 1) = Key then
               declare
                  J   : Natural := I + Key'Length;
                  Num : Natural := 0;
                  Got : Boolean := False;
               begin
                  while J <= S'Last and then S (J) = ' ' loop
                     pragma Loop_Invariant (J >= S'First);
                     pragma Loop_Variant (Increases => J);
                     J := J + 1;
                  end loop;
                  while J <= S'Last and then S (J) in '0' .. '9' loop
                     pragma Loop_Invariant (J >= S'First);
                     pragma Loop_Variant (Increases => J);
                     if Num <= Natural'Last / 10 - 1 then
                        Num := Num * 10 + Digit_Value (S (J));
                        J := J + 1;
                        Got := True;
                     else
                        Got := True;
                        exit;
                     end if;
                  end loop;
                  if Got then
                     return Num;
                  end if;
               end;
            end if;
            I := I + 1;
         end loop;
      end if;
      return 0;
   end Number_After;

   --  Parse the integer that immediately precedes a whole word in a line.
   --  The word must be preceded by digits and followed by a non-letter
   --  (or end of line).  Returns 0 when absent.  Used for the
   --  "N Tests M Failures" summary style.  Digit runs longer than the
   --  Natural capacity stop accumulating (previously a runtime
   --  Constraint_Error on overflow).
   function Number_Before_Word (S : String; Word : String) return Natural
   with
     SPARK_Mode => On,
     Pre        => S'First >= 1 and S'Last < Natural'Last and Word'Length >= 1
   is
      I : Natural := S'First;
   begin
      if Word'Length <= S'Length then
         while I <= S'Last - Word'Length + 1 loop
            pragma Loop_Invariant (I in S'First .. S'Last - Word'Length + 2);
            pragma Loop_Variant (Increases => I);
            if S (I .. I + Word'Length - 1) = Word then
               declare
                  J  : constant Natural := I + Word'Length;
                  OK : Boolean := True;
               begin
                  if J <= S'Last and then S (J) in 'a' .. 'z' | 'A' .. 'Z' then
                     OK := False;
                  end if;
                  if OK then
                     declare
                        K : Natural := I - 1;
                     begin
                        while K >= S'First and then S (K) = ' ' loop
                           pragma Loop_Invariant (K in S'First .. S'Last);
                           pragma Loop_Variant (Decreases => K);
                           K := K - 1;
                        end loop;
                        if K >= S'First and then S (K) in '0' .. '9' then
                           pragma Assert (K in S'First .. S'Last);
                           declare
                              DStart : Natural := K;
                              Num    : Natural := 0;
                           begin
                              while DStart > S'First
                                and then S (DStart - 1) in '0' .. '9'
                              loop
                                 pragma
                                   Loop_Invariant
                                     (DStart in S'First .. S'Last);
                                 pragma
                                   Loop_Invariant
                                     (for all Q in DStart .. K =>
                                        S (Q) in '0' .. '9');
                                 pragma Loop_Variant (Decreases => DStart);
                                 DStart := DStart - 1;
                              end loop;
                              for C in DStart .. K loop
                                 pragma Loop_Invariant (C in S'First .. K);
                                 pragma
                                   Loop_Invariant
                                     (for all Q in C .. K =>
                                        S (Q) in '0' .. '9');
                                 if Num <= Natural'Last / 10 - 1 then
                                    Num := Num * 10 + Digit_Value (S (C));
                                 else
                                    exit;
                                 end if;
                              end loop;
                              return Num;
                           end;
                        end if;
                     end;
                  end if;
               end;
            end if;
            I := I + 1;
         end loop;
      end if;
      return 0;
   end Number_Before_Word;

   --  A markdown table row split into its `|`-separated cells.  Cells are
   --  capped at Types.Max_Desc_Str; longer cells are truncated, and cells
   --  past the 5th are ignored.
   Max_Cells : constant := 5;
   type Parts_Array is
     array (1 .. Max_Cells) of String (1 .. Types.Max_Desc_Str);
   type Part_Len_Array is array (1 .. Max_Cells) of Natural;

   --  Length of the cell at Idx with trailing spaces trimmed (0 when the
   --  cell is empty or all spaces).  Markdown tables right-pad cells to the
   --  column separator, so a `| 67 |` count cell is stored as "67 ".
   function Cell_Trimmed_Len
     (Parts : Parts_Array; Part_Len : Part_Len_Array; Idx : Natural)
      return Natural
   is
      L : Natural := Part_Len (Idx);
   begin
      while L > 0 and then Parts (Idx) (L) = ' ' loop
         L := L - 1;
      end loop;
      return L;
   end Cell_Trimmed_Len;

   --  True when the cell at Idx holds only digits (ignoring padding
   --  spaces) -- i.e. it is a test count.  Empty cells and cells with any
   --  non-digit (a category name, a PASS/FAIL status, a `|---|---|`
   --  separator, a header row) are not counts, so headers and separators
   --  are skipped naturally.
   function Is_Number_Cell
     (Parts : Parts_Array; Part_Len : Part_Len_Array; Idx : Natural)
      return Boolean
   is
      L : constant Natural := Cell_Trimmed_Len (Parts, Part_Len, Idx);
   begin
      if L = 0 then
         return False;
      end if;
      for I in 1 .. L loop
         if Parts (Idx) (I) not in '0' .. '9' then
            return False;
         end if;
      end loop;
      return True;
   end Is_Number_Cell;

   --  Numeric value of the digit-only cell at Idx (0 when empty).  Callers
   --  guard with Is_Number_Cell first.
   function Cell_Count
     (Parts : Parts_Array; Part_Len : Part_Len_Array; Idx : Natural)
      return Natural
   is
      N : Natural := 0;
   begin
      for I in 1 .. Cell_Trimmed_Len (Parts, Part_Len, Idx) loop
         N := N * 10 + (Character'Pos (Parts (Idx) (I)) - Character'Pos ('0'));
      end loop;
      return N;
   end Cell_Count;

   --  Parse one markdown table row and append it to Summary.Categories
   --  when it carries a positive test count.  Two layouts are accepted:
   --
   --    A: "| - | Category | N | PASS |" -- the AUnit-style report layout
   --       with a leading index cell; the count is cell 3.
   --    B: "| Category | N | PASS |"       -- plain table; count is cell 2.
   --
   --  In both layouts the count cell must be all digits (so header and
   --  separator rows are skipped regardless of layout), the category name
   --  is the cell before the count, and the status is the cell after it
   --  (any non-"PASS" status counts as FAIL).  Category rows ADD their
   --  counts to the totals; a trailing "Passed:"/"Failed:" footer line
   --  overrides the totals (see Parse_Passed_Failed_Line).
   procedure Parse_Table_Row
     (Line    : String;
      Last    : Natural;
      Summary : in out Types.Implementation.Test_Summary)
   is
      First_Pipe : Natural := 0;
   begin
      for I in 1 .. Last loop
         if Line (I) = '|' then
            First_Pipe := I;
            exit;
         end if;
      end loop;
      if First_Pipe = 0 then
         return;
      end if;

      declare
         Parts    : Parts_Array;
         Part_Len : Part_Len_Array := (others => 0);
         Part_Ct  : Natural := 0;
         In_Part  : Boolean := False;
      begin
         --  Split after the first `|`: cells start at the first non-space
         --  after a separator and run to the next `|` (spaces inside a
         --  cell are kept, so category names survive verbatim).
         for I in First_Pipe + 1 .. Last loop
            if Line (I) = '|' then
               In_Part := False;
            elsif not In_Part then
               if Line (I) /= ' ' then
                  Part_Ct := Part_Ct + 1;
                  In_Part := True;
                  if Part_Ct <= Max_Cells then
                     Part_Len (Part_Ct) := 1;
                     Parts (Part_Ct) (1) := Line (I);
                  end if;
               end if;
            else
               if Part_Ct <= Max_Cells
                 and then Part_Len (Part_Ct) < Types.Max_Desc_Str
               then
                  Part_Len (Part_Ct) := Part_Len (Part_Ct) + 1;
                  Parts (Part_Ct) (Part_Len (Part_Ct)) := Line (I);
               end if;
            end if;
         end loop;

         --  Locate the numeric count cell: layout A puts it at cell 3,
         --  layout B at cell 2.  A header/separator row has no numeric
         --  cell and is skipped.  (A row where BOTH cells 2 and 3 are
         --  numeric is layout A -- a numeric index cell with a numeric
         --  category name is not a realistic case.)
         declare
            Count_Idx : Natural := 0;
         begin
            if Part_Ct >= 3 and then Is_Number_Cell (Parts, Part_Len, 3) then
               Count_Idx := 3;
            elsif Part_Ct >= 2 and then Is_Number_Cell (Parts, Part_Len, 2)
            then
               Count_Idx := 2;
            end if;

            if Count_Idx > 0 then
               declare
                  TCount     : constant Natural :=
                    Cell_Count (Parts, Part_Len, Count_Idx);
                  Name_Idx   : constant Natural :=
                    (if Count_Idx = 3 then 2 else 1);
                  Status_Idx : constant Natural := Count_Idx + 1;
               begin
                  if TCount > 0 then
                     declare
                        Cat : Types.Test_Metrics :=
                          (Cat_Len    =>
                             Cell_Trimmed_Len (Parts, Part_Len, Name_Idx),
                           Test_Count => TCount,
                           others     => <>);
                     begin
                        for I in 1 .. Cat.Cat_Len loop
                           Cat.Category (I) := Parts (Name_Idx) (I);
                        end loop;

                        if Part_Ct >= Status_Idx
                          and then Part_Len (Status_Idx) >= 4
                        then
                           if Parts (Status_Idx) (1 .. 4) = "PASS" then
                              Cat.Status := Types.Pass;
                              Summary.Total_Passed :=
                                Summary.Total_Passed + TCount;
                           else
                              Cat.Status := Types.Fail;
                              Summary.Total_Failed :=
                                Summary.Total_Failed + TCount;
                           end if;
                        end if;
                        Summary.Categories.Append (Cat);
                     end;
                  end if;
               end;
            end if;
         end;
      end;
   end Parse_Table_Row;

   --  Parse the "Passed:" / "Failed:" summary lines (adacovex native
   --  test_result.md footer).  The last occurrence wins.
   procedure Parse_Passed_Failed_Line
     (Line    : String;
      Last    : Natural;
      Summary : in out Types.Implementation.Test_Summary) is
   begin
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
                  Num :=
                    Num
                    * 10
                    + (Character'Pos (Line (J)) - Character'Pos ('0'));
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
                  Num :=
                    Num
                    * 10
                    + (Character'Pos (Line (J)) - Character'Pos ('0'));
                  J := J + 1;
               end loop;
               Summary.Total_Failed := Num;
            end;
         end if;
      end loop;
   end Parse_Passed_Failed_Line;

   --  TAP: "ok 1 - name" / "not ok 2 - name" counters.
   procedure Parse_TAP_Line
     (Line    : String;
      Last    : Natural;
      Summary : in out Types.Implementation.Test_Summary)
   is
      T : constant String := Trim_Left (Line (1 .. Last));
   begin
      if Starts_With (T, "not ok")
        and then (T'Length = 6 or else T (T'First + 6) = ' ')
      then
         Summary.Total_Failed := Summary.Total_Failed + 1;
      elsif Starts_With (T, "ok")
        and then (T'Length = 2 or else T (T'First + 2) = ' ')
      then
         Summary.Total_Passed := Summary.Total_Passed + 1;
      end if;
   end Parse_TAP_Line;

   --  Automake: "PASS: name" / "FAIL: name".
   procedure Parse_Automake_Line
     (Line : String; Summary : in out Types.Implementation.Test_Summary)
   is
      T : constant String := Trim_Left (Line (1 .. Line'Last));
   begin
      if Starts_With (T, "PASS:") then
         Summary.Total_Passed := Summary.Total_Passed + 1;
      elsif Starts_With (T, "FAIL:") then
         Summary.Total_Failed := Summary.Total_Failed + 1;
      end if;
   end Parse_Automake_Line;

   --  Maven Surefire: "Tests run: N, Failures: M, Errors: E".
   --  Last summary line wins, matching the "Passed:"/"Failed:" rule.
   procedure Parse_Surefire_Line
     (Line : String; Summary : in out Types.Implementation.Test_Summary)
   is
      Tests_Run : Natural := Number_After (Line, "Tests run:");
      Failures  : Natural := Number_After (Line, "Failures:");
      Errors    : Natural := Number_After (Line, "Errors:");
   begin
      if Tests_Run > 0 then
         Summary.Total_Failed := Failures + Errors;
         if Failures + Errors < Tests_Run then
            Summary.Total_Passed := Tests_Run - Failures - Errors;
         else
            Summary.Total_Passed := 0;
         end if;
      end if;
   end Parse_Surefire_Line;

   --  Unity: "N Tests M Failures [K Ignored]".
   procedure Parse_Unity_Line
     (Line : String; Summary : in out Types.Implementation.Test_Summary)
   is
      N_Tests    : constant Natural := Number_Before_Word (Line, "Tests");
      N_Failures : constant Natural := Number_Before_Word (Line, "Failures");
   begin
      if N_Tests > 0 then
         Summary.Total_Failed := N_Failures;
         if N_Failures < N_Tests then
            Summary.Total_Passed := N_Tests - N_Failures;
         else
            Summary.Total_Passed := 0;
         end if;
      end if;
   end Parse_Unity_Line;

   procedure Parse_Test_Result
     (File_Path : String;
      Summary   : out Types.Implementation.Test_Summary;
      Success   : out Boolean)
   is
      use Ada.Text_IO;
      F        : File_Type;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Overflow : Boolean;
      Line_Num : Natural := 0;
   begin
      Summary :=
        (Categories   =>
           Types.Implementation.Test_Metrics_Vectors.Empty_Vector,
         Total_Passed => 0,
         Total_Failed => 0);

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
               --  A physical line longer than the maximum is drained and
               --  reported by Read_Line; parsing stops so no partial test
               --  summary is passed downstream.
               Summary :=
                 (Categories   =>
                    Types.Implementation.Test_Metrics_Vectors.Empty_Vector,
                  Total_Passed => 0,
                  Total_Failed => 0);
               Close (F);
               Success := False;
               return;
            end if;

            Parse_Table_Row (Line (1 .. Last), Last, Summary);

            Parse_Passed_Failed_Line (Line (1 .. Last), Last, Summary);
            Parse_TAP_Line (Line (1 .. Last), Last, Summary);
            Parse_Automake_Line (Line (1 .. Last), Summary);
            Parse_Surefire_Line (Line (1 .. Last), Summary);
            Parse_Unity_Line (Line (1 .. Last), Summary);
         end loop;
      exception
         when others =>
            Close (F);
            raise;
      end;

      Close (F);
      Success := True;
   end Parse_Test_Result;

   --  Conventional test-result file names, tried in order at the project
   --  root and under docs/.  Covers common Markdown, plain-text and log
   --  summary conventions in addition to adacovex's native test_result.md.
   type Name_Array is array (Positive range <>) of String (1 .. 24);
   Candidates : constant Name_Array :=
     ("test_result.md          ",
      "test_results.md         ",
      "test-result.md          ",
      "test-results.md         ",
      "test_report.md          ",
      "test-report.md          ",
      "test_output.md          ",
      "test-output.md          ",
      "test_result.txt         ",
      "test_results.txt        ",
      "test-result.txt         ",
      "test-results.txt        ",
      "test_report.txt         ",
      "test-report.txt         ",
      "test_output.txt         ",
      "test-output.txt         ",
      "tests.md                ",
      "tests.txt               ",
      "test_results.log        ",
      "test-results.log        ",
      "docs/test_result.md     ",
      "docs/test_results.md    ",
      "docs/test-result.md     ",
      "docs/test-results.md    ");

   --  Strip trailing spaces from a string slice.
   function Trim_Right (S : String) return String
   with SPARK_Mode => On, Pre => S'Last >= 1 and S'Last < Natural'Last
   is
      L : Natural := S'Last;
   begin
      while L >= S'First and then S (L) = ' ' loop
         pragma Loop_Invariant (L in S'First - 1 .. S'Last);
         pragma Loop_Variant (Decreases => L);
         L := L - 1;
      end loop;
      if L < S'First then
         return "";
      end if;
      return S (S'First .. L);
   end Trim_Right;

   --  Return the path of the first existing conventional test-result file
   --  under Target_Dir, or "" if none is present.  Used by the result cache
   --  to key a cached test summary to the exact artifact analyzed.
   function Find_Test_Result (Target_Dir : String) return String is
   begin
      for I in Candidates'Range loop
         declare
            P : constant String :=
              Target_Dir & "/" & Trim_Right (Candidates (I));
         begin
            if Exists (P) and then Kind (P) = Ordinary_File then
               return P;
            end if;
         end;
      end loop;
      return "";
   end Find_Test_Result;

   procedure Parse_Test_Result_From_Project
     (Target_Dir : String;
      Summary    : out Types.Implementation.Test_Summary;
      Success    : out Boolean)
   is
      Tmp : Types.Implementation.Test_Summary;
      OK  : Boolean;
      Pth : constant String := Find_Test_Result (Target_Dir);
   begin
      if Pth'Length > 0 then
         Parse_Test_Result (Pth, Tmp, OK);
         if OK then
            Summary := Tmp;
            Success := True;
            return;
         end if;
      end if;
      Success := False;
   end Parse_Test_Result_From_Project;

end Adacovex.Parsers.Tests;
