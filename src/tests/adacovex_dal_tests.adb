with Adacovex.Types;
use Adacovex.Types, Adacovex.Types.Implementation;
with Adacovex.Compliance.DAL;
with Adacovex.Parsers.DO178C;
with Ada.Text_IO; use Ada.Text_IO;
with Ada.Directories;

package body Adacovex_DAL_Tests is

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
   begin
      declare
         Assessment : DAL_Assessment;
      begin
         Assessment :=
           (Target_DAL             => DAL_C,
            Standard               => DO_178C,
            Status                 => Achieved,
            HLR_Total              => 10,
            HLR_Found              => 10,
            LLR_Total              => 5,
            LLR_Found              => 5,
            All_Subprograms_Traced => True,
            Orphan_Tags            => False,
            Tests_Passing          => True,
            Min_SPARK_Level_Met    => True,
            Failed_Reasons         => DAL_Failure_Vectors.Empty_Vector);
         R.Check
           (Adacovex.Compliance.DAL.Is_DAL_Achieved (Assessment),
            "Is_DAL_Achieved True when Status = Achieved");
      end;

      declare
         Assessment : DAL_Assessment;
      begin
         Assessment :=
           (Target_DAL             => DAL_C,
            Standard               => DO_178C,
            Status                 => Unmet,
            HLR_Total              => 10,
            HLR_Found              => 5,
            LLR_Total              => 5,
            LLR_Found              => 3,
            All_Subprograms_Traced => False,
            Orphan_Tags            => True,
            Tests_Passing          => False,
            Min_SPARK_Level_Met    => False,
            Failed_Reasons         => DAL_Failure_Vectors.Empty_Vector);
         R.Check
           (not Adacovex.Compliance.DAL.Is_DAL_Achieved (Assessment),
            "Is_DAL_Achieved False when Status = Unmet");
      end;

      --  Test 3: an HLR markdown entry with an ID and description longer
      --  than the fixed buffers is clamped instead of raising
      --  Constraint_Error.
      declare
         HLR_File : constant String := "/tmp/adacovex_hlr_test.md";
         HLRs     : Adacovex.Parsers.DO178C.HLR_Vectors.Vector;
         OK       : Boolean;
         F        : File_Type;
         Big_Id   : String (1 .. 80);
         Big_Desc : String (1 .. 200);
      begin
         for I in Big_Id'Range loop
            Big_Id (I) := 'A';
         end loop;
         for I in Big_Desc'Range loop
            Big_Desc (I) := 'x';
         end loop;
         begin
            Create (F, Out_File, HLR_File);
            Put_Line (F, "# High-Level Requirements");
            Put_Line (F, "- HLR-" & Big_Id & ": " & Big_Desc);
            Put_Line (F, "- HLR-CLAMP: Normal entry.");
            Close (F);
         end;
         Adacovex.Parsers.DO178C.Parse_HLR_MD (HLR_File, HLRs, OK);
         R.Check (OK, "Parse_HLR_MD succeeds on oversized entries");
         R.Check
           (Natural (HLRs.Length) = 2, "Parse_HLR_MD parsed both entries");
         R.Check
           (HLRs (1).Id_Len = Adacovex.Types.Max_Id_Str,
            "Oversized HLR ID clamped to Max_Id_Str");
         R.Check
           (HLRs (1).D_Len = Adacovex.Types.Max_Desc_Str,
            "Oversized HLR description clamped to Max_Desc_Str");
         R.Check
           (HLRs (2).Id_Len = 5 and then HLRs (2).Id (1 .. 5) = "CLAMP",
            "Normal HLR entry unchanged");
         begin
            Ada.Directories.Delete_File (HLR_File);
         exception
            when others =>
               null;
         end;
      end;

      --  Test 4 (1.10.0): Assess_Standard records the compliance standard and
      --  reuses the shared evidence checks, so the level label is
      --  standard-aware (ISO 26262 DAL C -> ASIL B).
      declare
         Tmp        : constant String := "/tmp/adacovex_std_test";
         Assessment : DAL_Assessment;
         Pkgs       : Package_Vectors.Vector;
         Proof      : Proof_Summary;
         Tests      : Test_Summary;
         F          : File_Type;
      begin
         begin
            if Ada.Directories.Exists (Tmp) then
               Ada.Directories.Delete_Tree (Tmp);
            end if;
            Ada.Directories.Create_Path (Tmp & "/docs/compliance");
            Create (F, Out_File, Tmp & "/docs/compliance/HLR.md");
            Close (F);
            Create (F, Out_File, Tmp & "/docs/compliance/LLR.md");
            Close (F);
         end;
         Proof.Level := Gold;
         Proof.Proved_VCs := 1;
         Proof.Total_VCs := 1;
         Adacovex.Compliance.DAL.Assess_Standard
           (ISO_26262, DAL_C, Tmp, Pkgs, Proof, Tests, Assessment);
         R.Check
           (Assessment.Standard = ISO_26262,
            "Assess_Standard records ISO 26262 standard");
         R.Check
           (Assessment.Target_DAL = DAL_C,
            "Assess_Standard reuses the DAL rigor tier");
         R.Check
           (Adacovex.Types.Standard_Level_Name
              (Assessment.Standard, Assessment.Target_DAL)
            = "ASIL B",
            "Assess_Standard level label is ASIL B");
         R.Check
           (Assessment.Status = Achieved,
            "Assess_Standard achieves on empty target (Gold, no HLRs/orphans)");
         begin
            if Ada.Directories.Exists (Tmp) then
               Ada.Directories.Delete_Tree (Tmp);
            end if;
         exception
            when others =>
               null;
         end;
      end;
   end Run;

end Adacovex_DAL_Tests;
