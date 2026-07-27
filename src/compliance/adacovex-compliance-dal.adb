with Ada.Text_IO;

package body Adacovex.Compliance.DAL is

   use type Types.SPARK_Level;
   use type Types.DAL_Status;

   procedure Assess_DAL_C
     (Target_Dir     : String;
      Packages       : Types.Package_Array;
      Pkg_Count      : Natural;
      Proof_Summary  : Types.Proof_Summary;
      Test_Summary   : Types.Test_Summary;
      Assessment     : out Types.DAL_Assessment)
   is
      HLR_Path : String (1 .. Types.Max_Path);
      HLR_Len  : Natural;
      LLR_Path : String (1 .. Types.Max_Path);
      LLR_Len  : Natural;

      HLR_List : Adacovex.Parsers.DO178C.HLR_Array;
      HLR_Count : Natural := 0;
      LLR_List  : Adacovex.Parsers.DO178C.LLR_Array;
      LLR_Count : Natural := 0;

      HLR_Success : Boolean;
      LLR_Success : Boolean;

      Failed_Idx : Natural := 0;
   begin
      Assessment := (others => <>);
      Assessment.Target_DAL := Types.DAL_C;

      -- Build paths to HLR.md and LLR.md
      declare
         Dir : constant String := Target_Dir & "/docs/compliance";
      begin
         HLR_Len := Dir'Length + 7;
         for I in 1 .. Dir'Length loop
            HLR_Path (I) := Dir (Dir'First + I - 1);
         end loop;
         HLR_Path (Dir'Length + 1 .. Dir'Length + 7) := "/HLR.md";
         LLR_Path (1 .. Dir'Length) := HLR_Path (1 .. Dir'Length);
         LLR_Len := Dir'Length + 7;
         LLR_Path (Dir'Length + 1 .. Dir'Length + 7) := "/LLR.md";
      end;

      -- Parse HLR.md and LLR.md
      Adacovex.Parsers.DO178C.Parse_HLR_MD
        (HLR_Path (1 .. HLR_Len), HLR_List, HLR_Count, HLR_Success);
      Adacovex.Parsers.DO178C.Parse_LLR_MD
        (LLR_Path (1 .. LLR_Len), LLR_List, LLR_Count, LLR_Success);

      Assessment.HLR_Total := HLR_Count;
      Assessment.LLR_Total := LLR_Count;

      -- Check HLR traceability: every HLR in docs must be in source
      for H in 1 .. HLR_Count loop
         declare
            HLR_Id : String renames HLR_List (H).Id (1 .. HLR_List (H).Id_Len);
         begin
            if Adacovex.Parsers.DO178C.Find_HLR_In_Source
                 (HLR_Id, Packages, Pkg_Count) then
               Assessment.HLR_Found := Assessment.HLR_Found + 1;
            end if;
         end;
      end loop;

      -- Check for orphan HLR tags in source (not found in HLR.md)
      declare
         Orphan_Found : Boolean := False;
      begin
       for P in 1 .. Pkg_Count loop
          for T in 1 .. Packages (P).Total_HLR_Tags loop
             declare
                Tag_Len : constant Natural := Packages (P).HLR_Tags (T).Len;
                Found   : Boolean := False;
             begin
                 for H in 1 .. HLR_Count loop
                    declare
                       H_Str : String renames HLR_List (H).Id (1 .. HLR_List (H).Id_Len);
                       Match : Boolean := True;
                    begin
                       if Tag_Len = H_Str'Length then
                          for I in 1 .. Tag_Len loop
                             if Packages (P).HLR_Tags (T).Tag (I) /= H_Str (H_Str'First + I - 1) then
                                Match := False;
                                exit;
                             end if;
                          end loop;
                          if Match then
                             Found := True;
                             exit;
                          end if;
                       end if;
                    end;
                 end loop;
                if not Found then
                   Orphan_Found := True;
                end if;
             end;
          end loop;
         end loop;
         Assessment.Orphan_Tags := Orphan_Found;
      end;

      -- Check SPARK level: need Silver or Gold for DAL-C
      Assessment.Min_SPARK_Level_Met :=
        Proof_Summary.Level >= Types.Silver;

      -- Check tests passing
      Assessment.Tests_Passing := Test_Summary.Total_Failed = 0;

      -- Collect failures
      if Assessment.HLR_Found < Assessment.HLR_Total then
         Failed_Idx := Failed_Idx + 1;
         declare
            Msg : constant String :=
              "Missing HLRs: " & Natural'Image (Assessment.HLR_Total - Assessment.HLR_Found);
         begin
            for I in 1 .. Msg'Length loop
               Assessment.Failed_Reasons (Failed_Idx) (I) := Msg (I);
            end loop;
         end;
      end if;

      if Assessment.Orphan_Tags then
         Failed_Idx := Failed_Idx + 1;
         declare
            Msg : constant String := "Orphan HLR tags found in source";
         begin
            for I in 1 .. Msg'Length loop
               Assessment.Failed_Reasons (Failed_Idx) (I) := Msg (I);
            end loop;
         end;
      end if;

      if not Assessment.Min_SPARK_Level_Met then
         Failed_Idx := Failed_Idx + 1;
         declare
            Msg : constant String :=
              "SPARK level below Silver: " & Types.To_String (Proof_Summary.Level);
         begin
            for I in 1 .. Msg'Length loop
               Assessment.Failed_Reasons (Failed_Idx) (I) := Msg (I);
            end loop;
         end;
      end if;

      if not Assessment.Tests_Passing then
         Failed_Idx := Failed_Idx + 1;
         declare
            Msg : constant String :=
              "Test failures: " & Natural'Image (Test_Summary.Total_Failed);
         begin
            for I in 1 .. Msg'Length loop
               Assessment.Failed_Reasons (Failed_Idx) (I) := Msg (I);
            end loop;
         end;
      end if;

      Assessment.Failed_Count := Failed_Idx;

      if Failed_Idx = 0 then
         Assessment.Status := Types.Achieved;
      else
         Assessment.Status := Types.Unmet;
      end if;
   end Assess_DAL_C;

   function Is_DAL_Achieved
     (Assessment : Types.DAL_Assessment) return Boolean is
   begin
      return Assessment.Status = Types.Achieved;
   end Is_DAL_Achieved;

end Adacovex.Compliance.DAL;
