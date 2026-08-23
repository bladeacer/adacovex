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

   function Img_Frac (Num : Natural; Den : Natural) return String is
      --  0..1 fraction with one decimal, e.g. "0.5"
      P : Natural := 0;
   begin
      if Den = 0 then
         return "0.0";
      end if;
      P := (Num * 10) / Den;
      --  Clamp 10 -> 1.0
      if P >= 10 then
         return "1.0";
      end if;
      return "0." & Img (P);
   end Img_Frac;

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

   --  Escape HTML special chars in a bounded slice.
   function Html_Escape (S : String) return String is
      R : Unbounded_String;
   begin
      for I in S'Range loop
         case S (I) is
            when '&'    =>
               Append (R, "&amp;");

            when '<'    =>
               Append (R, "&lt;");

            when '>'    =>
               Append (R, "&gt;");

            when '"'    =>
               Append (R, "&quot;");

            when others =>
               Append (R, S (I .. I));
         end case;
      end loop;
      return To_String (R);
   end Html_Escape;

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
      Tests       : Types.Implementation.Test_Summary;
      Graph       : Types.Implementation.Component_Vectors.Vector)
      return String
   is
      R : Unbounded_String;

      procedure Put (S : String) is
      begin
         Append (R, S);
      end Put;

      --  A single pie/donut slice: label + start/end (0..100) + value.
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

      --  A single bar/column row: label + size fraction 0..1 + value.
      procedure Bar_Row
        (Label : String; Part : Natural; Total : Natural; Value : Natural) is
      begin
         Put ("<tr><th scope=""row"">");
         Put (Html_Escape (Label));
         Put ("</th><td style=""--size:");
         if Total = 0 then
            Put ("0.0");
         else
            Put (Img_Frac (Part, Total));
         end if;
         Put ("""><span class=""data"">");
         Put (Img (Value));
         Put ("</span></td></tr>");
      end Bar_Row;
   begin
      --  SPARK proof donut: proved vs unproved (not total) so circle always sums to 100
      Put ("<div class=""chart-card""><h3>SPARK Proof</h3>");
      Put ("<table class=""charts-css donut show-labels"">");
      Put ("<caption>SPARK proof progress</caption><tbody>");
      if Proof.Total_VCs > 0 then
         declare
            U : constant Natural := Proof.Total_VCs - Proof.Proved_VCs;
            P : constant Natural := Pct (Proof.Proved_VCs, Proof.Total_VCs);
         begin
            Slice_Row ("Proved", 0, P, Proof.Proved_VCs);
            if U > 0 then
               Slice_Row ("Unproved", P, 100, U);
            end if;
         end;
      else
         Slice_Row ("No VCs", 0, 100, 0);
      end if;
      Put ("</tbody></table>");
      Put ("<p style=""color:var(--muted);font-size:.82rem;margin:6px 0 0"">");
      Put
        (Img (Proof.Proved_VCs)
         & " / "
         & Img (Proof.Total_VCs)
         & " VCs proved");
      Put ("</p></div>");

      --  Proof categories column (proved vs total per category)
      Put ("<div class=""chart-card""><h3>Proof Check Types</h3>");
      Put
        ("<table class=""charts-css column show-labels show-primary-axis"">");
      Put ("<caption>Proved checks by category</caption><tbody>");
      Bar_Row
        ("Flow", Proof.Flow_Proved, Proof.Flow_Checks, Proof.Flow_Proved);
      Bar_Row
        ("Init", Proof.Init_Proved, Proof.Init_Checks, Proof.Init_Proved);
      Bar_Row
        ("Runtime",
         Proof.Runtime_Proved,
         Proof.Runtime_Checks,
         Proof.Runtime_Proved);
      Bar_Row
        ("Assert", Proof.Assert_Proved, Proof.Assertions, Proof.Assert_Proved);
      Bar_Row
        ("Functional",
         Proof.Functional_Proved,
         Proof.Functional_Ct,
         Proof.Functional_Proved);
      Put ("</tbody></table></div>");

      --  Test categories bar (each category as its own row, normalized by max)
      Put ("<div class=""chart-card""><h3>Test Results by Category</h3>");
      Put ("<table class=""charts-css bar show-labels"">");
      Put ("<caption>Test counts by category</caption><tbody>");
      if Tests.Categories.Is_Empty then
         Bar_Row ("No categories", 0, 1, 0);
      else
         declare
            Max_Ct : Natural := 1;
         begin
            for C in 1 .. Integer (Tests.Categories.Length) loop
               if Tests.Categories (C).Test_Count > Max_Ct then
                  Max_Ct := Tests.Categories (C).Test_Count;
               end if;
            end loop;
            for C in 1 .. Integer (Tests.Categories.Length) loop
               declare
                  Cat : Types.Test_Metrics renames Tests.Categories (C);
               begin
                  Bar_Row
                    (Cat.Category (1 .. Cat.Cat_Len),
                     Cat.Test_Count,
                     Max_Ct,
                     Cat.Test_Count);
               end;
            end loop;
         end;
      end if;
      Put ("</tbody></table></div>");

      --  Docstring coverage bar
      Put ("<div class=""chart-card""><h3>Docstring Coverage</h3>");
      Put ("<table class=""charts-css bar show-labels"">");
      Put ("<caption>Documented subprograms</caption><tbody>");
      if Doc_Metrics.Total_Subprograms = 0 then
         Bar_Row ("No subprograms", 0, 1, 0);
      else
         Bar_Row
           ("Documented",
            Doc_Metrics.Documented_Subprogs,
            Doc_Metrics.Total_Subprograms,
            Doc_Metrics.Documented_Subprogs);
      end if;
      Put ("</tbody></table></div>");

      --  Test pass/fail pie
      Put ("<div class=""chart-card""><h3>Tests Pass/Fail</h3>");
      Put ("<table class=""charts-css pie show-labels"">");
      Put ("<caption>Pass vs fail</caption><tbody>");
      declare
         Total_T : constant Natural := Tests.Total_Passed + Tests.Total_Failed;
      begin
         if Total_T = 0 then
            Slice_Row ("No tests", 0, 100, 0);
         else
            declare
               P : constant Natural := Pct (Tests.Total_Passed, Total_T);
            begin
               Slice_Row ("Passed", 0, P, Tests.Total_Passed);
               if Tests.Total_Failed > 0 then
                  Slice_Row ("Failed", P, 100, Tests.Total_Failed);
               end if;
            end;
         end if;
      end;
      Put ("</tbody></table></div>");

      --  Dependency scope pie (if Graph not empty)
      if not Graph.Is_Empty then
         declare
            Base_Ct  : Natural := 0;
            Dev_Ct   : Natural := 0;
            Trans_Ct : Natural := 0;
            Vend_Ct  : Natural := 0;
         begin
            for I in 1 .. Integer (Graph.Length) loop
               case Graph (I).Scope is
                  when Types.Scope_Base       =>
                     Base_Ct := Base_Ct + 1;

                  when Types.Scope_Dev        =>
                     Dev_Ct := Dev_Ct + 1;

                  when Types.Scope_Transitive =>
                     Trans_Ct := Trans_Ct + 1;

                  when Types.Scope_Vendored   =>
                     Vend_Ct := Vend_Ct + 1;
               end case;
            end loop;
            declare
               Total : constant Natural :=
                 Base_Ct + Dev_Ct + Trans_Ct + Vend_Ct;
               Start : Natural := 0;
            begin
               if Total > 0 then
                  Put
                    ("<div class=""chart-card""><h3>Dependencies by Scope</h3>");
                  Put ("<table class=""charts-css pie show-labels"">");
                  Put ("<caption>Scope distribution</caption><tbody>");
                  if Base_Ct > 0 then
                     declare
                        F : constant Natural := Pct (Base_Ct, Total);
                     begin
                        Slice_Row ("base", Start, Start + F, Base_Ct);
                        Start := Start + F;
                     end;
                  end if;
                  if Dev_Ct > 0 then
                     declare
                        F : constant Natural := Pct (Dev_Ct, Total);
                     begin
                        Slice_Row ("dev", Start, Start + F, Dev_Ct);
                        Start := Start + F;
                     end;
                  end if;
                  if Trans_Ct > 0 then
                     declare
                        F : constant Natural := Pct (Trans_Ct, Total);
                     begin
                        Slice_Row ("transitive", Start, Start + F, Trans_Ct);
                        Start := Start + F;
                     end;
                  end if;
                  if Vend_Ct > 0 then
                     declare
                        F : constant Natural := Pct (Vend_Ct, Total);
                     begin
                        Slice_Row ("vendored", Start, Start + F, Vend_Ct);
                     end;
                  end if;
                  Put ("</tbody></table></div>");
               end if;
            end;
         end;
      end if;

      return To_String (R);
   end Render_Charts;

   function Render_Charts
     (Doc_Metrics : Types.Docstring_Metrics;
      Proof       : Types.Proof_Summary;
      Tests       : Types.Implementation.Test_Summary) return String
   is
      Empty : Types.Implementation.Component_Vectors.Vector;
   begin
      return Render_Charts (Doc_Metrics, Proof, Tests, Empty);
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
            when '"'    =>
               --  JSON escape: backslash + quote
               Append (R, "\""");

            when '\'    =>
               --  JSON escape: backslash + backslash
               Append (R, "\\");

            when others =>
               Append (R, S (I));
         end case;
      end loop;
      return To_String (R);
   end Json_Escape;

   function Render_Deps_HTML
     (Graph : Types.Implementation.Component_Vectors.Vector) return String
   is
      R : Unbounded_String;

      procedure Put (S : String) is
      begin
         Append (R, S);
      end Put;

      function Scope_Class (S : Types.Component_Scope) return String is
      begin
         return
           (case S is
              when Types.Scope_Base       => "scope-base",
              when Types.Scope_Dev        => "scope-dev",
              when Types.Scope_Transitive => "scope-transitive",
              when Types.Scope_Vendored   => "scope-vendored");
      end Scope_Class;

      --  Count direct children of node Idx
      function Child_Count (Idx : Positive) return Natural is
         C : Natural := 0;
      begin
         for J in 1 .. Integer (Graph.Length) loop
            if Graph (J).Parent = Idx then
               C := C + 1;
            end if;
         end loop;
         return C;
      end Child_Count;

      procedure Render_Node (Idx : Positive; Depth : Natural) is
         Info         : Types.Implementation.Component_Info renames
           Graph (Idx);
         Has_Children : constant Boolean := Child_Count (Idx) > 0;
      begin
         Put
           ("<li class=""dep-node"" data-name="""
            & Html_Escape (Info.Name (1 .. Info.Name_Len))
            & """ data-scope="""
            & Scope_Name (Info.Scope)
            & """>");
         if Has_Children then
            Put ("<details");
            if Depth < 1 then
               Put (" open");
            end if;
            Put (">");
            Put ("<summary>");
         else
            Put
              ("<div style=""border:1px solid var(--border);"
               & "border-radius:10px;background:var(--card);"
               & "padding:8px 12px;display:flex;align-items:center;"
               & "gap:10px;flex-wrap:wrap;line-height:1.5"">");
         end if;

         Put
           ("<strong>"
            & Html_Escape (Info.Name (1 .. Info.Name_Len))
            & "</strong>");
         if Info.Version_Len > 0 then
            Put
              ("<span class=""dep-badge"">"
               & Html_Escape (Info.Version (1 .. Info.Version_Len))
               & "</span>");
         end if;
         Put
           ("<span class=""dep-badge "
            & Scope_Class (Info.Scope)
            & """>"
            & Scope_Name (Info.Scope)
            & "</span>");
         if Info.Kind = Types.Root_Component then
            Put ("<span class=""dep-badge"">root</span>");
         end if;
         if Child_Count (Idx) > 0 then
            Put
              ("<span class=""dep-badge"">"
               & Img (Child_Count (Idx))
               & " deps</span>");
         end if;
         if Info.License_Len > 0 then
            Put
              ("<span class=""dep-meta"">"
               & Html_Escape (Info.License (1 .. Info.License_Len))
               & "</span>");
         end if;
         if Info.PURL_Len > 0 then
            Put
              ("<span class=""dep-meta"" title=""PURL"">"
               & Html_Escape (Info.PURL (1 .. Info.PURL_Len))
               & "</span>");
         end if;

         if Has_Children then
            Put ("</summary>");
         else
            Put ("</div>");
         end if;

         if Has_Children then
            Put ("<ul>");
            for J in 1 .. Integer (Graph.Length) loop
               if Graph (J).Parent = Idx then
                  Render_Node (J, Depth + 1);
               end if;
            end loop;
            Put ("</ul>");
            Put ("</details>");
         end if;
         Put ("</li>");
      end Render_Node;

   begin
      if Graph.Is_Empty then
         return
           "<div class=""card""><p class=""dep-empty"">No dependencies resolved. "
           & "Add an <code>alire.toml</code> or check <code>--manifest</code>. "
           & "Raw data at <a href=""/api/deps"">/api/deps</a>.</p></div>";
      end if;

      Put ("<div class=""card"">");
      Put ("<h2>Dependency Graph</h2>");
      Put
        ("<p style=""color:var(--muted);font-size:.85rem;margin:4px 0 8px"">"
         & Img (Natural (Graph.Length))
         & " components &middot; "
         & "<a href=""/api/deps"">/api/deps JSON</a> &middot; "
         & "<a href=""/api/metrics"">/api/metrics</a></p>");
      Put ("<div class=""dep-toolbar"">");
      Put
        ("<input id=""dep-filter"" type=""search"" "
         & "placeholder=""Filter by name (e.g. gnatprove)"" "
         & "aria-label=""Filter dependencies"">");
      Put
        ("<label style=""display:flex;align-items:center;gap:4px;font-size:.85rem"">"
         & "<input type=""checkbox"" id=""filter-base"" checked "
         & "onchange=""filterByScope()""> base</label>");
      Put
        ("<label style=""display:flex;align-items:center;gap:4px;font-size:.85rem"">"
         & "<input type=""checkbox"" id=""filter-dev"" checked "
         & "onchange=""filterByScope()""> dev</label>");
      Put
        ("<label style=""display:flex;align-items:center;gap:4px;font-size:.85rem"">"
         & "<input type=""checkbox"" id=""filter-transitive"" checked "
         & "onchange=""filterByScope()""> transitive</label>");
      Put
        ("<label style=""display:flex;align-items:center;gap:4px;font-size:.85rem"">"
         & "<input type=""checkbox"" id=""filter-vendored"" checked "
         & "onchange=""filterByScope()""> vendored</label>");
      Put
        ("<button class=""theme-toggle"" onclick=""expandDeps(true)"">Expand all</button>");
      Put
        ("<button class=""theme-toggle"" onclick=""expandDeps(false)"">Collapse all</button>");
      Put ("</div>");
      Put ("<div class=""dep-tree""><ul>");
      --  Render roots (Parent=0 or index 1)
      declare
         Roots_Found : Boolean := False;
      begin
         for I in 1 .. Integer (Graph.Length) loop
            if Graph (I).Parent = 0 then
               Render_Node (I, 0);
               Roots_Found := True;
            end if;
         end loop;
         if not Roots_Found then
            --  Fallback: render index 1 as root
            Render_Node (1, 0);
         end if;
      end;
      Put ("</ul></div>");
      Put ("</div>");
      return To_String (R);
   end Render_Deps_HTML;

   --  Shared tabbed dashboard builder.
   function Render_Dashboard_Internal
     (Doc_Metrics   : Types.Docstring_Metrics;
      Proof         : Types.Proof_Summary;
      Tests         : Types.Implementation.Test_Summary;
      DAL_Assess    : Types.Implementation.DAL_Assessment;
      Packages      : Types.Implementation.Package_Vectors.Vector;
      Graph         : Types.Implementation.Component_Vectors.Vector;
      All_Standards : Boolean;
      Theme         : Types.Dashboard_Theme) return String
   is
      Overview : Unbounded_String;
      Proof_S  : Unbounded_String;
      Tests_S  : Unbounded_String;
      Compl    : Unbounded_String;
      HLR_S    : Unbounded_String;

      procedure Put_O (S : String) is
      begin
         Append (Overview, S);
      end Put_O;
      procedure Put_P (S : String) is
      begin
         Append (Proof_S, S);
      end Put_P;
      procedure Put_T (S : String) is
      begin
         Append (Tests_S, S);
      end Put_T;
      procedure Put_C (S : String) is
      begin
         Append (Compl, S);
      end Put_C;
      procedure Put_H (S : String) is
      begin
         Append (HLR_S, S);
      end Put_H;

      Spark_Color : constant String :=
        (case Proof.Level is
           when Types.Platinum => "#E5E4E2",
           when Types.Gold     => "#FFD700",
           when Types.Silver   => "#C0C0C0",
           when Types.Bronze   => "#CD7F32",
           when Types.Stone    => "#888888");
   begin
      --  Overview tab: badges + source overview
      Put_O
        ("<div class=""card""><h2>Status Badges</h2>"
         & "<div class=""badge-container"">");
      Put_O ("<img src=""/badge/spark.svg"" alt=""SPARK Badge"">");
      Put_O ("<img src=""/badge/tests.svg"" alt=""Tests Badge"">");
      if All_Standards then
         for Std in Types.Compliance_Standard loop
            Put_O ("<img src=""/badge/");
            Put_O (Types.Standard_Slug (Std));
            Put_O (".svg"" alt=""");
            Put_O (Types.To_String (Std));
            Put_O (" Badge"">");
         end loop;
      else
         Put_O ("<img src=""/badge/");
         Put_O (Types.Standard_Slug (DAL_Assess.Standard));
         Put_O (".svg"" alt=""");
         Put_O (Types.To_String (DAL_Assess.Standard));
         Put_O (" Badge"">");
      end if;
      Put_O
        ("</div><p style=""color:var(--muted);font-size:.82rem;"
         & "margin:8px 0 0"">Badges refresh from "
         & "<code>/badge/*.svg</code> endpoints.</p></div>");

      Put_O ("<div class=""tab-grid"">");
      Put_O ("<div class=""card""><h2>Source Overview</h2>");
      Put_O ("<table><tr><th>Metric</th><th>Value</th></tr>");
      Put_O ("<tr><td>Packages Scanned</td><td>");
      Put_O (Img (Natural (Packages.Length)));
      Put_O ("</td></tr>");
      Put_O ("<tr><td>Total Subprograms</td><td>");
      Put_O (Img (Doc_Metrics.Total_Subprograms));
      Put_O ("</td></tr>");
      Put_O ("<tr><td>Docstring Coverage</td><td>");
      Put_O (Img (Doc_Metrics.Coverage_Pct));
      Put_O ("%</td></tr></table></div>");

      Put_O ("<div class=""card""><h2>Quick Stats</h2><table>");
      Put_O
        ("<tr><td>SPARK Level</td><td class=""spark"" style=""color:"
         & Spark_Color
         & """>");
      Put_O (Types.To_String (Proof.Level) & "</td></tr>");
      Put_O
        ("<tr><td>VCs Proved</td><td>"
         & Img (Proof.Proved_VCs)
         & " / "
         & Img (Proof.Total_VCs)
         & "</td></tr>");
      Put_O
        ("<tr><td>Tests</td><td>"
         & Img (Tests.Total_Passed)
         & " passed, "
         & Img (Tests.Total_Failed)
         & " failed</td></tr>");
      Put_O
        ("<tr><td>Compliance</td><td class="""
         & (if DAL_Assess.Status = Types.Achieved then "pass" else "fail")
         & """>"
         & Types.To_String (DAL_Assess.Status)
         & "</td></tr>");
      Put_O
        ("<tr><td>Dependencies</td><td>"
         & Img (Natural (Graph.Length))
         & " components</td></tr>");
      Put_O ("</table></div>");
      Put_O ("</div>");

      --  Proof tab
      Put_P ("<div class=""card""><h2>SPARK Proof Analysis</h2>");
      Put_P
        ("<table><tr><th>Check Type</th><th>Total</th><th>Proved</th></tr>");
      Put_P
        ("<tr><td>Level</td><td colspan=""2"" class=""spark"" style=""color:");
      Put_P (Spark_Color);
      Put_P (""">");
      Put_P (Types.To_String (Proof.Level));
      Put_P ("</td></tr>");
      Put_P ("<tr><td>Flow</td><td>");
      Put_P (Img (Proof.Flow_Checks));
      Put_P ("</td><td>");
      Put_P (Img (Proof.Flow_Proved));
      Put_P ("</td></tr>");
      Put_P ("<tr><td>Initialization</td><td>");
      Put_P (Img (Proof.Init_Checks));
      Put_P ("</td><td>");
      Put_P (Img (Proof.Init_Proved));
      Put_P ("</td></tr>");
      Put_P ("<tr><td>Runtime</td><td>");
      Put_P (Img (Proof.Runtime_Checks));
      Put_P ("</td><td>");
      Put_P (Img (Proof.Runtime_Proved));
      Put_P ("</td></tr>");
      Put_P ("<tr><td>Assertions</td><td>");
      Put_P (Img (Proof.Assertions));
      Put_P ("</td><td>");
      Put_P (Img (Proof.Assert_Proved));
      Put_P ("</td></tr>");
      Put_P ("<tr><td>Functional</td><td>");
      Put_P (Img (Proof.Functional_Ct));
      Put_P ("</td><td>");
      Put_P (Img (Proof.Functional_Proved));
      Put_P ("</td></tr>");
      Put_P ("<tr><td>Total VCs</td><td>");
      Put_P (Img (Proof.Total_VCs));
      Put_P ("</td><td>");
      Put_P (Img (Proof.Proved_VCs));
      Put_P ("</td></tr></table></div>");

      --  Tests tab
      Put_T ("<div class=""card""><h2>Test Results</h2>");
      Put_T ("<table><tr><th>Category</th><th>Tests</th><th>Status</th></tr>");
      for C in 1 .. Integer (Tests.Categories.Length) loop
         Put_T ("<tr><td>");
         Put_T
           (Html_Escape
              (Tests.Categories (C).Category
                 (1 .. Tests.Categories (C).Cat_Len)));
         Put_T ("</td><td>");
         Put_T (Img (Tests.Categories (C).Test_Count));
         Put_T ("</td><td class=""");
         Put_T
           (if Tests.Categories (C).Status = Types.Pass
            then "pass"
            else "fail");
         Put_T (""">");
         Put_T (Types.To_String (Tests.Categories (C).Status));
         Put_T ("</td></tr>");
      end loop;
      Put_T ("<tr><td><strong>Total</strong></td><td><strong>");
      Put_T (Img (Tests.Total_Passed + Tests.Total_Failed));
      Put_T ("</strong></td><td><strong class=""");
      Put_T (if Tests.Total_Failed = 0 then "pass" else "fail");
      Put_T (""">Passed: ");
      Put_T (Img (Tests.Total_Passed));
      Put_T (", Failed: ");
      Put_T (Img (Tests.Total_Failed));
      Put_T ("</strong></td></tr></table></div>");

      --  Compliance tab
      Put_C ("<div class=""card"">");
      if All_Standards then
         Put_C ("<h2>Compliance (all standards)</h2>");
      else
         Put_C ("<h2>");
         Put_C (Types.To_String (DAL_Assess.Standard));
         Put_C (" Compliance</h2>");
      end if;
      Put_C ("<table><tr><th>Criterion</th><th>Status</th></tr>");
      if All_Standards then
         for Std in Types.Compliance_Standard loop
            Put_C ("<tr><td>");
            Put_C (Types.To_String (Std));
            Put_C (" level</td><td class=""");
            Put_C
              (if DAL_Assess.Status = Types.Achieved then "pass" else "fail");
            Put_C (""">");
            Put_C (Types.Standard_Level_Name (Std, DAL_Assess.Target_DAL));
            Put_C (" (");
            Put_C (Types.To_String (DAL_Assess.Status));
            Put_C (")</td></tr>");
         end loop;
      else
         Put_C ("<tr><td>Target level</td><td>");
         Put_C
           (Types.Standard_Level_Name
              (DAL_Assess.Standard, DAL_Assess.Target_DAL));
         Put_C ("</td></tr>");
         Put_C ("<tr><td>Overall Status</td><td class=""");
         Put_C (if DAL_Assess.Status = Types.Achieved then "pass" else "fail");
         Put_C (""">");
         Put_C (Types.To_String (DAL_Assess.Status));
         Put_C ("</td></tr>");
      end if;
      Put_C ("<tr><td>HLR Traced</td><td>");
      Put_C (Img (DAL_Assess.HLR_Found));
      Put_C (" / ");
      Put_C (Img (DAL_Assess.HLR_Total));
      Put_C ("</td></tr>");
      Put_C ("<tr><td>Orphan Tags</td><td>");
      Put_C (if DAL_Assess.Orphan_Tags then "Yes" else "No");
      Put_C ("</td></tr>");
      Put_C ("<tr><td>Tests Passing</td><td>");
      Put_C (if DAL_Assess.Tests_Passing then "Yes" else "No");
      Put_C ("</td></tr>");
      if not DAL_Assess.Failed_Reasons.Is_Empty then
         for R in 1 .. Integer (DAL_Assess.Failed_Reasons.Length) loop
            Put_C ("<tr><td>Failure</td><td class=""fail"">");
            Put_C (Html_Escape (DAL_Assess.Failed_Reasons (R)));
            Put_C ("</td></tr>");
         end loop;
      end if;
      Put_C ("</table></div>");

      --  HLR tab content reused in Compliance? Keep separate HLR panel for inclusion
      Put_H ("<div class=""card""><h2>HLR Traceability</h2>");
      Put_H ("<table><tr><th>Package</th><th>HLR Tags</th></tr>");
      declare
         Any_HLR : Boolean := False;
      begin
         for P in 1 .. Integer (Packages.Length) loop
            if not Packages (P).HLR_Tags.Is_Empty then
               Any_HLR := True;
               Put_H ("<tr><td>");
               Put_H
                 (Html_Escape
                    (Packages (P).Name (1 .. Packages (P).Name_Len)));
               Put_H ("</td><td>");
               for T in 1 .. Integer (Packages (P).HLR_Tags.Length) loop
                  if T > 1 then
                     Put_H (", ");
                  end if;
                  Put_H
                    (Html_Escape
                       (Packages (P).HLR_Tags (T).Tag
                          (1 .. Packages (P).HLR_Tags (T).Len)));
               end loop;
               Put_H ("</td></tr>");
            end if;
         end loop;
         if not Any_HLR then
            Put_H
              ("<tr><td colspan=""2"" style=""color:var(--muted)"">No HLR tags found</td></tr>");
         end if;
      end;
      Put_H ("</table></div>");

      --  Blend HLR into compliance tab as extra card
      Append (Compl, To_String (HLR_S));

      return
        Replace_All
          (Replace_All
             (Replace_All
                (Replace_All
                   (Replace_All
                      (Replace_All
                         (Replace_All
                            (Replace_All
                               (Adacovex.Dashboard_Template.Template,
                                "__OVERVIEW__",
                                To_String (Overview)),
                             "__PROOF__",
                             To_String (Proof_S)),
                          "__TESTS__",
                          To_String (Tests_S)),
                       "__COMPLIANCE__",
                       To_String (Compl)),
                    "__DEPS__",
                    Render_Deps_HTML (Graph)),
                 "__CHARTS__",
                 Render_Charts (Doc_Metrics, Proof, Tests, Graph)),
              "__GRAPH_JSON__",
              Render_Deps_JSON (Graph)),
           "__THEME__",
           Types.To_String (Theme));
   end Render_Dashboard_Internal;

   function Render_Dashboard
     (Doc_Metrics   : Types.Docstring_Metrics;
      Proof         : Types.Proof_Summary;
      Tests         : Types.Implementation.Test_Summary;
      DAL_Assess    : Types.Implementation.DAL_Assessment;
      Packages      : Types.Implementation.Package_Vectors.Vector;
      Graph         : Types.Implementation.Component_Vectors.Vector;
      All_Standards : Boolean := False;
      Theme         : Types.Dashboard_Theme := Types.System_Theme)
      return String is
   begin
      return
        Render_Dashboard_Internal
          (Doc_Metrics,
           Proof,
           Tests,
           DAL_Assess,
           Packages,
           Graph,
           All_Standards,
           Theme);
   end Render_Dashboard;

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
      Empty : Types.Implementation.Component_Vectors.Vector;
   begin
      return
        Render_Dashboard_Internal
          (Doc_Metrics,
           Proof,
           Tests,
           DAL_Assess,
           Packages,
           Empty,
           All_Standards,
           Theme);
   end Render_Dashboard;

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
      --  Per-category test metrics (name, count, PASS/FAIL status) -- the
      --  same data the dashboard Tests chart renders, exported for
      --  scripting and archiving.  Empty when the target has no category
      --  rows (e.g. TAP/Automake-only summaries).
      Put ("""test_categories"":[");
      declare
         First_Cat : Boolean := True;
      begin
         for C in 1 .. Integer (Tests.Categories.Length) loop
            declare
               Cat : Types.Test_Metrics renames Tests.Categories (C);
            begin
               if not First_Cat then
                  Put (",");
               end if;
               First_Cat := False;
               Put ("{""name"":""");
               Put (Cat.Category (1 .. Cat.Cat_Len));
               Put (""",""count"":");
               Put (Img (Cat.Test_Count));
               Put (",""status"":""");
               Put (Types.To_String (Cat.Status));
               Put ("""}");
            end;
         end loop;
      end;
      Put ("]");
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
