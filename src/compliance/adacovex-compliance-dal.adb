package body Adacovex.Compliance.DAL is

   use type Types.SPARK_Level;
   use type Types.DAL_Status;
   use type Types.DAL_Level;

   function Min_SPARK_For (Level : Types.DAL_Level) return Types.SPARK_Level
   with SPARK_Mode => On
   is
   begin
      case Level is
         when Types.DAL_A =>
            return Types.Gold;

         when Types.DAL_B =>
            return Types.Silver;

         when Types.DAL_C =>
            return Types.Bronze;

         when Types.DAL_D =>
            return Types.Stone;

         when Types.DAL_E =>
            return Types.Stone;
      end case;
   end Min_SPARK_For;

   function Need_Tests (Level : Types.DAL_Level) return Boolean
   with SPARK_Mode => On
   is
   begin
      return Level /= Types.DAL_E;
   end Need_Tests;

   procedure Assess_DAL
     (Level         : Types.DAL_Level;
      Target_Dir    : String;
      Packages      : Types.Implementation.Package_Vectors.Vector;
      Proof_Summary : Types.Proof_Summary;
      Test_Summary  : Types.Implementation.Test_Summary;
      Assessment    : out Types.Implementation.DAL_Assessment;
      Use_Cache     : Boolean := False)
   is
      HLR_Path    : String (1 .. Types.Max_Path);
      HLR_Len     : Natural;
      LLR_Path    : String (1 .. Types.Max_Path);
      LLR_Len     : Natural;
      HLR_List    : Adacovex.Parsers.DO178C.HLR_Vectors.Vector;
      LLR_List    : Adacovex.Parsers.DO178C.LLR_Vectors.Vector;
      HLR_Success : Boolean;
      LLR_Success : Boolean;
      Min_Lvl     : constant Types.SPARK_Level := Min_SPARK_For (Level);
      Tests_Req   : constant Boolean := Need_Tests (Level);
   begin
      Assessment :=
        (Target_DAL             => Level,
         Standard               => Types.DO_178C,
         Status                 => Types.Unmet,
         HLR_Total              => 0,
         HLR_Found              => 0,
         LLR_Total              => 0,
         LLR_Found              => 0,
         All_Subprograms_Traced => False,
         Orphan_Tags            => False,
         Tests_Passing          => False,
         Min_SPARK_Level_Met    => False,
         Failed_Reasons         =>
           Types.Implementation.DAL_Failure_Vectors.Empty_Vector);

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

      -- Parse HLR.md and LLR.md (cached when Use_Cache, so unchanged
      -- requirements documents are served from the on-disk result cache).
      Adacovex.Parsers.DO178C.Parse_HLR_MD
        (HLR_Path (1 .. HLR_Len), HLR_List, HLR_Success, Use_Cache);
      Adacovex.Parsers.DO178C.Parse_LLR_MD
        (LLR_Path (1 .. LLR_Len), LLR_List, LLR_Success, Use_Cache);

      Assessment.HLR_Total := Natural (HLR_List.Length);
      Assessment.LLR_Total := Natural (LLR_List.Length);

      -- Check HLR traceability: every HLR in docs must be in source
      for H in 1 .. Integer (HLR_List.Length) loop
         declare
            HLR_Id : constant String :=
              HLR_List (H).Id (1 .. HLR_List (H).Id_Len);
         begin
            if Adacovex.Parsers.DO178C.Find_HLR_In_Source (HLR_Id, Packages)
            then
               Assessment.HLR_Found := Assessment.HLR_Found + 1;
            end if;
         end;
      end loop;

      -- Check for orphan HLR tags in source (not found in HLR.md)
      declare
         Orphan_Found : Boolean := False;
      begin
         for P in 1 .. Integer (Packages.Length) loop
            for T in 1 .. Integer (Packages (P).HLR_Tags.Length) loop
               declare
                  Tag_Len : constant Natural := Packages (P).HLR_Tags (T).Len;
                  Found   : Boolean := False;
               begin
                  for H in 1 .. Integer (HLR_List.Length) loop
                     declare
                        H_Str : constant String :=
                          HLR_List (H).Id (1 .. HLR_List (H).Id_Len);
                        Match : Boolean := True;
                     begin
                        if Tag_Len = H_Str'Length then
                           for I in 1 .. Tag_Len loop
                              if Packages (P).HLR_Tags (T).Tag (I)
                                /= H_Str (H_Str'First + I - 1)
                              then
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

      -- Check SPARK level against per-level minimum
      Assessment.Min_SPARK_Level_Met := Proof_Summary.Level >= Min_Lvl;

      -- Check tests passing (not required for DAL-E)
      if Tests_Req then
         Assessment.Tests_Passing := Test_Summary.Total_Failed = 0;
      else
         Assessment.Tests_Passing := True;
      end if;
      -- Collect failures
      declare
         procedure Push (Msg : String) is
            Field : Types.Desc_Field := (others => ' ');
         begin
            if Msg'Length <= Types.Max_Desc_Str then
               Field (1 .. Msg'Length) := Msg;
            end if;
            Assessment.Failed_Reasons.Append (Field);
         end Push;
      begin
         if Assessment.HLR_Found < Assessment.HLR_Total then
            Push
              ("Missing HLRs: "
               & Natural'Image (Assessment.HLR_Total - Assessment.HLR_Found));
         end if;

         if Assessment.Orphan_Tags then
            Push ("Orphan HLR tags found in source");
         end if;

         if not Assessment.Min_SPARK_Level_Met then
            Push
              ("SPARK level below "
               & Types.To_String (Min_Lvl)
               & ": "
               & Types.To_String (Proof_Summary.Level));
         end if;

         if Tests_Req and then not Assessment.Tests_Passing then
            Push ("Test failures detected");
         end if;
      end;

      if Assessment.Failed_Reasons.Is_Empty then
         Assessment.Status := Types.Achieved;
      else
         Assessment.Status := Types.Unmet;
      end if;
   end Assess_DAL;

   function Is_DAL_Achieved
     (Assessment : Types.Implementation.DAL_Assessment) return Boolean is
   begin
      return Assessment.Status = Types.Achieved;
   end Is_DAL_Achieved;

   procedure Assess_Standard
     (Standard      : Types.Compliance_Standard;
      Level         : Types.DAL_Level;
      Target_Dir    : String;
      Packages      : Types.Implementation.Package_Vectors.Vector;
      Proof_Summary : Types.Proof_Summary;
      Test_Summary  : Types.Implementation.Test_Summary;
      Assessment    : out Types.Implementation.DAL_Assessment;
      Use_Cache     : Boolean := False) is
   begin
      Assess_DAL
        (Level,
         Target_Dir,
         Packages,
         Proof_Summary,
         Test_Summary,
         Assessment,
         Use_Cache);
      Assessment.Standard := Standard;
   end Assess_Standard;

end Adacovex.Compliance.DAL;
