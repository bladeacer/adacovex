with Ada.Strings.Fixed;
with Adacovex.Types;
use Adacovex.Types, Adacovex.Types.Implementation;
with Adacovex.Renderers.SVG; use Adacovex.Renderers.SVG;

package body Adacovex_Renderer_SVG_Tests is

   function Contains (S : String; Sub : String) return Boolean is
   begin
      return Ada.Strings.Fixed.Index (S, Sub) > 0;
   end Contains;

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
   begin
      --  SPARK badge: Platinum
      declare
         S : constant String := Render_SPARK_Badge (Platinum);
      begin
         R.Check (Contains (S, "<svg"), "SPARK Platinum: contains <svg");
         R.Check (Contains (S, "SPARK"), "SPARK Platinum: label");
         R.Check (Contains (S, "Platinum"), "SPARK Platinum: value");
      end;

      --  SPARK badge: Stone
      declare
         S : constant String := Render_SPARK_Badge (Stone);
      begin
         R.Check (Contains (S, "<svg"), "SPARK Stone: contains <svg");
         R.Check (Contains (S, "SPARK"), "SPARK Stone: label");
         R.Check (Contains (S, "Stone"), "SPARK Stone: value");
      end;

      --  Tests badge: 0/0
      declare
         Summary : Test_Summary;
      begin
         Summary.Total_Passed := 0;
         Summary.Total_Failed := 0;
         declare
            S : constant String := Render_Tests_Badge (Summary);
         begin
            R.Check (Contains (S, "<svg"), "Tests 0/0: contains <svg");
            R.Check (Contains (S, "Tests"), "Tests 0/0: label");
            R.Check (Contains (S, "0 Passed"), "Tests 0/0: 0 Passed");
         end;
      end;

      --  Tests badge: 10/0
      declare
         Summary : Test_Summary;
      begin
         Summary.Total_Passed := 10;
         Summary.Total_Failed := 0;
         declare
            S : constant String := Render_Tests_Badge (Summary);
         begin
            R.Check (Contains (S, "<svg"), "Tests 10/0: contains <svg");
            R.Check (Contains (S, "Tests"), "Tests 10/0: label");
            R.Check (Contains (S, "10 Passed"), "Tests 10/0: 10 Passed");
         end;
      end;

      --  Tests badge: 5/2
      declare
         Summary : Test_Summary;
      begin
         Summary.Total_Passed := 5;
         Summary.Total_Failed := 2;
         declare
            S : constant String := Render_Tests_Badge (Summary);
         begin
            R.Check (Contains (S, "<svg"), "Tests 5/2: contains <svg");
            R.Check (Contains (S, "Tests"), "Tests 5/2: label");
            R.Check (Contains (S, "5 Passed"), "Tests 5/2: 5 Passed");
         end;
      end;

      --  DO-178C badge: Achieved
      declare
         Assess : DAL_Assessment;
      begin
         Assess.Status := Achieved;
         Assess.Target_DAL := DAL_C;
         declare
            S : constant String := Render_DO178C_Badge (Assess);
         begin
            R.Check (Contains (S, "<svg"), "DO-178C Achieved: contains <svg");
            R.Check (Contains (S, "DO-178C"), "DO-178C Achieved: label");
            R.Check
              (Contains (S, "DAL-C PASS"), "DO-178C Achieved: DAL-C PASS");
         end;
      end;

      --  DO-178C badge: Unmet
      declare
         Assess : DAL_Assessment;
      begin
         Assess.Status := Unmet;
         Assess.Target_DAL := DAL_C;
         declare
            S : constant String := Render_DO178C_Badge (Assess);
         begin
            R.Check (Contains (S, "<svg"), "DO-178C Unmet: contains <svg");
            R.Check (Contains (S, "DO-178C"), "DO-178C Unmet: label");
            R.Check (Contains (S, "DAL-C FAIL"), "DO-178C Unmet: DAL-C FAIL");
         end;
      end;

      --  Compliance badge: ISO 26262 (ASIL B) via the standard-parameterized
      --  renderer.
      declare
         Assess : DAL_Assessment;
      begin
         Assess.Status := Achieved;
         Assess.Target_DAL := DAL_C;
         declare
            S : constant String := Render_Compliance_Badge (Assess, ISO_26262);
         begin
            R.Check
              (Contains (S, "<svg"), "ISO 26262 Achieved: contains <svg");
            R.Check (Contains (S, "ISO 26262"), "ISO 26262 Achieved: label");
            R.Check
              (Contains (S, "ASIL B PASS"), "ISO 26262 Achieved: ASIL B PASS");
         end;
      end;

      --  Compliance badge: IEC 62304 (Class A).
      declare
         Assess : DAL_Assessment;
      begin
         Assess.Status := Achieved;
         Assess.Target_DAL := DAL_C;
         declare
            S : constant String := Render_Compliance_Badge (Assess, IEC_62304);
         begin
            R.Check
              (Contains (S, "<svg"), "IEC 62304 Achieved: contains <svg");
            R.Check (Contains (S, "IEC 62304"), "IEC 62304 Achieved: label");
            R.Check
              (Contains (S, "Class A PASS"),
               "IEC 62304 Achieved: Class A PASS");
         end;
      end;

      --  Docstring badge: 100%
      declare
         Metrics : Docstring_Metrics;
      begin
         Metrics.Coverage_Pct := 100;
         declare
            S : constant String := Render_Docstring_Badge (Metrics);
         begin
            R.Check (Contains (S, "<svg"), "docs 100%: contains <svg");
            R.Check (Contains (S, "docs"), "docs 100%: label");
            R.Check (Contains (S, "100%"), "docs 100%: shows 100%");
         end;
      end;

      --  Docstring badge: 50%
      declare
         Metrics : Docstring_Metrics;
      begin
         Metrics.Coverage_Pct := 50;
         declare
            S : constant String := Render_Docstring_Badge (Metrics);
         begin
            R.Check (Contains (S, "<svg"), "docs 50%: contains <svg");
            R.Check (Contains (S, "docs"), "docs 50%: label");
            R.Check (Contains (S, "50%"), "docs 50%: shows 50%");
         end;
      end;

      --  Docstring badge: 0%
      declare
         Metrics : Docstring_Metrics;
      begin
         Metrics.Coverage_Pct := 0;
         declare
            S : constant String := Render_Docstring_Badge (Metrics);
         begin
            R.Check (Contains (S, "<svg"), "docs 0%: contains <svg");
            R.Check (Contains (S, "docs"), "docs 0%: label");
            R.Check (Contains (S, "0%"), "docs 0%: shows 0%");
         end;
      end;
   end Run;

end Adacovex_Renderer_SVG_Tests;
