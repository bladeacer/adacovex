with Ada.Strings.Fixed;
with Adacovex.Types;
use Adacovex.Types, Adacovex.Types.Implementation;
with Adacovex.Renderers.SVG; use Adacovex.Renderers.SVG;

package body Adacovex_Renderer_SVG_Tests is

   function Contains (S : String; Sub : String) return Boolean is
   begin
      return Ada.Strings.Fixed.Index (S, Sub) > 0;
   end Contains;

   --  Numeric value of the Nth occurrence of an `Attr="..."` in the SVG
   --  markup (1-based).  Badge_SVG emits five `width=` attributes (svg,
   --  clipPath rect, label rect, value rect, shade rect) and three `x=`
   --  attributes (value rect, label text, value text), so Nth_Attr can
   --  pick out each dimension from the generated markup.  Returns 0 when
   --  the occurrence is missing -- a failure, surfaced by the caller's
   --  R.Check.
   function Nth_Attr (S : String; Attr : String; N : Positive) return Natural
   is
      --  A leading space keeps `x="` from matching inside `rx="3"` (the
      --  clip-path corner radius); every real attribute in the markup is
      --  preceded by a space.
      Needle : constant String := " " & Attr & "=" & '"';  --  e.g. width="
      Pos    : Natural := S'First;
      Found  : Natural := 0;
   begin
      loop
         exit when Pos > S'Last;
         Pos := Ada.Strings.Fixed.Index (S, Needle, Pos);
         exit when Pos = 0;
         Found := Found + 1;
         if Found = N then
            declare
               P : Natural := Pos + Needle'Length;
               V : Natural := 0;
            begin
               while P <= S'Last and then S (P) in '0' .. '9' loop
                  V := V * 10 + (Character'Pos (S (P)) - Character'Pos ('0'));
                  P := P + 1;
               end loop;
               return V;
            end;
         end if;
         Pos := Pos + Needle'Length;
      end loop;
      return 0;
   end Nth_Attr;

   --  Assert the pixel geometry of a badge: the total width, the label and
   --  value segment widths, the value segment's x offset (it must start
   --  exactly where the label segment ends), and the two centered text
   --  positions.  These numbers pin the per-glyph advance-width table and
   --  the fixed 20px total segment padding that Badge_SVG sizes segments
   --  with, so a regression in either fails loudly instead of silently
   --  producing flush or lopsided badges.
   procedure Check_Geometry
     (R    : in out Adacovex.Test_Support.Runner'Class;
      SVG  : String;
      Name : String;
      LW   : Natural;
      --  label segment width  (text + 10px each side)
      VW   : Natural;
      --  value segment width
      TW   : Natural;
      --  total badge width    (LW + VW)
      LX   : Natural;
      --  label text x (segment centre)
      VX   : Natural)  --  value text x (segment centre)
   is
   begin
      R.Check (Nth_Attr (SVG, "width", 1) = TW, Name & ": total width");
      R.Check
        (Nth_Attr (SVG, "width", 3) = LW, Name & ": label segment width");
      R.Check
        (Nth_Attr (SVG, "width", 4) = VW, Name & ": value segment width");
      R.Check
        (Nth_Attr (SVG, "x", 1) = LW, Name & ": value segment starts at LW");
      R.Check (Nth_Attr (SVG, "x", 2) = LX, Name & ": label text centered");
      R.Check (Nth_Attr (SVG, "x", 3) = VX, Name & ": value text centered");
   end Check_Geometry;

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
   begin
      --  SPARK badge: Platinum
      --  "SPARK" = 35px text (7 each) + 20 = 55; "Platinum" = 46px
      --  (P 7, l 3, a 6, t 3, i 3, n 7, u 7, m 10) + 20 = 66; total 121.
      declare
         S : constant String := Render_SPARK_Badge (Platinum);
      begin
         R.Check (Contains (S, "<svg"), "SPARK Platinum: contains <svg");
         R.Check (Contains (S, "SPARK"), "SPARK Platinum: label");
         R.Check (Contains (S, "Platinum"), "SPARK Platinum: value");
         Check_Geometry (R, S, "SPARK Platinum", 55, 66, 121, 27, 88);
      end;

      --  SPARK badge: Stone
      --  "Stone" = 30px text + 20 = 50; total 105.
      declare
         S : constant String := Render_SPARK_Badge (Stone);
      begin
         R.Check (Contains (S, "<svg"), "SPARK Stone: contains <svg");
         R.Check (Contains (S, "SPARK"), "SPARK Stone: label");
         R.Check (Contains (S, "Stone"), "SPARK Stone: value");
         Check_Geometry (R, S, "SPARK Stone", 55, 50, 105, 27, 80);
      end;

      --  Tests badge: 0/0
      --  "Tests" = 28px text + 20 = 48; "0 Passed" = 48px + 20 = 68; total 116.
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
            Check_Geometry (R, S, "Tests 0/0", 48, 68, 116, 24, 82);
         end;
      end;

      --  Tests badge: 10/0
      --  "10 Passed" = 55px text + 20 = 75; total 123.
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
            Check_Geometry (R, S, "Tests 10/0", 48, 75, 123, 24, 85);
         end;
      end;

      --  Tests badge: 5/2
      --  "5 Passed" = 48px text + 20 = 68 (same geometry as 0 Passed).
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
            Check_Geometry (R, S, "Tests 5/2", 48, 68, 116, 24, 82);
         end;
      end;

      --  DO-178C badge: Achieved
      --  "DO-178C" = 47px text (D 7, O 8, - 4, 1/7/8 7, C 7) + 20 = 67;
      --  "DAL-C PASS" = 62px + 20 = 82; total 149.
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
            Check_Geometry (R, S, "DO-178C Achieved", 67, 82, 149, 33, 108);
         end;
      end;

      --  DO-178C badge: Unmet
      --  "DAL-C FAIL" = 56px text + 20 = 76; total 143.
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
            Check_Geometry (R, S, "DO-178C Unmet", 67, 76, 143, 33, 105);
         end;
      end;

      --  Compliance badge: ISO 26262 (ASIL B) via the standard-parameterized
      --  renderer.
      --  "ISO 26262" = 56px text (I 3, S 7, O 8, space 3, 2/6/2/6/2 7 each)
      --  + 20 = 76; "ASIL B PASS" = 64px + 20 = 84; total 160.
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
            Check_Geometry (R, S, "ISO 26262 Achieved", 76, 84, 160, 38, 118);
         end;
      end;

      --  Compliance badge: IEC 62304 (Class A).
      --  "IEC 62304" = 55px text + 20 = 75; "Class A PASS" = 69px + 20 = 89;
      --  total 164.
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
            Check_Geometry (R, S, "IEC 62304 Achieved", 75, 89, 164, 37, 119);
         end;
      end;

      --  Server badge endpoints: the exact render calls the /badge/*.svg
      --  routes in adacovex-server-http.adb make, pinned so the LLR-SERVER-01
      --  badge surface (spark, tests, do178c, iso26262, iec62304) cannot
      --  regress without a test failure.  The routes serve
      --  Render_SPARK_Badge (Proof.Level), Render_Tests_Badge (Tests), and
      --  Render_Compliance_Badge (Assess, DO_178C / ISO_26262 / IEC_62304)
      --  respectively; do178c.svg goes through the standard-parameterized
      --  renderer (not the Render_DO178C_Badge wrapper), so its geometry is
      --  pinned here through the exact server call.
      declare
         S : constant String := Render_SPARK_Badge (Platinum);
      begin
         R.Check (Contains (S, "<svg"), "/badge/spark.svg: contains <svg");
         R.Check (Contains (S, "SPARK"), "/badge/spark.svg: label");
         R.Check (Contains (S, "Platinum"), "/badge/spark.svg: value");
         Check_Geometry (R, S, "/badge/spark.svg", 55, 66, 121, 27, 88);
      end;

      --  /badge/tests.svg with the self-assessment count (738 Passed): the
      --  same 130px geometry make run-self emits into docs/badges/tests.svg.
      declare
         Summary : Test_Summary;
      begin
         Summary.Total_Passed := 738;
         Summary.Total_Failed := 0;
         declare
            S : constant String := Render_Tests_Badge (Summary);
         begin
            R.Check (Contains (S, "<svg"), "/badge/tests.svg: contains <svg");
            R.Check (Contains (S, "Tests"), "/badge/tests.svg: label");
            R.Check (Contains (S, "738 Passed"), "/badge/tests.svg: value");
            Check_Geometry (R, S, "/badge/tests.svg", 48, 82, 130, 24, 89);
         end;
      end;

      --  /badge/do178c.svg: Render_Compliance_Badge (Assess, DO_178C) --
      --  Achieved ("DAL-C PASS", 67/82/149) and Unmet ("DAL-C FAIL",
      --  67/76/143), both through the exact server call.
      declare
         Assess : DAL_Assessment;
      begin
         Assess.Status := Achieved;
         Assess.Target_DAL := DAL_C;
         declare
            S : constant String := Render_Compliance_Badge (Assess, DO_178C);
         begin
            R.Check (Contains (S, "<svg"), "/badge/do178c.svg: contains <svg");
            R.Check (Contains (S, "DO-178C"), "/badge/do178c.svg: label");
            R.Check (Contains (S, "DAL-C PASS"), "/badge/do178c.svg: value");
            Check_Geometry (R, S, "/badge/do178c.svg", 67, 82, 149, 33, 108);
         end;
      end;
      declare
         Assess : DAL_Assessment;
      begin
         Assess.Status := Unmet;
         Assess.Target_DAL := DAL_C;
         declare
            S : constant String := Render_Compliance_Badge (Assess, DO_178C);
         begin
            R.Check (Contains (S, "<svg"), "/badge/do178c.svg (Unmet): <svg");
            R.Check
              (Contains (S, "DAL-C FAIL"), "/badge/do178c.svg: FAIL value");
            Check_Geometry
              (R, S, "/badge/do178c.svg (Unmet)", 67, 76, 143, 33, 105);
         end;
      end;

      --  /badge/iso26262.svg and /badge/iec62304.svg: the remaining two
      --  compliance routes, pinned through their standard-parameterized
      --  server calls.
      declare
         Assess : DAL_Assessment;
      begin
         Assess.Status := Achieved;
         Assess.Target_DAL := DAL_C;
         declare
            S : constant String := Render_Compliance_Badge (Assess, ISO_26262);
         begin
            R.Check
              (Contains (S, "<svg"), "/badge/iso26262.svg: contains <svg");
            R.Check (Contains (S, "ISO 26262"), "/badge/iso26262.svg: label");
            R.Check
              (Contains (S, "ASIL B PASS"), "/badge/iso26262.svg: value");
            Check_Geometry (R, S, "/badge/iso26262.svg", 76, 84, 160, 38, 118);
         end;
      end;
      declare
         Assess : DAL_Assessment;
      begin
         Assess.Status := Achieved;
         Assess.Target_DAL := DAL_C;
         declare
            S : constant String := Render_Compliance_Badge (Assess, IEC_62304);
         begin
            R.Check
              (Contains (S, "<svg"), "/badge/iec62304.svg: contains <svg");
            R.Check (Contains (S, "IEC 62304"), "/badge/iec62304.svg: label");
            R.Check
              (Contains (S, "Class A PASS"), "/badge/iec62304.svg: value");
            Check_Geometry (R, S, "/badge/iec62304.svg", 75, 89, 164, 37, 119);
         end;
      end;

      --  Docstring badge: 100%
      --  "docs" = 26px text + 20 = 46; "100%" = 30px (1/0/0 7 each, % 9)
      --  + 20 = 50; total 96.
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
            Check_Geometry (R, S, "docs 100%", 46, 50, 96, 23, 71);
         end;
      end;

      --  Docstring badge: 50%
      --  "50%" = 23px text + 20 = 43; total 89.
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
            Check_Geometry (R, S, "docs 50%", 46, 43, 89, 23, 67);
         end;
      end;

      --  Docstring badge: 0%
      --  "0%" = 16px text + 20 = 36; total 82.
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
            Check_Geometry (R, S, "docs 0%", 46, 36, 82, 23, 64);
         end;
      end;
   end Run;

end Adacovex_Renderer_SVG_Tests;
