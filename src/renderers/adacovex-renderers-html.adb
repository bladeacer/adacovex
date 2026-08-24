with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Adacovex;
with Adacovex.Dashboard_Template;

package body Adacovex.Renderers.HTML is

   use Ada.Strings.Unbounded;
   use type Types.Test_Status;
   use type Types.DAL_Status;
   use type Types.Dashboard_Theme;
   use type Types.Component_Kind;
   use type Types.Component_Scope;

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

   --  0..1 fraction with two decimals ("0.42"), clamped at 1.00.  Charts.css
   --  pie/bar sizes are unitless turn fractions (--start/--end/--size), NOT
   --  0..100 percentages -- feeding Pct values here is what made old pie
   --  slices render as repeated full turns.
   function Frac (Part, Total : Natural) return String is
      P : Natural := 0;
   begin
      if Total = 0 then
         return "0.00";
      end if;
      P := (Part * 100) / Total;
      if P >= 100 then
         return "1.00";
      end if;
      if P < 10 then
         return "0.0" & Img (P);
      end if;
      return "0." & Img (P);
   end Frac;

   --  Signed integer without Ada's leading space (for SVG coordinates).
   function I_S (N : Integer) return String is
      S : constant String := Integer'Image (N);
   begin
      if S (S'First) = ' ' then
         return S (S'First + 1 .. S'Last);
      end if;
      return S;
   end I_S;

   --  "x,y" (SVG coordinates) of radar axis A (1..5, clockwise from the
   --  top) at Radius.  Centre is (110,100); the exact cos/sin*1000 values
   --  for angles 90/162/234/306/378 degrees keep the math in integers --
   --  no floating point in the renderer.
   Axis_Cos : constant array (1 .. 5) of Integer := (0, -951, -588, 588, 951);
   Axis_Sin : constant array (1 .. 5) of Integer :=
     (1000, 309, -809, -809, 309);

   function Radar_Point (A : Positive; Radius : Natural) return String is
      X : constant Integer := 110 + ((Integer (Radius) * Axis_Cos (A)) / 1000);
      Y : constant Integer := 100 - ((Integer (Radius) * Axis_Sin (A)) / 1000);
   begin
      return I_S (X) & "," & I_S (Y);
   end Radar_Point;

   --  "x,y x,y ..." point list for the five radar axes at Radius.
   function Radar_Points (Radius : Natural) return String is
      Buf : String (1 .. 128);
      BL  : Natural := 0;
   begin
      for A in 1 .. 5 loop
         if BL > 0 then
            BL := BL + 1;
            Buf (BL) := ' ';
         end if;
         declare
            XY : constant String := Radar_Point (A, Radius);
         begin
            for I in XY'Range loop
               if BL < Buf'Last then
                  BL := BL + 1;
                  Buf (BL) := XY (I);
               end if;
            end loop;
         end;
      end loop;
      return Buf (1 .. BL);
   end Radar_Points;

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

      --  A single pie/donut slice: label + start/end fraction strings.
      procedure Slice_Row
        (Label : String; Start_F, End_F : String; Value : Natural) is
      begin
         Put ("<tr><th scope=""row"">");
         Put (Label);
         Put ("</th><td style=""--start:");
         Put (Start_F);
         Put (";--end:");
         Put (End_F);
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
            Put ("0.00");
         else
            Put (Frac (Part, Total));
         end if;
         Put ("""><span class=""data"">");
         Put (Img (Value));
         Put ("</span></td></tr>");
      end Bar_Row;

   begin
      --  SPARK proof donut: proved vs unproved (not total) so the ring sums
      --  to one.  The hole is pure CSS (.charts-css.pie.donut::after).
      Put ("<div class=""chart-card""><h3>SPARK Proof</h3>");
      Put ("<table class=""charts-css pie donut show-labels"">");
      Put ("<caption>SPARK proof progress</caption><tbody>");
      if Proof.Total_VCs > 0 then
         declare
            U : constant Natural := Proof.Total_VCs - Proof.Proved_VCs;
            P : constant String := Frac (Proof.Proved_VCs, Proof.Total_VCs);
         begin
            Slice_Row ("Proved", "0.00", P, Proof.Proved_VCs);
            if U > 0 then
               Slice_Row ("Unproved", P, "1.00", U);
            end if;
         end;
      else
         Slice_Row ("No VCs", "0.00", "1.00", 0);
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

      --  Test categories bar (each category as its own row, normalised by max)
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

      --  Test pass/fail pie (start/end are 0..1 turn fractions)
      Put ("<div class=""chart-card""><h3>Tests Pass/Fail</h3>");
      Put ("<table class=""charts-css pie show-labels"">");
      Put ("<caption>Pass vs fail</caption><tbody>");
      declare
         Total_T : constant Natural := Tests.Total_Passed + Tests.Total_Failed;
      begin
         if Total_T = 0 then
            Slice_Row ("No tests", "0.00", "1.00", 0);
         else
            declare
               P : constant String := Frac (Tests.Total_Passed, Total_T);
            begin
               Slice_Row ("Passed", "0.00", P, Tests.Total_Passed);
               if Tests.Total_Failed > 0 then
                  Slice_Row ("Failed", P, "1.00", Tests.Total_Failed);
               end if;
            end;
         end if;
      end;
      Put
        ("</tbody></table></div>");      --  Docstring coverage: radial gauge (styled like the robustness and
      --  SPARK proof radars, compact for the Charts tab).
      declare
         Cov : constant Natural :=
           Pct
             (Doc_Metrics.Documented_Subprogs, Doc_Metrics.Total_Subprograms);
      begin
         Put ("<div class=""chart-card""><h3>Docstring Coverage</h3>");
         if Doc_Metrics.Total_Subprograms = 0 then
            Put ("<p style=""color:var(--muted);font-size:.85rem"">");
            Put ("No subprograms</p></div>");
         else
            Put ("<svg viewBox=""0 0 220 220"" width=""100%"" height=""160""");
            Put (" role=""img"" aria-label=""Docstring coverage"">");
            for G in 1 .. 4 loop
               Put ("<polygon points=""");
               Put (Radar_Points (20 * G));
               Put (""" fill=""none"" stroke=""var(--border)""");
               Put (" stroke-width=""1"" opacity="".55""/>");
            end loop;
            Put ("<path d=""M110,100 L");
            Put (Radar_Point (1, 80));
            Put (""" stroke=""var(--border)"" stroke-width=""1""/>");
            Put ("<polygon points=""");
            Put (Radar_Point (1, 4 + (Cov * 76) / 100));
            Put (""" fill=""var(--accent)"" fill-opacity=""0.25""");
            Put (" stroke=""var(--accent)"" stroke-width=""2""/>");
            Put ("<circle transform=""translate(");
            Put (Radar_Point (1, 4 + (Cov * 76) / 100));
            Put (")"" r=""2.5"" fill=""var(--accent)""/>");
            Put ("<text transform=""translate(");
            Put (Radar_Point (1, 95));
            Put (")"" text-anchor=""middle"" dy=""-5""");
            Put (" font-size=""8.5"" fill=""var(--muted)"">");
            Put ("Coverage");
            Put ("</text>");
            Put ("<text x=""110"" y=""96"" text-anchor=""middle""");
            Put
              (" font-size=""28"" font-weight=""700"" fill=""var(--accent)"">");
            Put (Img (Cov));
            Put ("%</text>");
            Put ("<text x=""110"" y=""112"" text-anchor=""middle""");
            Put (" font-size=""8"" fill=""var(--muted)"">");
            Put ("documented</text>");
            Put ("</svg>");
            Put ("<p style=""color:var(--muted);font-size:.75rem;");
            Put ("text-align:center;margin:4px 0 0"">");
            Put (Img (Doc_Metrics.Documented_Subprogs));
            Put (" / ");
            Put (Img (Doc_Metrics.Total_Subprograms));
            Put (" documented</p></div>");
         end if;
      end;

      --  Dependency scope polar ring (conic gradient + CSS hole; the four
      --  cut points are cumulative percentages, theme colours via variables).
      --  Now with a centre rating badge and improved legend layout.
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
               S1    : constant Natural := Pct (Base_Ct, Total);
               S2    : constant Natural := Pct (Base_Ct + Dev_Ct, Total);
               S3    : constant Natural :=
                 Pct (Base_Ct + Dev_Ct + Trans_Ct, Total);
            begin
               if Total > 0 then
                  Put
                    ("<div class=""chart-card""><h3>Dependencies by Scope</h3>");
                  Put ("<div class=""polar-wrap"">");
                  Put ("<div class=""polar"" role=""img"" aria-label=""");
                  Put ("Dependency scope distribution"" style=""background:");
                  Put ("conic-gradient(var(--scope-base) 0% ");
                  Put (Img (S1));
                  Put ("%, var(--scope-dev) ");
                  Put (Img (S1));
                  Put ("% ");
                  Put (Img (S2));
                  Put ("%, var(--scope-trans) ");
                  Put (Img (S2));
                  Put ("% ");
                  Put (Img (S3));
                  Put ("%, var(--scope-vend) ");
                  Put (Img (S3));
                  Put ("% 100%)"">");
                  --  Centre hole with total count
                  Put ("<div class=""polar-center"">");
                  Put ("<div class=""polar-rating"">");
                  Put (Img (Total));
                  Put ("</div>");
                  Put ("<div class=""polar-label"">deps</div>");
                  Put ("</div></div>");
                  Put ("<ul class=""polar-legend"">");
                  if Base_Ct > 0 then
                     Put ("<li style=""--i:var(--scope-base)""><i></i>base");
                     Put ("<b>");
                     Put (Img (Base_Ct));
                     Put ("</b></li>");
                  end if;
                  if Dev_Ct > 0 then
                     Put ("<li style=""--i:var(--scope-dev)""><i></i>dev");
                     Put ("<b>");
                     Put (Img (Dev_Ct));
                     Put ("</b></li>");
                  end if;
                  if Trans_Ct > 0 then
                     Put
                       ("<li style=""--i:var(--scope-trans)""><i></i>transitive");
                     Put ("<b>");
                     Put (Img (Trans_Ct));
                     Put ("</b></li>");
                  end if;
                  if Vend_Ct > 0 then
                     Put
                       ("<li style=""--i:var(--scope-vend)""><i></i>vendored");
                     Put ("<b>");
                     Put (Img (Vend_Ct));
                     Put ("</b></li>");
                  end if;
                  Put ("</ul></div></div>");
               end if;
            end;
         end;
      end if;

      --  Stacked bar chart for dependency scopes (pure CSS, raw numbers)
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
               Pct_B : Natural := 0;
               Pct_D : Natural := 0;
               Pct_T : Natural := 0;
               Pct_V : Natural := 0;
            begin
               if Total > 0 then
                  Pct_B := (Base_Ct * 100) / Total;
                  Pct_D := (Dev_Ct * 100) / Total;
                  Pct_T := (Trans_Ct * 100) / Total;
                  Pct_V := 100 - Pct_B - Pct_D - Pct_T;
                  Put ("<div class=""chart-card""><h3>Scope Breakdown</h3>");
                  Put ("<div class=""stacked-bar"" role=""img""");
                  Put (" aria-label=""Dependency scope breakdown"">");
                  if Pct_B > 0 then
                     Put ("<i style=""width:");
                     Put (Img (Pct_B));
                     Put ("%;background:var(--scope-base)""></i>");
                  end if;
                  if Pct_D > 0 then
                     Put ("<i style=""width:");
                     Put (Img (Pct_D));
                     Put ("%;background:var(--scope-dev)""></i>");
                  end if;
                  if Pct_T > 0 then
                     Put ("<i style=""width:");
                     Put (Img (Pct_T));
                     Put ("%;background:var(--scope-trans)""></i>");
                  end if;
                  if Pct_V > 0 then
                     Put ("<i style=""width:");
                     Put (Img (Pct_V));
                     Put ("%;background:var(--scope-vend)""></i>");
                  end if;
                  Put ("</div>");
                  Put ("<ul class=""scope-legend"" style=""margin-top:8px"">");
                  Put ("<li><i class=""s-base""></i>base <b>");
                  Put (Img (Base_Ct));
                  Put (" (");
                  Put (Img (Pct_B));
                  Put ("%)</b></li>");
                  Put ("<li><i class=""s-dev""></i>dev <b>");
                  Put (Img (Dev_Ct));
                  Put (" (");
                  Put (Img (Pct_D));
                  Put ("%)</b></li>");
                  Put ("<li><i class=""s-trans""></i>transitive <b>");
                  Put (Img (Trans_Ct));
                  Put (" (");
                  Put (Img (Pct_T));
                  Put ("%)</b></li>");
                  Put ("<li><i class=""s-vend""></i>vendored <b>");
                  Put (Img (Vend_Ct));
                  Put (" (");
                  Put (Img (Pct_V));
                  Put ("%)</b></li>");
                  Put ("</ul></div>");
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
           ("<button type=""button"" class=""dep-link"" "
            & "onclick=""showDepDetails(");
         Put (Img (Idx));
         Put (");return false;"" title=""Click for details"">");
         Put (Html_Escape (Info.Name (1 .. Info.Name_Len)));
         Put ("</button> ");
         if Info.Version_Len > 0 then
            Put
              ("<span class=""dep-badge"">"
               & Html_Escape (Info.Version (1 .. Info.Version_Len))
               & "</span> ");
         end if;
         Put
           ("<span class=""dep-badge "
            & Scope_Class (Info.Scope)
            & """>"
            & Scope_Name (Info.Scope)
            & "</span> ");
         if Info.Kind = Types.Root_Component then
            Put ("<span class=""dep-badge"">root</span> ");
         end if;
         if Child_Count (Idx) > 0 then
            Put
              ("<span class=""dep-badge"">"
               & Img (Child_Count (Idx))
               & " deps</span> ");
         end if;
         if Info.License_Len > 0 then
            Put
              ("<span class=""dep-meta lic"">"
               & Html_Escape (Info.License (1 .. Info.License_Len))
               & "</span> ");
         end if;
         if Info.PURL_Len > 0 then
            Put
              ("<span class=""dep-meta purl"" title=""PURL"">"
               & Html_Escape (Info.PURL (1 .. Info.PURL_Len))
               & "</span> ");
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
      --  Mini summarizer at top: scope distribution bar (pure CSS, no JS)
      declare
         C_Base  : Natural := 0;
         C_Dev   : Natural := 0;
         C_Trans : Natural := 0;
         C_Vend  : Natural := 0;
         Total   : Natural := 0;
         Pct_B   : Natural := 0;
         Pct_D   : Natural := 0;
         Pct_T   : Natural := 0;
         Pct_V   : Natural := 0;
      begin
         for I in 1 .. Integer (Graph.Length) loop
            case Graph (I).Scope is
               when Types.Scope_Base       =>
                  C_Base := C_Base + 1;

               when Types.Scope_Dev        =>
                  C_Dev := C_Dev + 1;

               when Types.Scope_Transitive =>
                  C_Trans := C_Trans + 1;

               when Types.Scope_Vendored   =>
                  C_Vend := C_Vend + 1;
            end case;
            Total := Total + 1;
         end loop;
         if Total > 0 then
            Pct_B := (C_Base * 100) / Total;
            Pct_D := (C_Dev * 100) / Total;
            Pct_T := (C_Trans * 100) / Total;
            Pct_V := 100 - Pct_B - Pct_D - Pct_T;
         end if;
         Put
           ("<div class=""chart-card"" style=""margin:0 0 14px;max-width:640px"">");
         Put ("<h3>Scope Distribution</h3>");
         Put
           ("<div class=""scope-stack"" role=""img"" "
            & "aria-label=""Scope distribution"">");
         if Pct_B > 0 then
            Put
              ("<i class=""s-base"" style=""width:"
               & Img (Pct_B)
               & "%""></i>");
         end if;
         if Pct_D > 0 then
            Put
              ("<i class=""s-dev"" style=""width:" & Img (Pct_D) & "%""></i>");
         end if;
         if Pct_T > 0 then
            Put
              ("<i class=""s-trans"" style=""width:"
               & Img (Pct_T)
               & "%""></i>");
         end if;
         if Pct_V > 0 then
            Put
              ("<i class=""s-vend"" style=""width:"
               & Img (Pct_V)
               & "%""></i>");
         end if;
         Put ("</div>");
         Put ("<ul class=""scope-legend scope-legend-prominent"">");
         Put ("<li><i class=""s-base""></i>base <b>");
         Put (Img (C_Base));
         Put ("</b></li><li><i class=""s-dev""></i>dev <b>");
         Put (Img (C_Dev));
         Put ("</b></li><li><i class=""s-trans""></i>transitive <b>");
         Put (Img (C_Trans));
         Put ("</b></li><li><i class=""s-vend""></i>vendored <b>");
         Put (Img (C_Vend));
         Put ("</b></li></ul>");
         Put ("</div>");
      end;
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
        ("<label class=""cb"" title=""base = declared in alire.toml"">"
         & "<input type=""checkbox"" id=""filter-base"" checked "
         & "onchange=""filterByScope()""><span class=""box"">"
         & "<svg class=""tick"" viewBox=""0 0 12 12"" width=""11"" height=""11"" aria-hidden=""true"">"
         & "<path d=""M2 6 L5 9 L10 3"" stroke=""currentColor"" fill=""none"" "
         & "stroke-width=""2"" stroke-linecap=""round"" stroke-linejoin=""round""/>"
         & "</svg></span> "
         & "<svg class=""icon"" viewBox=""0 0 12 12"" width=""10"" height=""10"" aria-hidden=""true"">"
         & "<use href=""#i-base""/></svg> base</label>");
      Put
        ("<label class=""cb"" title=""dev = declared in alire-dev.toml"">"
         & "<input type=""checkbox"" id=""filter-dev"" checked "
         & "onchange=""filterByScope()""><span class=""box"">"
         & "<svg class=""tick"" viewBox=""0 0 12 12"" width=""11"" height=""11"" aria-hidden=""true"">"
         & "<path d=""M2 6 L5 9 L10 3"" stroke=""currentColor"" fill=""none"" "
         & "stroke-width=""2"" stroke-linecap=""round"" stroke-linejoin=""round""/>"
         & "</svg></span> "
         & "<svg class=""icon"" viewBox=""0 0 12 12"" width=""10"" height=""10"" aria-hidden=""true"">"
         & "<use href=""#i-dev""/></svg> dev</label>");
      Put
        ("<label class=""cb"" title=""transitive = pulled in by a dependency"">"
         & "<input type=""checkbox"" id=""filter-transitive"" checked "
         & "onchange=""filterByScope()""><span class=""box"">"
         & "<svg class=""tick"" viewBox=""0 0 12 12"" width=""11"" height=""11"" aria-hidden=""true"">"
         & "<path d=""M2 6 L5 9 L10 3"" stroke=""currentColor"" fill=""none"" "
         & "stroke-width=""2"" stroke-linecap=""round"" stroke-linejoin=""round""/>"
         & "</svg></span> "
         & "<svg class=""icon"" viewBox=""0 0 12 12"" width=""10"" height=""10"" aria-hidden=""true"">"
         & "<use href=""#i-trans""/></svg> transitive</label>");
      Put
        ("<label class=""cb"" title=""vendored = bundled third-party source"">"
         & "<input type=""checkbox"" id=""filter-vendored"" checked "
         & "onchange=""filterByScope()""><span class=""box"">"
         & "<svg class=""tick"" viewBox=""0 0 12 12"" width=""11"" height=""11"" aria-hidden=""true"">"
         & "<path d=""M2 6 L5 9 L10 3"" stroke=""currentColor"" fill=""none"" "
         & "stroke-width=""2"" stroke-linecap=""round"" stroke-linejoin=""round""/>"
         & "</svg></span> "
         & "<svg class=""icon"" viewBox=""0 0 12 12"" width=""10"" height=""10"" aria-hidden=""true"">"
         & "<use href=""#i-vend""/></svg> vendored</label>");
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
      --  Dep details panel (populated by JS on click)
      Put ("<div class=""dep-details"" id=""dep-detail-popup"" hidden"">");
      Put ("</div>");
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

      --  Overview collation charts: robustness radar with a tier rating,
      --  per-check-type SPARK radar (moved from the Charts tab), tests
      --  donut and the doc-coverage gauge
      declare
         procedure Mini_Slice (Lbl : String; St_F, Fi_F : String; V : Natural)
         is
         begin
            Put_O ("<tr><th scope=""row"">");
            Put_O (Html_Escape (Lbl));
            Put_O ("</th><td style=""--start:");
            Put_O (St_F);
            Put_O (";--end:");
            Put_O (Fi_F);
            Put_O ("""><span class=""data"">");
            Put_O (Img (V));
            Put_O ("</span></td></tr>");
         end Mini_Slice;
      begin
         Put_O ("<div class=""chart-grid"" style=""margin-top:14px"">");

         --  Robustness radar: five quality axes (each 0..100) plus a tier
         --  rating derived from their average.  Split layout: chart on the
         --  left, rating meanings and per-axis results on the right.  The
         --  tier badge renders inside the chart centre.
         declare
            R_Vals  : array (1 .. 5) of Natural := (others => 0);
            R_Name  : constant array (1 .. 5) of String (1 .. 8) :=
              ("Docs    ", "Proof   ", "Tests   ", "Comp    ", "Deps    ");
            R_Len   : constant array (1 .. 5) of Natural := (4, 5, 5, 4, 4);
            Vend_Ct : Natural := 0;
            Avg     : Natural := 0;
            Tier    : Character := 'D';
         begin
            R_Vals (1) := Doc_Metrics.Coverage_Pct;
            R_Vals (2) := Pct (Proof.Proved_VCs, Proof.Total_VCs);
            R_Vals (3) :=
              Pct
                (Tests.Total_Passed, Tests.Total_Passed + Tests.Total_Failed);
            R_Vals (4) :=
              (if DAL_Assess.Status = Types.Achieved then 100 else 0);
            for I in 1 .. Integer (Graph.Length) loop
               if Graph (I).Scope = Types.Scope_Vendored then
                  Vend_Ct := Vend_Ct + 1;
               end if;
            end loop;
            R_Vals (5) :=
              Pct (Natural (Graph.Length) - Vend_Ct, Natural (Graph.Length));
            Avg :=
              (R_Vals (1) + R_Vals (2) + R_Vals (3) + R_Vals (4) + R_Vals (5))
              / 5;
            if Avg >= 90 then
               Tier := 'S';
            elsif Avg >= 80 then
               Tier := 'A';
            elsif Avg >= 65 then
               Tier := 'B';
            elsif Avg >= 50 then
               Tier := 'C';
            end if;

            Put_O ("<div class=""chart-card""><h3>Robustness</h3>");
            Put_O ("<div class=""radar-split"">");
            Put_O ("<div class=""radar-chart"">");
            Put_O
              ("<svg viewBox=""0 0 220 220"" width=""100%"" height=""200""");
            Put_O
              (" role=""img"" aria-label=""Robustness radar with tier rating"">");
            for G in 1 .. 4 loop
               Put_O ("<polygon points=""");
               Put_O (Radar_Points (20 * G));
               Put_O (""" fill=""none"" stroke=""var(--border)""");
               Put_O (" stroke-width=""1"" opacity="".55""/>");
            end loop;
            for K in 1 .. 5 loop
               Put_O ("<path d=""M110,100 L");
               Put_O (Radar_Point (K, 80));
               Put_O (""" stroke=""var(--border)"" stroke-width=""1""/>");
            end loop;
            Put_O ("<polygon points=""");
            for K in 1 .. 5 loop
               if K > 1 then
                  Put_O (" ");
               end if;
               Put_O (Radar_Point (K, 4 + (R_Vals (K) * 76) / 100));
            end loop;
            Put_O (""" fill=""var(--accent)"" fill-opacity=""0.25""");
            Put_O (" stroke=""var(--accent)"" stroke-width=""2""/>");
            for K in 1 .. 5 loop
               Put_O ("<circle transform=""translate(");
               Put_O (Radar_Point (K, 4 + (R_Vals (K) * 76) / 100));
               Put_O (")"" r=""2.5"" fill=""var(--accent)""/>");
            end loop;
            for K in 1 .. 5 loop
               Put_O ("<text transform=""translate(");
               Put_O (Radar_Point (K, 98));
               Put_O (")"" text-anchor=""");
               if K = 1 then
                  Put_O ("middle"" dy=""-5""");
               elsif K <= 3 then
                  Put_O ("end"" dy=""3""");
               else
                  Put_O ("start"" dy=""3""");
               end if;
               Put_O (" font-size=""8.5"" fill=""var(--muted)"">");
               Put_O (R_Name (K) (1 .. R_Len (K)));
               Put_O ("</text>");
            end loop;
            --  Tier badge inside the chart centre
            Put_O ("<text x=""110"" y=""96"" text-anchor=""middle""");
            Put_O
              (" font-size=""28"" font-weight=""700"" fill=""var(--accent)"">");
            Put_O (Tier & "</text>");
            Put_O ("<text x=""110"" y=""112"" text-anchor=""middle""");
            Put_O (" font-size=""8"" fill=""var(--muted)"">TIER</text>");
            Put_O ("</svg>");
            Put_O ("</div>");
            Put_O ("<div class=""radar-legend"">");
            Put_O ("<div class=""tier-wrap"">");
            Put_O ("<span class=""tier tier-" & Tier & """>" & Tier);
            Put_O ("</span><span class=""tier-note"">Avg ");
            Put_O (Img (Avg));
            Put_O ("% &middot; S&ge;90 A&ge;80 B&ge;65 C&ge;50 D&lt;50");
            Put_O ("</span></div>");
            Put_O ("<ul>");
            for K in 1 .. 5 loop
               Put_O ("<li><i></i>");
               Put_O (R_Name (K) (1 .. R_Len (K)));
               Put_O (" <b>");
               Put_O (Img (R_Vals (K)));
               Put_O ("%</b></li>");
            end loop;
            Put_O ("</ul></div>");
            Put_O ("</div></div>");
         end;

         --  SPARK proof per check category (radar moved from the Charts
         --  tab: it reads at a glance on the Overview).  Styled like the
         --  Robustness radar: proof rate per category (0..100), tier badge
         --  in the centre, and a split legend on the right.
         declare
            type Cat_Rec is record
               Name : String (1 .. 8);
               Len  : Natural;
            end record;
            Cats  : constant array (1 .. 5) of Cat_Rec :=
              (("Flow    ", 4),
               ("Init    ", 4),
               ("Runtime ", 7),
               ("Assert  ", 6),
               ("Func    ", 4));
            Rates : constant array (1 .. 5) of Natural :=
              ((if Proof.Flow_Checks > 0
                then (Proof.Flow_Proved * 100) / Proof.Flow_Checks
                else 0),
               (if Proof.Init_Checks > 0
                then (Proof.Init_Proved * 100) / Proof.Init_Checks
                else 0),
               (if Proof.Runtime_Checks > 0
                then (Proof.Runtime_Proved * 100) / Proof.Runtime_Checks
                else 0),
               (if Proof.Assertions > 0
                then (Proof.Assert_Proved * 100) / Proof.Assertions
                else 0),
               (if Proof.Functional_Ct > 0
                then (Proof.Functional_Proved * 100) / Proof.Functional_Ct
                else 0));
            Avg   : Natural := 0;
            Tier  : Character := 'D';
         begin
            for K in 1 .. 5 loop
               Avg := Avg + Rates (K);
            end loop;
            Avg := Avg / 5;
            if Avg >= 90 then
               Tier := 'S';
            elsif Avg >= 80 then
               Tier := 'A';
            elsif Avg >= 65 then
               Tier := 'B';
            elsif Avg >= 50 then
               Tier := 'C';
            end if;

            Put_O ("<div class=""chart-card""><h3>SPARK Proof</h3>");
            Put_O ("<div class=""radar-split"">");
            Put_O ("<div class=""radar-chart"">");
            if Rates (1) + Rates (2) + Rates (3) + Rates (4) + Rates (5) = 0
            then
               Put_O ("<p style=""color:var(--muted);font-size:.85rem"">");
               Put_O ("No proof data</p>");
            else
               Put_O
                 ("<svg viewBox=""0 0 220 220"" width=""100%"" height=""200""");
               Put_O
                 (" role=""img"" aria-label=""SPARK proof by check type"">");
               for G in 1 .. 4 loop
                  Put_O ("<polygon points=""");
                  Put_O (Radar_Points (20 * G));
                  Put_O (""" fill=""none"" stroke=""var(--border)""");
                  Put_O (" stroke-width=""1"" opacity="".55""/>");
               end loop;
               for A in 1 .. 5 loop
                  Put_O ("<path d=""M110,100 L");
                  Put_O (Radar_Point (A, 80));
                  Put_O (""" stroke=""var(--border)"" stroke-width=""1""/>");
               end loop;
               Put_O ("<polygon points=""");
               for K in 1 .. 5 loop
                  if K > 1 then
                     Put_O (" ");
                  end if;
                  Put_O (Radar_Point (K, 4 + (Rates (K) * 76) / 100));
               end loop;
               Put_O (""" fill=""var(--accent)"" fill-opacity=""0.25""");
               Put_O (" stroke=""var(--accent)"" stroke-width=""2""/>");
               for K in 1 .. 5 loop
                  Put_O ("<circle transform=""translate(");
                  Put_O (Radar_Point (K, 4 + (Rates (K) * 76) / 100));
                  Put_O (")"" r=""2.5"" fill=""var(--accent)""/>");
               end loop;
               for A in 1 .. 5 loop
                  Put_O ("<text transform=""translate(");
                  Put_O (Radar_Point (A, 95));
                  Put_O (")"" text-anchor=""");
                  if A = 1 then
                     Put_O ("middle"" dy=""-5""");
                  elsif A <= 3 then
                     Put_O ("end"" dy=""3""");
                  else
                     Put_O ("start"" dy=""3""");
                  end if;
                  Put_O (" font-size=""8.5"" fill=""var(--muted)"">");
                  Put_O (Cats (A).Name (1 .. Cats (A).Len));
                  Put_O ("</text>");
               end loop;
               --  Tier badge inside the chart centre
               Put_O ("<text x=""110"" y=""96"" text-anchor=""middle""");
               Put_O
                 (" font-size=""28"" font-weight=""700"" fill=""var(--accent)"">");
               Put_O (Tier & "</text>");
               Put_O ("<text x=""110"" y=""112"" text-anchor=""middle""");
               Put_O (" font-size=""8"" fill=""var(--muted)"">TIER</text>");
               Put_O ("</svg>");
            end if;
            Put_O ("</div>");
            Put_O ("<div class=""radar-legend"">");
            Put_O ("<div class=""tier-wrap"">");
            Put_O ("<span class=""tier tier-" & Tier & """>" & Tier);
            Put_O ("</span><span class=""tier-note"">Avg ");
            Put_O (Img (Avg));
            Put_O ("% &middot; S&ge;90 A&ge;80 B&ge;65 C&ge;50 D&lt;50");
            Put_O ("</span></div>");
            Put_O ("<ul>");
            for K in 1 .. 5 loop
               Put_O ("<li><i></i>");
               Put_O (Cats (K).Name (1 .. Cats (K).Len));
               Put_O (" <b>");
               Put_O (Img (Rates (K)));
               Put_O ("%</b></li>");
            end loop;
            Put_O ("</ul></div>");
            Put_O ("</div></div>");
         end;

         --  Tests donut + category column chart side by side
         Put_O ("<div class=""chart-card""><h3>Tests</h3>");
         Put_O
           ("<table class=""charts-css pie donut show-labels"" style=""height:150px;max-width:200px;margin:0 auto"">");
         Put_O ("<caption>Tests</caption><tbody>");
         declare
            Tot : constant Natural := Tests.Total_Passed + Tests.Total_Failed;
         begin
            if Tot = 0 then
               Mini_Slice ("No tests", "0.00", "1.00", 0);
            else
               declare
                  P : constant String := Frac (Tests.Total_Passed, Tot);
               begin
                  Mini_Slice ("Passed", "0.00", P, Tests.Total_Passed);
                  if Tests.Total_Failed > 0 then
                     Mini_Slice ("Failed", P, "1.00", Tests.Total_Failed);
                  end if;
               end;
            end if;
         end;
         Put_O ("</tbody></table></div>");

         --  Test category column chart (visualise per-category counts)
         Put_O ("<div class=""chart-card""><h3>Test Categories</h3>");
         if Tests.Categories.Is_Empty then
            Put_O ("<p style=""color:var(--muted);font-size:.85rem"">");
            Put_O ("No test categories</p>");
         else
            Put_O
              ("<table class=""charts-css column show-labels show-primary-axis"">");
            Put_O ("<caption>Tests by category</caption><tbody>");
            for C in 1 .. Integer (Tests.Categories.Length) loop
               declare
                  Cat : Types.Test_Metrics renames Tests.Categories (C);
                  Pct : constant String :=
                    (if Cat.Test_Count > 0
                     then Frac (Cat.Test_Count, Cat.Test_Count)
                     else "0.00");
               begin
                  Put_O ("<tr><th scope=""row"">");
                  Put_O (Html_Escape (Cat.Category (1 .. Cat.Cat_Len)));
                  Put_O ("</th><td style=""--size:");
                  Put_O (Pct);
                  Put_O ("""><span class=""data"">");
                  Put_O (Img (Cat.Test_Count));
                  Put_O ("</span></td></tr>");
               end;
            end loop;
            Put_O ("</tbody></table>");
         end if;
         Put_O ("</div>");

         --  Doc coverage: radial chart (1 axis, 0..100, styled like the
         --  robustness and SPARK proof radars).
         Put_O ("<div class=""chart-card""><h3>Doc Coverage</h3>");
         declare
            Cov : constant Natural :=
              Pct
                (Doc_Metrics.Documented_Subprogs,
                 Doc_Metrics.Total_Subprograms);
         begin
            if Doc_Metrics.Total_Subprograms = 0 then
               Put_O ("<p style=""color:var(--muted);font-size:.85rem"">");
               Put_O ("No subprograms</p></div>");
            else
               Put_O ("<div class=""radar-split"">");
               Put_O ("<div class=""radar-chart"">");
               Put_O
                 ("<svg viewBox=""0 0 220 220"" width=""100%"" height=""200""");
               Put_O (" role=""img"" aria-label=""Docstring coverage"">");
               for G in 1 .. 4 loop
                  Put_O ("<polygon points=""");
                  Put_O (Radar_Points (20 * G));
                  Put_O (""" fill=""none"" stroke=""var(--border)""");
                  Put_O (" stroke-width=""1"" opacity="".55""/>");
               end loop;
               Put_O ("<path d=""M110,100 L");
               Put_O (Radar_Point (1, 80));
               Put_O (""" stroke=""var(--border)"" stroke-width=""1""/>");
               Put_O ("<polygon points=""");
               Put_O (Radar_Point (1, 4 + (Cov * 76) / 100));
               Put_O (""" fill=""var(--accent)"" fill-opacity=""0.25""");
               Put_O (" stroke=""var(--accent)"" stroke-width=""2""/>");
               Put_O ("<circle transform=""translate(");
               Put_O (Radar_Point (1, 4 + (Cov * 76) / 100));
               Put_O (")"" r=""2.5"" fill=""var(--accent)""/>");
               Put_O ("<text transform=""translate(");
               Put_O (Radar_Point (1, 95));
               Put_O (")"" text-anchor=""middle"" dy=""-5""");
               Put_O (" font-size=""8.5"" fill=""var(--muted)"">");
               Put_O ("Coverage");
               Put_O ("</text>");
               Put_O ("<text x=""110"" y=""96"" text-anchor=""middle""");
               Put_O
                 (" font-size=""28"" font-weight=""700"" fill=""var(--accent)"">");
               Put_O (Img (Cov));
               Put_O ("%</text>");
               Put_O ("<text x=""110"" y=""112"" text-anchor=""middle""");
               Put_O (" font-size=""8"" fill=""var(--muted)"">");
               Put_O ("documented</text>");
               Put_O ("</svg>");
               Put_O ("</div>");
               Put_O ("<div class=""radar-legend"">");
               Put_O ("<ul>");
               Put_O ("<li><i></i>Coverage <b>");
               Put_O (Img (Cov));
               Put_O ("%</b></li>");
               Put_O ("<li><i></i>Total <b>");
               Put_O (Img (Doc_Metrics.Total_Subprograms));
               Put_O ("</b></li>");
               Put_O ("<li><i></i>Documented <b>");
               Put_O (Img (Doc_Metrics.Documented_Subprogs));
               Put_O ("</b></li>");
               Put_O ("</ul></div>");
               Put_O ("</div></div>");
            end if;
         end;
         Put_O ("</div>");
         Put_O ("</div>");
      end;

      --  Proof tab: mini compliance-style gauge at the top
      Put_P ("<div class=""chart-grid"" style=""margin-bottom:14px"">");
      Put_P ("<div class=""chart-card""><h3>Proof Achievement</h3>");
      declare
         Proof_Pct : Natural := 0;
      begin
         if Proof.Total_VCs > 0 then
            Proof_Pct := (Proof.Proved_VCs * 100) / Proof.Total_VCs;
         end if;
         Put_P ("<div class=""compliance-gauge-wrap"">");
         Put_P ("<div class=""gauge-chart"">");
         Put_P ("<svg viewBox=""0 0 120 68"" width=""100%"" height=""66""");
         Put_P (" role=""img"" aria-label=""Proof achievement"">");
         Put_P ("<path d=""M10 60 A50 50 0 0 1 110 60"" fill=""none""");
         Put_P (" stroke=""var(--border)"" stroke-width=""11""");
         Put_P (" stroke-linecap=""round""/>");
         Put_P ("<path d=""M10 60 A50 50 0 0 1 110 60"" fill=""none""");
         Put_P (" stroke=""var(--accent)"" stroke-width=""11""");
         Put_P (" stroke-linecap=""round"" stroke-dasharray=""157""");
         Put_P (" stroke-dashoffset=""");
         Put_P (Img (157 - (157 * Proof_Pct) / 100));
         Put_P ("""/>");
         Put_P ("<text x=""60"" y=""56"" text-anchor=""middle""");
         Put_P (" font-size=""11"" font-weight=""600""");
         Put_P (" fill=""var(--accent)"">");
         Put_P (Img (Proof_Pct));
         Put_P ("%</text></svg>");
         Put_P ("</div>");
         Put_P ("<div class=""gauge-info"">");
         Put_P ("<div class=""gauge-achieved"">");
         Put_P (Img (Proof.Proved_VCs));
         Put_P (" / ");
         Put_P (Img (Proof.Total_VCs));
         Put_P (" VCs</div>");
         Put_P ("<div style=""font-size:.82rem;color:var(--muted)"">");
         Put_P (Types.To_String (Proof.Level));
         Put_P ("</div>");
         Put_P ("</div></div></div>");
      end;
      Put_P ("</div>");
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

      --  Tests tab: mini compliance-style gauge at the top
      Put_T ("<div class=""chart-grid"" style=""margin-bottom:14px"">");
      Put_T ("<div class=""chart-card""><h3>Test Pass Rate</h3>");
      declare
         Pass_Pct : Natural := 0;
      begin
         if Tests.Total_Passed + Tests.Total_Failed > 0 then
            Pass_Pct :=
              (Tests.Total_Passed * 100)
              / (Tests.Total_Passed + Tests.Total_Failed);
         end if;
         Put_T ("<div class=""compliance-gauge-wrap"">");
         Put_T ("<div class=""gauge-chart"">");
         Put_T ("<svg viewBox=""0 0 120 68"" width=""100%"" height=""66""");
         Put_T (" role=""img"" aria-label=""Test pass rate"">");
         Put_T ("<path d=""M10 60 A50 50 0 0 1 110 60"" fill=""none""");
         Put_T (" stroke=""var(--border)"" stroke-width=""11""");
         Put_T (" stroke-linecap=""round""/>");
         Put_T ("<path d=""M10 60 A50 50 0 0 1 110 60"" fill=""none""");
         Put_T (" stroke=""var(--pass)"" stroke-width=""11""");
         Put_T (" stroke-linecap=""round"" stroke-dasharray=""157""");
         Put_T (" stroke-dashoffset=""");
         Put_T (Img (157 - (157 * Pass_Pct) / 100));
         Put_T ("""/>");
         Put_T ("<text x=""60"" y=""56"" text-anchor=""middle""");
         Put_T (" font-size=""11"" font-weight=""600""");
         Put_T (" fill=""var(--pass)"">");
         Put_T (Img (Pass_Pct));
         Put_T ("%</text></svg>");
         Put_T ("</div>");
         Put_T ("<div class=""gauge-info"">");
         Put_T ("<div class=""gauge-achieved"">");
         Put_T (Img (Tests.Total_Passed));
         Put_T (" passed</div>");
         Put_T ("<div style=""font-size:.82rem;color:var(--muted)"">");
         Put_T (Img (Tests.Total_Failed));
         Put_T (" failed</div>");
         Put_T ("</div></div></div>");
      end;
      Put_T ("</div>");
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

      --  Compliance tab: achievement gauge with target + percent achieved
      declare
         --  Compliance percentage: weighted score across HLR traceability,
         --  tests passing, SPARK level met, and subprogram coverage.
         HLR_Pct   : Natural := 0;
         Test_Pct  : Natural := 0;
         SPARK_Pct : Natural := 0;
         Compl_Pct : Natural := 0;
      begin
         if DAL_Assess.HLR_Total > 0 then
            HLR_Pct := (DAL_Assess.HLR_Found * 100) / DAL_Assess.HLR_Total;
         else
            HLR_Pct := 100;
         end if;
         if Tests.Total_Passed + Tests.Total_Failed > 0 then
            Test_Pct :=
              (Tests.Total_Passed * 100)
              / (Tests.Total_Passed + Tests.Total_Failed);
         else
            Test_Pct := 0;
         end if;
         SPARK_Pct := (if DAL_Assess.Min_SPARK_Level_Met then 100 else 0);
         Compl_Pct := (HLR_Pct + Test_Pct + SPARK_Pct) / 3;

         Put_C
           ("<div class=""chart-card"" style=""margin-bottom:14px;max-width:400px"">");
         Put_C ("<h3>Compliance Status</h3>");
         Put_C ("<div class=""compliance-gauge-wrap"">");
         Put_C ("<div class=""gauge-chart"">");
         Put_C ("<svg viewBox=""0 0 120 68"" width=""100%"" height=""66""");
         Put_C (" role=""img"" aria-label=""Compliance achievement"">");
         Put_C ("<path d=""M10 60 A50 50 0 0 1 110 60"" fill=""none""");
         Put_C (" stroke=""var(--border)"" stroke-width=""11""");
         Put_C (" stroke-linecap=""round""/>");
         Put_C ("<path d=""M10 60 A50 50 0 0 1 110 60"" fill=""none""");
         Put_C
           (" stroke="""
            & (if DAL_Assess.Status = Types.Achieved
               then "var(--pass)"
               else "var(--fail)")
            & """ stroke-width=""11""");
         Put_C (" stroke-linecap=""round"" stroke-dasharray=""157""");
         Put_C (" stroke-dashoffset=""");
         Put_C (Img (157 - (157 * Compl_Pct) / 100));
         Put_C ("""/>");
         Put_C
           ("<text x=""60"" y=""56"" text-anchor=""middle"" font-size=""11""");
         Put_C (" font-weight=""600""");
         Put_C (" fill=""");
         Put_C
           (if DAL_Assess.Status = Types.Achieved
            then "var(--pass)"
            else "var(--fail)");
         Put_C (""">");
         Put_C (Img (Compl_Pct));
         Put_C ("%</text></svg>");
         Put_C ("</div>");
         Put_C ("<div class=""gauge-info"">");
         Put_C ("<div class=""gauge-target"">Target: <b>");
         Put_C
           (Types.Standard_Level_Name
              (DAL_Assess.Standard, DAL_Assess.Target_DAL));
         Put_C ("</b></div>");
         Put_C
           ("<div class=""gauge-achieved"">Achieved: <span class=""pct"">");
         Put_C (Img (Compl_Pct));
         Put_C ("%</span></div>");
         Put_C ("<div style=""font-size:.82rem;color:var(--muted)"">");
         Put_C ("HLR ");
         Put_C (Img (HLR_Pct));
         Put_C ("% &middot; Tests ");
         Put_C (Img (Test_Pct));
         Put_C ("% &middot; SPARK ");
         Put_C (Img (SPARK_Pct));
         Put_C ("%</div>");
         Put_C ("</div></div></div>");
      end;
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
              "__VERSION__",
              Adacovex.Version),
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
         Put (",""lang"":");
         Put_Field (Graph (I).Language, Graph (I).Language_Len);
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
