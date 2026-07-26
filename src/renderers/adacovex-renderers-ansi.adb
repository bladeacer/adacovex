with Ada.Text_IO;
--  SPDX-License-Identifier: Apache-2.0

package body Adacovex.Renderers.ANSI is

   use type Types.Test_Status;
   use type Types.DAL_Status;

   ESC : constant String := ASCII.ESC & "[";

   procedure Put_Color (Color : String; Bold : Boolean := False) is
   begin
      if Bold then
         Ada.Text_IO.Put (ESC & "1;" & Color & "m");
      else
         Ada.Text_IO.Put (ESC & Color & "m");
      end if;
   end Put_Color;

   procedure Reset_Color is
   begin
      Ada.Text_IO.Put (ESC & "0m");
   end Reset_Color;

   procedure Render_Summary
     (Doc_Metrics  : Types.Docstring_Metrics;
      Proof        : Types.Proof_Summary;
      Tests        : Types.Test_Summary;
      DAL_Assess   : Types.DAL_Assessment;
      Packages     : Types.Package_Array;
      Pkg_Count    : Natural)
   is
   begin
      Ada.Text_IO.Put_Line ("");
      Put_Color ("34", True);
      Ada.Text_IO.Put_Line ("=== adacovex - Coverage & Verification Report ===");
      Reset_Color;
      Ada.Text_IO.Put_Line ("");

      -- Source Overview
      Put_Color ("33", True);
      Ada.Text_IO.Put_Line ("--- Source Overview ---");
      Reset_Color;
      Ada.Text_IO.Put_Line ("Packages scanned: " & Natural'Image (Pkg_Count));
      Ada.Text_IO.Put_Line ("Total subprograms: " & Natural'Image (Doc_Metrics.Total_Subprograms));
      Ada.Text_IO.Put_Line ("");

      -- Docstring Coverage
      Put_Color ("33", True);
      Ada.Text_IO.Put_Line ("--- Docstring Coverage ---");
      Reset_Color;
      Ada.Text_IO.Put_Line ("Documented: " & Natural'Image (Doc_Metrics.Documented_Subprogs) &
                            " / " & Natural'Image (Doc_Metrics.Total_Subprograms));
      if Doc_Metrics.Coverage_Pct >= 80 then
         Put_Color ("32");
      elsif Doc_Metrics.Coverage_Pct >= 50 then
         Put_Color ("33");
      else
         Put_Color ("31");
      end if;
      Ada.Text_IO.Put_Line ("Coverage: " & Natural'Image (Doc_Metrics.Coverage_Pct) & "%");
      Reset_Color;
      Ada.Text_IO.Put_Line ("");

      -- SPARK Proof
      Put_Color ("33", True);
      Ada.Text_IO.Put_Line ("--- SPARK Proof Analysis ---");
      Reset_Color;
      Ada.Text_IO.Put_Line ("Level: " & Types.To_String (Proof.Level));

      case Proof.Level is
         when Types.Platinum =>
            Put_Color ("37");
         when Types.Gold =>
            Put_Color ("33");
         when Types.Silver =>
            Put_Color ("37");
         when Types.Bronze =>
            Put_Color ("31");
         when Types.Stone =>
            Put_Color ("31");
      end case;
      Ada.Text_IO.Put_Line ("  SPARK Level: " & Types.To_String (Proof.Level));
      Reset_Color;

      Ada.Text_IO.Put_Line ("Total VCs: " & Natural'Image (Proof.Total_VCs));
      Ada.Text_IO.Put_Line ("Proved: " & Natural'Image (Proof.Proved_VCs));
      Ada.Text_IO.Put_Line ("Flow checks: " & Natural'Image (Proof.Flow_Proved) &
                            " / " & Natural'Image (Proof.Flow_Checks));
      Ada.Text_IO.Put_Line ("Runtime checks: " & Natural'Image (Proof.Runtime_Proved) &
                            " / " & Natural'Image (Proof.Runtime_Checks));
      Ada.Text_IO.Put_Line ("Assertions: " & Natural'Image (Proof.Assert_Proved) &
                            " / " & Natural'Image (Proof.Assertions));
      Ada.Text_IO.Put_Line ("Functional contracts: " & Natural'Image (Proof.Functional_Proved) &
                            " / " & Natural'Image (Proof.Functional_Ct));
      Ada.Text_IO.Put_Line ("Unproved: " & Natural'Image (Proof.Unproved));
      Ada.Text_IO.Put_Line ("");

      -- Test Results
      Put_Color ("33", True);
      Ada.Text_IO.Put_Line ("--- Test Results ---");
      Reset_Color;
      for C in 1 .. Tests.Category_Count loop
         Ada.Text_IO.Put ("  " & Tests.Categories (C).Category (1 .. Tests.Categories (C).Cat_Len));
         Ada.Text_IO.Put (" | " & Natural'Image (Tests.Categories (C).Test_Count));
         if Tests.Categories (C).Status = Types.Pass then
            Put_Color ("32");
         else
            Put_Color ("31");
         end if;
         Ada.Text_IO.Put_Line (" " & Types.To_String (Tests.Categories (C).Status));
         Reset_Color;
      end loop;
      Ada.Text_IO.Put_Line ("");

      if Tests.Total_Failed = 0 then
         Put_Color ("32", True);
      else
         Put_Color ("31", True);
      end if;
      Ada.Text_IO.Put_Line ("Passed: " & Natural'Image (Tests.Total_Passed) &
                            "  Failed: " & Natural'Image (Tests.Total_Failed));
      Reset_Color;
      Ada.Text_IO.Put_Line ("");

      -- DO-178C DAL Assessment
      Put_Color ("33", True);
      Ada.Text_IO.Put_Line ("--- DO-178C DAL Assessment ---");
      Reset_Color;
      Ada.Text_IO.Put_Line ("Target DAL: " & Types.To_String (DAL_Assess.Target_DAL));
      if DAL_Assess.Status = Types.Achieved then
         Put_Color ("32", True);
      else
         Put_Color ("31", True);
      end if;
      Ada.Text_IO.Put_Line ("Status: " & Types.To_String (DAL_Assess.Status));
      Reset_Color;

      Ada.Text_IO.Put_Line ("HLR traced: " & Natural'Image (DAL_Assess.HLR_Found) &
                            " / " & Natural'Image (DAL_Assess.HLR_Total));
      Ada.Text_IO.Put_Line ("Orphan tags: " & (if DAL_Assess.Orphan_Tags then "Yes" else "No"));
      Ada.Text_IO.Put_Line ("Tests passing: " & (if DAL_Assess.Tests_Passing then "Yes" else "No"));
      Ada.Text_IO.Put_Line ("Min SPARK level met: " &
                            (if DAL_Assess.Min_SPARK_Level_Met then "Yes" else "No"));

      if DAL_Assess.Failed_Count > 0 then
         Ada.Text_IO.Put_Line ("Failures:");
         for F in 1 .. DAL_Assess.Failed_Count loop
            Ada.Text_IO.Put_Line ("  - " & DAL_Assess.Failed_Reasons (F) (1 .. Types.Max_Desc_Str));
         end loop;
      end if;
      Ada.Text_IO.Put_Line ("");

      -- HLR Traceability per package
      Put_Color ("33", True);
      Ada.Text_IO.Put_Line ("--- HLR Traceability ---");
      Reset_Color;
      for P in 1 .. Pkg_Count loop
         if Packages (P).Total_HLR_Tags > 0 then
            Ada.Text_IO.Put (Packages (P).Name (1 .. Packages (P).Name_Len) & ": ");
            for T in 1 .. Packages (P).Total_HLR_Tags loop
               if T > 1 then
                  Ada.Text_IO.Put (", ");
               end if;
               Ada.Text_IO.Put (Packages (P).HLR_Tags (T).Tag (1 .. Packages (P).HLR_Tags (T).Len));
            end loop;
            Ada.Text_IO.New_Line;
         end if;
      end loop;
      Ada.Text_IO.Put_Line ("");
   end Render_Summary;

end Adacovex.Renderers.ANSI;
