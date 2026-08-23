with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Adacovex.Dashboard_Template;

package body Adacovex.Renderers.HTML is

   use Ada.Strings.Unbounded;
   use type Types.Test_Status;
   use type Types.DAL_Status;
   use type Types.Dashboard_Theme;
   use type Types.Component_Kind;

   function Img (N : Natural) return String is
      S : constant String := Natural'Image (N);
   begin
      return S (2 .. S'Last);
   end Img;

   --  Replace every occurrence of From in S with To (pure string helper).
   function Replace_All (S, From, To : String) return String is
      R : Unbounded_String;
      I : Positive := S'First;
   begin
      loop
         declare
            J : constant Natural := Ada.Strings.Fixed.Index (S, From, I);
         begin
            if J = 0 then
               Append (R, S (I .. S'Last));
               exit;
            end if;
            Append (R, S (I .. J - 1));
            Append (R, To);
            I := J + From'Length;
            exit when I > S'Last;
         end;
      end loop;
      return To_String (R);
   end Replace_All;

   function Render_Dashboard
     (Doc_Metrics   : Types.Docstring_Metrics;
      Proof         : Types.Proof_Summary;
      Tests         : Types.Implementation.Test_Summary;
      DAL_Assess    : Types.Implementation.DAL_Assessment;
      Packages      : Types.Implementation.Package_Vectors.Vector;
      All_Standards : Boolean := False;
      Theme         : Types.Dashboard_Theme := Types.System_Theme)
      return String
   is
      Cards : Unbounded_String;

      procedure Put_Card (S : String) is
      begin
         Append (Cards, S);
      end Put_Card;

      Spark_Color : constant String :=
        (case Proof.Level is
           when Types.Platinum => "#E5E4E2",
           when Types.Gold     => "#FFD700",
           when Types.Silver   => "#C0C0C0",
           when Types.Bronze   => "#CD7F32",
           when Types.Stone    => "#888888");
   begin
      --  Status badges card.
      Put_Card
        ("<div class=""card""><h2>Status Badges</h2>"
         & "<div class=""badge-container"">");
      Put_Card ("<img src=""/badge/spark.svg"" alt=""SPARK Badge"">");
      Put_Card ("<img src=""/badge/tests.svg"" alt=""Tests Badge"">");
      if All_Standards then
         for Std in Types.Compliance_Standard loop
            Put_Card ("<img src=""/badge/");
            Put_Card (Types.Standard_Slug (Std));
            Put_Card (".svg"" alt=""");
            Put_Card (Types.To_String (Std));
            Put_Card (" Badge"">");
         end loop;
      else
         Put_Card ("<img src=""/badge/");
         Put_Card (Types.Standard_Slug (DAL_Assess.Standard));
         Put_Card (".svg"" alt=""");
         Put_Card (Types.To_String (DAL_Assess.Standard));
         Put_Card (" Badge"">");
      end if;
      Put_Card ("</div></div>");

      --  Source overview card.
      Put_Card ("<div class=""card""><h2>Source Overview</h2>");
      Put_Card ("<table><tr><th>Metric</th><th>Value</th></tr>");
      Put_Card ("<tr><td>Packages Scanned</td><td>");
      Put_Card (Img (Natural (Packages.Length)));
      Put_Card ("</td></tr>");
      Put_Card ("<tr><td>Total Subprograms</td><td>");
      Put_Card (Img (Doc_Metrics.Total_Subprograms));
      Put_Card ("</td></tr>");
      Put_Card ("<tr><td>Docstring Coverage</td><td>");
      Put_Card (Img (Doc_Metrics.Coverage_Pct));
      Put_Card ("%</td></tr></table></div>");

      --  SPARK proof analysis card.
      Put_Card ("<div class=""card""><h2>SPARK Proof Analysis</h2>");
      Put_Card
        ("<table><tr><th>Check Type</th><th>Total</th><th>Proved</th></tr>");
      Put_Card
        ("<tr><td>Level</td><td colspan=""2"" class=""spark"" style=""color:");
      Put_Card (Spark_Color);
      Put_Card (""">");
      Put_Card (Types.To_String (Proof.Level));
      Put_Card ("</td></tr>");
      Put_Card ("<tr><td>Flow</td><td>");
      Put_Card (Img (Proof.Flow_Checks));
      Put_Card ("</td><td>");
      Put_Card (Img (Proof.Flow_Proved));
      Put_Card ("</td></tr>");
      Put_Card ("<tr><td>Initialization</td><td>");
      Put_Card (Img (Proof.Init_Checks));
      Put_Card ("</td><td>");
      Put_Card (Img (Proof.Init_Proved));
      Put_Card ("</td></tr>");
      Put_Card ("<tr><td>Runtime</td><td>");
      Put_Card (Img (Proof.Runtime_Checks));
      Put_Card ("</td><td>");
      Put_Card (Img (Proof.Runtime_Proved));
      Put_Card ("</td></tr>");
      Put_Card ("<tr><td>Assertions</td><td>");
      Put_Card (Img (Proof.Assertions));
      Put_Card ("</td><td>");
      Put_Card (Img (Proof.Assert_Proved));
      Put_Card ("</td></tr>");
      Put_Card ("<tr><td>Functional</td><td>");
      Put_Card (Img (Proof.Functional_Ct));
      Put_Card ("</td><td>");
      Put_Card (Img (Proof.Functional_Proved));
      Put_Card ("</td></tr>");
      Put_Card ("<tr><td>Total VCs</td><td>");
      Put_Card (Img (Proof.Total_VCs));
      Put_Card ("</td><td>");
      Put_Card (Img (Proof.Proved_VCs));
      Put_Card ("</td></tr></table></div>");

      --  Test results card.
      Put_Card ("<div class=""card""><h2>Test Results</h2>");
      Put_Card
        ("<table><tr><th>Category</th><th>Tests</th><th>Status</th></tr>");
      for C in 1 .. Integer (Tests.Categories.Length) loop
         Put_Card ("<tr><td>");
         Put_Card
           (Tests.Categories (C).Category (1 .. Tests.Categories (C).Cat_Len));
         Put_Card ("</td><td>");
         Put_Card (Img (Tests.Categories (C).Test_Count));
         Put_Card ("</td><td class=""");
         Put_Card
           (if Tests.Categories (C).Status = Types.Pass
            then "pass"
            else "fail");
         Put_Card (""">");
         Put_Card (Types.To_String (Tests.Categories (C).Status));
         Put_Card ("</td></tr>");
      end loop;
      Put_Card ("<tr><td><strong>Total</strong></td><td><strong>");
      Put_Card (Img (Tests.Total_Passed + Tests.Total_Failed));
      Put_Card ("</strong></td><td><strong class=""");
      Put_Card (if Tests.Total_Failed = 0 then "pass" else "fail");
      Put_Card (""">Passed: ");
      Put_Card (Img (Tests.Total_Passed));
      Put_Card (", Failed: ");
      Put_Card (Img (Tests.Total_Failed));
      Put_Card ("</strong></td></tr></table></div>");

      --  Compliance card (single standard or all standards at the tier).
      Put_Card ("<div class=""card"">");
      if All_Standards then
         Put_Card ("<h2>Compliance (all standards)</h2>");
      else
         Put_Card ("<h2>");
         Put_Card (Types.To_String (DAL_Assess.Standard));
         Put_Card (" Compliance</h2>");
      end if;
      Put_Card ("<table><tr><th>Criterion</th><th>Status</th></tr>");
      if All_Standards then
         for Std in Types.Compliance_Standard loop
            Put_Card ("<tr><td>");
            Put_Card (Types.To_String (Std));
            Put_Card (" level</td><td class=""");
            Put_Card
              (if DAL_Assess.Status = Types.Achieved then "pass" else "fail");
            Put_Card (""">");
            Put_Card (Types.Standard_Level_Name (Std, DAL_Assess.Target_DAL));
            Put_Card (" (");
            Put_Card (Types.To_String (DAL_Assess.Status));
            Put_Card (")</td></tr>");
         end loop;
      else
         Put_Card ("<tr><td>Target level</td><td>");
         Put_Card
           (Types.Standard_Level_Name
              (DAL_Assess.Standard, DAL_Assess.Target_DAL));
         Put_Card ("</td></tr>");
         Put_Card ("<tr><td>Overall Status</td><td class=""");
         Put_Card
           (if DAL_Assess.Status = Types.Achieved then "pass" else "fail");
         Put_Card (""">");
         Put_Card (Types.To_String (DAL_Assess.Status));
         Put_Card ("</td></tr>");
      end if;
      Put_Card ("<tr><td>HLR Traced</td><td>");
      Put_Card (Img (DAL_Assess.HLR_Found));
      Put_Card (" / ");
      Put_Card (Img (DAL_Assess.HLR_Total));
      Put_Card ("</td></tr>");
      Put_Card ("<tr><td>Orphan Tags</td><td>");
      Put_Card (if DAL_Assess.Orphan_Tags then "Yes" else "No");
      Put_Card ("</td></tr>");
      Put_Card ("<tr><td>Tests Passing</td><td>");
      Put_Card (if DAL_Assess.Tests_Passing then "Yes" else "No");
      Put_Card ("</td></tr>");
      if not DAL_Assess.Failed_Reasons.Is_Empty then
         for R in 1 .. Integer (DAL_Assess.Failed_Reasons.Length) loop
            Put_Card ("<tr><td>Failure</td><td class=""fail"">");
            Put_Card (DAL_Assess.Failed_Reasons (R));
            Put_Card ("</td></tr>");
         end loop;
      end if;
      Put_Card ("</table></div>");

      --  HLR traceability card.
      Put_Card ("<div class=""card""><h2>HLR Traceability</h2>");
      Put_Card ("<table><tr><th>Package</th><th>HLR Tags</th></tr>");
      for P in 1 .. Integer (Packages.Length) loop
         if not Packages (P).HLR_Tags.Is_Empty then
            Put_Card ("<tr><td>");
            Put_Card (Packages (P).Name (1 .. Packages (P).Name_Len));
            Put_Card ("</td><td>");
            for T in 1 .. Integer (Packages (P).HLR_Tags.Length) loop
               if T > 1 then
                  Put_Card (", ");
               end if;
               Put_Card
                 (Packages (P).HLR_Tags (T).Tag
                    (1 .. Packages (P).HLR_Tags (T).Len));
            end loop;
            Put_Card ("</td></tr>");
         end if;
      end loop;
      Put_Card ("</table></div>");

      --  Inject the cards + chart cards into the bundled page shell and set
      --  the initial theme marker (read by the theme script as the CLI
      --  preference).
      return
        Replace_All
          (Replace_All
             (Replace_All
                (Adacovex.Dashboard_Template.Template,
                 "__CARDS__",
                 To_String (Cards)),
              "__CHARTS__",
              Render_Charts (Doc_Metrics, Proof, Tests)),
           "__THEME__",
           Types.To_String (Theme));
   end Render_Dashboard;

   --  Percentage of N in M, rounded down, clamped to 0..100.  Chart sizes
   --  are unitless 0..1 fractions: divide by 100.
   function Pct (Part, Total : Natural) return Natural is
   begin
      if Total = 0 then
         return 0;
      end if;
      return (Part * 100) / Total;
   end Pct;

   function Render_Charts
     (Doc_Metrics : Types.Docstring_Metrics;
      Proof       : Types.Proof_Summary;
      Tests       : Types.Implementation.Test_Summary) return String
   is
      R : Unbounded_String;

      procedure Put (S : String) is
      begin
         Append (R, S);
      end Put;

      --  A single pie/donut slice: label + start/end (x100) + value.
      procedure Slice_Row
        (Label : String; Start, Finish : Natural; Value : Natural) is
      begin
         Put ("<tr><th scope=""row"">");
         Put (Label);
         Put ("</th><td style=""--start:");
         Put (Img (Start));
         Put (";--end:");
         Put (Img (Finish));
         Put ("""><span class=""data"">");
         Put (Img (Value));
         Put ("</span></td></tr>");
      end Slice_Row;

      --  A single bar row: label + size fraction (0..100) + value.
      procedure Bar_Row
        (Label : String; Fraction : Natural; Value : Natural) is
      begin
         Put ("<tr><th scope=""row"">");
         Put (Label);
         Put ("</th><td style=""--size:");
         Put (Img (Fraction));
         Put (".0""><span class=""data"">");
         Put (Img (Value));
         Put ("</span></td></tr>");
      end Bar_Row;
   begin
      --  SPARK proof donut (proved + total slices fill the circle)
      Put ("<div class=""chart-card""><h3>SPARK Proof</h3>");
      Put ("<table class=""charts-css donut show-labels"">");
      Put ("<caption>SPARK proof progress</caption><tbody>");
      if Proof.Total_VCs > 0 then
         declare
            P : constant Natural := Pct (Proof.Proved_VCs, Proof.Total_VCs);
         begin
            Slice_Row ("Proved", 0, P, Proof.Proved_VCs);
            Slice_Row ("Total", P, 100, Proof.Total_VCs);
         end;
      else
         Slice_Row ("No VCs", 0, 100, 0);
      end if;
      Put ("</tbody></table></div>");

      --  Proof categories column
      Put ("<div class=""chart-card""><h3>Proof Check Types</h3>");
      Put ("<table class=""charts-css column show-labels show-primary-axis"">");
      Put ("<caption>Proved checks by category</caption><tbody>");
      Bar_Row ("Flow", Pct (Proof.Flow_Proved, Proof.Flow_Checks), Proof.Flow_Proved);
      Bar_Row ("Init", Pct (Proof.Init_Proved, Proof.Init_Checks), Proof.Init_Proved);
      Bar_Row ("Runtime", Pct (Proof.Runtime_Proved, Proof.Runtime_Checks), Proof.Runtime_Proved);
      Bar_Row ("Assert", Pct (Proof.Assert_Proved, Proof.Assertions), Proof.Assert_Proved);
      Bar_Row ("Functional", Pct (Proof.Functional_Proved, Proof.Functional_Ct), Proof.Functional_Proved);
      Put ("</tbody></table></div>");

      --  Test categories bar
      Put ("<div class=""chart-card""><h3>Test Results by Category</h3>");
      Put ("<table class=""charts-css bar show-labels"">");
      Put ("<caption>Test counts by category</caption><tbody>");
      for C in 1 .. Integer (Tests.Categories.Length) loop
         declare
            Cat : Types.Test_Metrics renames Tests.Categories (C);
         begin
            Bar_Row
              (Cat.Category (1 .. Cat.Cat_Len), 100, Cat.Test_Count);
         end;
      end loop;
      Put ("</tbody></table></div>");

      --  Docstring coverage bar
      Put ("<div class=""chart-card""><h3>Docstring Coverage</h3>");
      Put ("<table class=""charts-css bar show-labels"">");
      Put ("<caption>Documented subprograms</caption><tbody>");
      Bar_Row
        ("Documented",
         Doc_Metrics.Coverage_Pct,
         Doc_Metrics.Documented_Subprogs);
      Put ("</tbody></table></div>");

      return To_String (R);
   end Render_Charts;

   --  Machine name of a dependency scope for JSON output.
   function Scope_Name (S : Types.Component_Scope) return String is
   begin
      return
        (case S is
           when Types.Scope_Base       => "base",
           when Types.Scope_Dev        => "dev",
           when Types.Scope_Transitive => "transitive",
           when Types.Scope_Vendored   => "vendored");
   end Scope_Name;

   --  Escape a fixed-width string field for JSON (quotes + backslashes).
   function Json_Escape (S : String) return String is
      R : Unbounded_String;
   begin
      for I in S'Range loop
         case S (I) is
            when '"' =>
               --  JSON escape: backslash + quote
               Append (R, "\""");
            when '\' =>
               --  JSON escape: backslash + backslash
               Append (R, "\\");
            when others =>
               Append (R, S (I));
         end case;
      end loop;
      return To_String (R);
   end Json_Escape;

   function Render_Deps_JSON
     (Graph : Types.Implementation.Component_Vectors.Vector) return String
   is
      Result : Unbounded_String;

      procedure Put (S : String) is
      begin
         Append (Result, S);
      end Put;

      --  Emit a quoted field from a Desc_Field/Path_Field + length.
      procedure Put_Field (F : String; Len : Natural) is
      begin
         Put ("""");
         Put (Json_Escape (F (1 .. Len)));
         Put ("""");
      end Put_Field;
   begin
      Put ("{""dependencies"":[");
      for I in 1 .. Integer (Graph.Length) loop
         if I > 1 then
            Put (",");
         end if;
         Put ("{""name"":");
         Put_Field (Graph (I).Name, Graph (I).Name_Len);
         Put (",""version"":");
         Put_Field (Graph (I).Version, Graph (I).Version_Len);
         Put (",""scope"":""");
         Put (Scope_Name (Graph (I).Scope));
         Put (""",""license"":");
         Put_Field (Graph (I).License, Graph (I).License_Len);
         Put (",""kind"":""");
         Put
           (if Types.Component_Kind'(Graph (I).Kind) = Types.Root_Component
            then "root"
            else "dependency");
         Put (""",""parent"":");
         Put (Img (Graph (I).Parent));
         Put (",""purl"":");
         Put_Field (Graph (I).PURL, Graph (I).PURL_Len);
         Put ("}");
      end loop;
      Put ("]}");

      return To_String (Result);
   end Render_Deps_JSON;

   function Render_Metrics_JSON
     (Doc_Metrics   : Types.Docstring_Metrics;
      Proof         : Types.Proof_Summary;
      Tests         : Types.Implementation.Test_Summary;
      DAL_Assess    : Types.Implementation.DAL_Assessment;
      All_Standards : Boolean := False) return String
   is
      Result : Unbounded_String;

      procedure Put (S : String) is
      begin
         Append (Result, S);
      end Put;
   begin
      Put ("{");
      Put ("""spark_level"":""");
      Put (Types.To_String (Proof.Level));
      Put (""",");
      Put ("""total_vcs"":");
      Put (Img (Proof.Total_VCs));
      Put (",");
      Put ("""proved_vcs"":");
      Put (Img (Proof.Proved_VCs));
      Put (",");
      Put ("""tests_passed"":");
      Put (Img (Tests.Total_Passed));
      Put (",");
      Put ("""tests_failed"":");
      Put (Img (Tests.Total_Failed));
      Put (",");
      Put ("""doc_coverage"":");
      Put (Img (Doc_Metrics.Coverage_Pct));
      Put (",");
      Put ("""standard"":""");
      if All_Standards then
         Put ("all");
      else
         Put (Types.To_String (DAL_Assess.Standard));
      end if;
      Put (""",");
      Put ("""level"":""");
      if All_Standards then
         Put
           (Types.Standard_Level_Name (Types.DO_178C, DAL_Assess.Target_DAL));
      else
         Put
           (Types.Standard_Level_Name
              (DAL_Assess.Standard, DAL_Assess.Target_DAL));
      end if;
      Put (""",");
      Put ("""dal_status"":""");
      Put (Types.To_String (DAL_Assess.Status));
      Put ("""");
      if All_Standards then
         Put (",""standards"":{");
         declare
            First : Boolean := True;
         begin
            for Std in Types.Compliance_Standard loop
               if not First then
                  Put (",");
               end if;
               First := False;
               Put ("""");
               Put (Types.To_String (Std));
               Put (""":{""level"":""");
               Put (Types.Standard_Level_Name (Std, DAL_Assess.Target_DAL));
               Put (""",""status"":""");
               Put (Types.To_String (DAL_Assess.Status));
               Put ("""}");
            end loop;
         end;
         Put ("}");
      end if;
      Put ("}");

      return To_String (Result);
   end Render_Metrics_JSON;

end Adacovex.Renderers.HTML;
