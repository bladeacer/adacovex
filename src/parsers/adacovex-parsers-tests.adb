with Ada.Text_IO;

package body Adacovex.Parsers.Tests is

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

   function Starts_With (S : String; Pre : String) return Boolean
   with SPARK_Mode => On
   is
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

   --  Parse the integer that immediately follows a keyword in a line,
   --  skipping any intervening spaces.  Returns 0 when absent.  Digit runs
   --  longer than the Natural capacity stop accumulating (previously the
   --  unguarded accumulation raised Constraint_Error at runtime).
   function Number_After (S : String; Key : String) return Natural
   with SPARK_Mode => On, Pre => S'First >= 1 and S'Last < Natural'Last
   is
   begin
      if Key'Length <= S'Length then
         for I in S'First .. S'Last - Key'Length + 1 loop
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
                     declare
                        Digit : constant Natural :=
                          Character'Pos (S (J)) - Character'Pos ('0');
                     begin
                        if Num <= (Natural'Last - Digit) / 10 then
                           Num := Num * 10 + Digit;
                           J := J + 1;
                           Got := True;
                        else
                           Got := True;
                           exit;
                        end if;
                     end;
                  end loop;
                  if Got then
                     return Num;
                  end if;
               end;
            end if;
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
   with SPARK_Mode => On, Pre => S'First >= 1 and S'Last < Natural'Last
   is
   begin
      if Word'Length <= S'Length then
         for I in S'First .. S'Last - Word'Length + 1 loop
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
                                 declare
                                    Digit : constant Natural :=
                                      Character'Pos (S (C))
                                      - Character'Pos ('0');
                                 begin
                                    if Num <= (Natural'Last - Digit) / 10 then
                                       Num := Num * 10 + Digit;
                                    else
                                       exit;
                                    end if;
                                 end;
                              end loop;
                              return Num;
                           end;
                        end if;
                     end;
                  end if;
               end;
            end if;
         end loop;
      end if;
      return 0;
   end Number_Before_Word;

   procedure Parse_Test_Result
     (File_Path : String;
      Summary   : out Types.Implementation.Test_Summary;
      Success   : out Boolean)
   is
      use Ada.Text_IO;
      F    : File_Type;
      Line : String (1 .. Types.Max_Line);
      Last : Natural;
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
                     Parts    :
                       array (1 .. 5) of String (1 .. Types.Max_Desc_Str);
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
                           if Part_Ct <= 5
                             and then Part_Len (Part_Ct) < Types.Max_Desc_Str
                           then
                              Part_Len (Part_Ct) := Part_Len (Part_Ct) + 1;
                              Parts (Part_Ct) (Part_Len (Part_Ct)) := Line (I);
                           end if;
                        end if;
                     end loop;

                     if Part_Ct >= 3 then
                        declare
                           Is_Number : Boolean := True;
                           TCount    : Natural := 0;
                        begin
                           for I in 1 .. Part_Len (3) loop
                              if Parts (3) (I) in '0' .. '9' then
                                 TCount :=
                                   TCount
                                   * 10
                                   + (Character'Pos (Parts (3) (I))
                                      - Character'Pos ('0'));
                              else
                                 Is_Number := False;
                              end if;
                           end loop;

                           if Is_Number and then TCount > 0 then
                              declare
                                 Cat : Types.Test_Metrics :=
                                   (Cat_Len    => Part_Len (2),
                                    Test_Count => TCount,
                                    others     => <>);
                              begin
                                 for I in 1 .. Part_Len (2) loop
                                    Cat.Category (I) := Parts (2) (I);
                                 end loop;

                                 if Part_Ct >= 4 and then Part_Len (4) >= 4
                                 then
                                    if Parts (4) (1 .. 4) = "PASS" then
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
               end if;
            end;

            -- Look for "Passed:" keyword
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

            -- TAP (Test Anything Protocol): "ok 1 - name" / "not ok 2 - name".
            -- Each line is one test, so pass/fail counters accumulate.
            declare
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
            end;

            -- Automake test-suite style: "PASS: name" / "FAIL: name".
            declare
               T : constant String := Trim_Left (Line (1 .. Last));
            begin
               if Starts_With (T, "PASS:") then
                  Summary.Total_Passed := Summary.Total_Passed + 1;
               elsif Starts_With (T, "FAIL:") then
                  Summary.Total_Failed := Summary.Total_Failed + 1;
               end if;
            end;

            -- Maven Surefire style: "Tests run: N, Failures: M, Errors: E".
            -- Last summary line wins, matching the "Passed:"/"Failed:" rule.
            declare
               Tests_Run : Natural :=
                 Number_After (Line (1 .. Last), "Tests run:");
               Failures  : Natural :=
                 Number_After (Line (1 .. Last), "Failures:");
               Errors    : Natural :=
                 Number_After (Line (1 .. Last), "Errors:");
            begin
               if Tests_Run > 0 then
                  Summary.Total_Failed := Failures + Errors;
                  if Failures + Errors < Tests_Run then
                     Summary.Total_Passed := Tests_Run - Failures - Errors;
                  else
                     Summary.Total_Passed := 0;
                  end if;
               end if;
            end;

            -- Unity style: "N Tests M Failures [K Ignored]".
            declare
               N_Tests    : constant Natural :=
                 Number_Before_Word (Line (1 .. Last), "Tests");
               N_Failures : constant Natural :=
                 Number_Before_Word (Line (1 .. Last), "Failures");
            begin
               if N_Tests > 0 then
                  Summary.Total_Failed := N_Failures;
                  if N_Failures < N_Tests then
                     Summary.Total_Passed := N_Tests - N_Failures;
                  else
                     Summary.Total_Passed := 0;
                  end if;
               end if;
            end;
         end loop;
      exception
         when others =>
            Close (F);
            raise;
      end;

      Close (F);
      Success := True;
   end Parse_Test_Result;

end Adacovex.Parsers.Tests;
