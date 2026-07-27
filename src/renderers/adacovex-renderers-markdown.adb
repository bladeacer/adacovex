with Ada.Text_IO;

package body Adacovex.Renderers.Markdown is

   procedure Generate_Verification_Report
     (Path        : String;
      Doc_Metrics : Types.Docstring_Metrics;
      Proof       : Types.Proof_Summary;
      Tests       : Types.Test_Summary;
      DAL_Assess  : Types.DAL_Assessment;
      Packages    : Types.Package_Array;
      Pkg_Count   : Natural)
   is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line (F, "# adacovex Verification Report");
      Ada.Text_IO.Put_Line (F, "");
      Ada.Text_IO.Put_Line (F, "## Source Overview");
      Ada.Text_IO.Put_Line (F, "");
      Ada.Text_IO.Put_Line (F, "| Metric | Value |");
      Ada.Text_IO.Put_Line (F, "|--------|-------|");
      Ada.Text_IO.Put_Line
        (F, "| Packages Scanned | " & Natural'Image (Pkg_Count) & " |");
      Ada.Text_IO.Put_Line
        (F,
         "| Total Subprograms | "
         & Natural'Image (Doc_Metrics.Total_Subprograms)
         & " |");
      Ada.Text_IO.Put_Line
        (F,
         "| Documented Subprograms | "
         & Natural'Image (Doc_Metrics.Documented_Subprogs)
         & " |");
      Ada.Text_IO.Put_Line
        (F,
         "| Docstring Coverage | "
         & Natural'Image (Doc_Metrics.Coverage_Pct)
         & "% |");
      Ada.Text_IO.Put_Line (F, "");
      Ada.Text_IO.Put_Line (F, "## SPARK Proof Analysis");
      Ada.Text_IO.Put_Line (F, "");
      Ada.Text_IO.Put_Line (F, "| Check Type | Count | Proved |");
      Ada.Text_IO.Put_Line (F, "|------------|-------|--------|");
      Ada.Text_IO.Put_Line
        (F, "| SPARK Level | " & Types.To_String (Proof.Level) & " | - |");
      Ada.Text_IO.Put_Line
        (F,
         "| Flow Dependencies | "
         & Natural'Image (Proof.Flow_Checks)
         & " | "
         & Natural'Image (Proof.Flow_Proved)
         & " |");
      Ada.Text_IO.Put_Line
        (F,
         "| Runtime Checks | "
         & Natural'Image (Proof.Runtime_Checks)
         & " | "
         & Natural'Image (Proof.Runtime_Proved)
         & " |");
      Ada.Text_IO.Put_Line
        (F,
         "| Assertions | "
         & Natural'Image (Proof.Assertions)
         & " | "
         & Natural'Image (Proof.Assert_Proved)
         & " |");
      Ada.Text_IO.Put_Line
        (F,
         "| Functional Contracts | "
         & Natural'Image (Proof.Functional_Ct)
         & " | "
         & Natural'Image (Proof.Functional_Proved)
         & " |");
      Ada.Text_IO.Put_Line
        (F,
         "| Termination | "
         & Natural'Image (Proof.Termination_Ct)
         & " | "
         & Natural'Image (Proof.Termination_Proved)
         & " |");
      Ada.Text_IO.Put_Line
        (F,
         "| **Total** | "
         & Natural'Image (Proof.Total_VCs)
         & " | "
         & Natural'Image (Proof.Proved_VCs)
         & " |");
      Ada.Text_IO.Put_Line (F, "");
      Ada.Text_IO.Put_Line (F, "## Test Results");
      Ada.Text_IO.Put_Line (F, "");
      Ada.Text_IO.Put_Line (F, "| Category | Tests | Status |");
      Ada.Text_IO.Put_Line (F, "|----------|-------|--------|");
      for C in 1 .. Tests.Category_Count loop
         Ada.Text_IO.Put_Line
           (F,
            "| "
            & Tests.Categories (C).Category (1 .. Tests.Categories (C).Cat_Len)
            & " | "
            & Natural'Image (Tests.Categories (C).Test_Count)
            & " | "
            & Types.To_String (Tests.Categories (C).Status)
            & " |");
      end loop;
      Ada.Text_IO.Put_Line
        (F,
         "| **Total** | **"
         & Natural'Image (Tests.Total_Passed + Tests.Total_Failed)
         & "** | **Passed: "
         & Natural'Image (Tests.Total_Passed)
         & ", Failed: "
         & Natural'Image (Tests.Total_Failed)
         & "** |");
      Ada.Text_IO.Put_Line (F, "");
      Ada.Text_IO.Put_Line (F, "## DO-178C Compliance");
      Ada.Text_IO.Put_Line (F, "");
      Ada.Text_IO.Put_Line (F, "| Criterion | Status |");
      Ada.Text_IO.Put_Line (F, "|-----------|--------|");
      Ada.Text_IO.Put_Line
        (F,
         "| Target DAL | " & Types.To_String (DAL_Assess.Target_DAL) & " |");
      Ada.Text_IO.Put_Line
        (F,
         "| Overall Status | " & Types.To_String (DAL_Assess.Status) & " |");
      Ada.Text_IO.Put_Line
        (F,
         "| HLR Traced | "
         & Natural'Image (DAL_Assess.HLR_Found)
         & " / "
         & Natural'Image (DAL_Assess.HLR_Total)
         & " |");
      Ada.Text_IO.Put_Line
        (F,
         "| Orphan Tags | "
         & (if DAL_Assess.Orphan_Tags then "Yes" else "No")
         & " |");
      Ada.Text_IO.Put_Line
        (F,
         "| Tests Passing | "
         & (if DAL_Assess.Tests_Passing then "Yes" else "No")
         & " |");
      Ada.Text_IO.Put_Line
        (F,
         "| Min SPARK Level | "
         & (if DAL_Assess.Min_SPARK_Level_Met then "Yes" else "No")
         & " |");

      if DAL_Assess.Failed_Count > 0 then
         Ada.Text_IO.Put_Line (F, "");
         Ada.Text_IO.Put_Line (F, "### Failure Reasons");
         for R in 1 .. DAL_Assess.Failed_Count loop
            Ada.Text_IO.Put_Line
              (F,
               "- " & DAL_Assess.Failed_Reasons (R) (1 .. Types.Max_Desc_Str));
         end loop;
      end if;

      Ada.Text_IO.Close (F);
   end Generate_Verification_Report;

   procedure Generate_Trace_Matrix
     (Path : String; Packages : Types.Package_Array; Pkg_Count : Natural)
   is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line (F, "# Traceability Matrix");
      Ada.Text_IO.Put_Line (F, "");
      Ada.Text_IO.Put_Line (F, "| Package | HLR Tags |");
      Ada.Text_IO.Put_Line (F, "|---------|-----------|");
      for P in 1 .. Pkg_Count loop
         if Packages (P).Total_HLR_Tags > 0 then
            Ada.Text_IO.Put
              (F,
               "| " & Packages (P).Name (1 .. Packages (P).Name_Len) & " | ");
            for T in 1 .. Packages (P).Total_HLR_Tags loop
               if T > 1 then
                  Ada.Text_IO.Put (F, ", ");
               end if;
               Ada.Text_IO.Put
                 (F,
                  Packages (P).HLR_Tags (T).Tag
                    (1 .. Packages (P).HLR_Tags (T).Len));
            end loop;
            Ada.Text_IO.Put_Line (F, " |");
         end if;
      end loop;
      Ada.Text_IO.Close (F);
   end Generate_Trace_Matrix;

end Adacovex.Renderers.Markdown;
