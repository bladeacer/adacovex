with Ada.Strings.Unbounded;

package body Adacovex.Renderers.HTML is

   use Ada.Strings.Unbounded;
   use type Types.Test_Status;
   use type Types.DAL_Status;

   function Img (N : Natural) return String is
      S : constant String := Natural'Image (N);
   begin
      return S (2 .. S'Last);
   end Img;

   function Render_Dashboard
     (Doc_Metrics   : Types.Docstring_Metrics;
      Proof         : Types.Proof_Summary;
      Tests         : Types.Implementation.Test_Summary;
      DAL_Assess    : Types.Implementation.DAL_Assessment;
      Packages      : Types.Implementation.Package_Vectors.Vector;
      All_Standards : Boolean := False) return String
   is
      Result : Unbounded_String;

      procedure Put (S : String) is
      begin
         Append (Result, S);
      end Put;

      Spark_Color : String (1 .. 7) := (others => ' ');
   begin
      case Proof.Level is
         when Types.Platinum =>
            Spark_Color := "#E5E4E2";

         when Types.Gold     =>
            Spark_Color := "#FFD700";

         when Types.Silver   =>
            Spark_Color := "#C0C0C0";

         when Types.Bronze   =>
            Spark_Color := "#CD7F32";

         when Types.Stone    =>
            Spark_Color := "#888888";
      end case;

      Put ("<!DOCTYPE html><html lang=""en""><head>");
      Put ("<meta charset=""UTF-8"">");
      Put ("<title>adacovex Dashboard</title>");
      Put ("<style>");
      Put
        (":root{--bg:#f5f5f5;--fg:#333;--card:#fff;--border:#ddd;--th:#f0f0f0;"
         & "--pass:#4c1;--fail:#e05d44;--muted:#888}");
      Put
        ("@media (prefers-color-scheme:dark){:root{--bg:#1e1e1e;--fg:#e0e0e0;"
         & "--card:#2d2d2d;--border:#444;--th:#3a3a3a;--pass:#8bc34a;"
         & "--fail:#ff6b5e;--muted:#999}}");
      Put
        (":root[data-theme=""dark""]{--bg:#1e1e1e;--fg:#e0e0e0;"
         & "--card:#2d2d2d;--border:#444;--th:#3a3a3a;--pass:#8bc34a;"
         & "--fail:#ff6b5e;--muted:#999}");
      Put
        (":root[data-theme=""light""]{--bg:#f5f5f5;--fg:#333;--card:#fff;"
         & "--border:#ddd;--th:#f0f0f0;--pass:#4c1;--fail:#e05d44;"
         & "--muted:#888}");
      Put
        ("body{font-family:DejaVu Sans,sans-serif;margin:40px;background:var(--bg);"
         & "color:var(--fg)}");
      Put ("h1{color:var(--fg)}");
      Put
        (".dash-header{display:flex;justify-content:space-between;align-items:center;"
         & "flex-wrap:wrap;gap:12px}");
      Put
        (".card{background:var(--card);border-radius:8px;padding:20px;margin:16px 0;"
         & "box-shadow:0 2px 4px rgba(0,0,0,.1)}");
      Put ("table{width:100%;border-collapse:collapse}");
      Put
        ("th,td{padding:8px 12px;text-align:left;border-bottom:1px solid var(--border)}");
      Put ("th{background:var(--th)}");
      Put (".badge-container{display:flex;gap:16px;flex-wrap:wrap}");
      Put (".badge-container svg{height:20px}");
      Put (".pass{color:var(--pass);font-weight:bold}");
      Put (".fail{color:var(--fail);font-weight:bold}");
      Put
        (".theme-toggle{background:var(--card);color:var(--fg);"
         & "border:1px solid var(--border);border-radius:6px;padding:8px 14px;"
         & "cursor:pointer;font-size:0.9em;font-family:inherit}");
      Put (".theme-toggle:hover{border-color:var(--pass)}");
      Put (".spark-");
      Put (Types.To_String (Proof.Level));
      Put ("{color:");
      Put (Spark_Color);
      Put (";font-weight:bold}");
      Put ("</style></head><body>");

      Put ("<div class=""dash-header"">");
      Put ("<h1>adacovex Coverage & Verification Dashboard</h1>");
      Put
        ("<button id=""theme-toggle"" class=""theme-toggle"" type=""button"""
         & ">Dark mode</button>");
      Put ("</div>");

      Put
        ("<div class=""card""><h2>Status Badges</h2><div class=""badge-container"">");
      Put ("<img src=""/badge/spark.svg"" alt=""SPARK Badge"">");
      Put ("<img src=""/badge/tests.svg"" alt=""Tests Badge"">");
      if All_Standards then
         for Std in Types.Compliance_Standard loop
            Put ("<img src=""/badge/");
            Put (Types.Standard_Slug (Std));
            Put (".svg"" alt=""");
            Put (Types.To_String (Std));
            Put (" Badge"">");
         end loop;
      else
         Put ("<img src=""/badge/");
         Put (Types.Standard_Slug (DAL_Assess.Standard));
         Put (".svg"" alt=""");
         Put (Types.To_String (DAL_Assess.Standard));
         Put (" Badge"">");
      end if;
      Put ("</div></div>");

      Put ("<div class=""card"">");
      Put ("<h2>Source Overview</h2>");
      Put ("<table><tr><th>Metric</th><th>Value</th></tr>");
      Put ("<tr><td>Packages Scanned</td><td>");
      Put (Img (Natural (Packages.Length)));
      Put ("</td></tr>");
      Put ("<tr><td>Total Subprograms</td><td>");
      Put (Img (Doc_Metrics.Total_Subprograms));
      Put ("</td></tr>");
      Put ("<tr><td>Docstring Coverage</td><td>");
      Put (Img (Doc_Metrics.Coverage_Pct));
      Put ("%</td></tr></table></div>");

      Put ("<div class=""card"">");
      Put ("<h2>SPARK Proof Analysis</h2>");
      Put ("<table><tr><th>Check Type</th><th>Total</th><th>Proved</th></tr>");
      Put ("<tr><td>Level</td><td colspan=""2"" class=""spark-");
      Put (Types.To_String (Proof.Level));
      Put (""">");
      Put (Types.To_String (Proof.Level));
      Put ("</td></tr>");
      Put ("<tr><td>Flow</td><td>");
      Put (Img (Proof.Flow_Checks));
      Put ("</td><td>");
      Put (Img (Proof.Flow_Proved));
      Put ("</td></tr>");
      Put ("<tr><td>Initialization</td><td>");
      Put (Img (Proof.Init_Checks));
      Put ("</td><td>");
      Put (Img (Proof.Init_Proved));
      Put ("</td></tr>");
      Put ("<tr><td>Runtime</td><td>");
      Put (Img (Proof.Runtime_Checks));
      Put ("</td><td>");
      Put (Img (Proof.Runtime_Proved));
      Put ("</td></tr>");
      Put ("<tr><td>Assertions</td><td>");
      Put (Img (Proof.Assertions));
      Put ("</td><td>");
      Put (Img (Proof.Assert_Proved));
      Put ("</td></tr>");
      Put ("<tr><td>Functional</td><td>");
      Put (Img (Proof.Functional_Ct));
      Put ("</td><td>");
      Put (Img (Proof.Functional_Proved));
      Put ("</td></tr>");
      Put ("<tr><td>Total VCs</td><td>");
      Put (Img (Proof.Total_VCs));
      Put ("</td><td>");
      Put (Img (Proof.Proved_VCs));
      Put ("</td></tr></table></div>");

      Put ("<div class=""card"">");
      Put ("<h2>Test Results</h2>");
      Put ("<table><tr><th>Category</th><th>Tests</th><th>Status</th></tr>");
      for C in 1 .. Integer (Tests.Categories.Length) loop
         Put ("<tr><td>");
         Put
           (Tests.Categories (C).Category (1 .. Tests.Categories (C).Cat_Len));
         Put ("</td><td>");
         Put (Img (Tests.Categories (C).Test_Count));
         Put ("</td><td class=""");
         Put
           (if Tests.Categories (C).Status = Types.Pass
            then "pass"
            else "fail");
         Put (""">");
         Put (Types.To_String (Tests.Categories (C).Status));
         Put ("</td></tr>");
      end loop;
      Put ("<tr><td><strong>Total</strong></td><td><strong>");
      Put (Img (Tests.Total_Passed + Tests.Total_Failed));
      Put ("</strong></td><td><strong class=""");
      Put (if Tests.Total_Failed = 0 then "pass" else "fail");
      Put (""">Passed: ");
      Put (Img (Tests.Total_Passed));
      Put (", Failed: ");
      Put (Img (Tests.Total_Failed));
      Put ("</strong></td></tr></table></div>");

      Put ("<div class=""card"">");
      if All_Standards then
         Put ("<h2>Compliance (all standards)</h2>");
      else
         Put ("<h2>");
         Put (Types.To_String (DAL_Assess.Standard));
         Put (" Compliance</h2>");
      end if;
      Put ("<table><tr><th>Criterion</th><th>Status</th></tr>");
      if All_Standards then
         for Std in Types.Compliance_Standard loop
            Put ("<tr><td>");
            Put (Types.To_String (Std));
            Put (" level</td><td class=""");
            Put
              (if DAL_Assess.Status = Types.Achieved then "pass" else "fail");
            Put (""">");
            Put (Types.Standard_Level_Name (Std, DAL_Assess.Target_DAL));
            Put (" (");
            Put (Types.To_String (DAL_Assess.Status));
            Put (")</td></tr>");
         end loop;
      else
         Put ("<tr><td>Target level</td><td>");
         Put
           (Types.Standard_Level_Name
              (DAL_Assess.Standard, DAL_Assess.Target_DAL));
         Put ("</td></tr>");
         Put ("<tr><td>Overall Status</td><td class=""");
         Put (if DAL_Assess.Status = Types.Achieved then "pass" else "fail");
         Put (""">");
         Put (Types.To_String (DAL_Assess.Status));
         Put ("</td></tr>");
      end if;
      Put ("<tr><td>HLR Traced</td><td>");
      Put (Img (DAL_Assess.HLR_Found));
      Put (" / ");
      Put (Img (DAL_Assess.HLR_Total));
      Put ("</td></tr>");
      Put ("<tr><td>Orphan Tags</td><td>");
      Put (if DAL_Assess.Orphan_Tags then "Yes" else "No");
      Put ("</td></tr>");
      Put ("<tr><td>Tests Passing</td><td>");
      Put (if DAL_Assess.Tests_Passing then "Yes" else "No");
      Put ("</td></tr>");

      if not DAL_Assess.Failed_Reasons.Is_Empty then
         for R in 1 .. Integer (DAL_Assess.Failed_Reasons.Length) loop
            Put ("<tr><td>Failure</td><td class=""fail"">");
            Put (DAL_Assess.Failed_Reasons (R));
            Put ("</td></tr>");
         end loop;
      end if;

      Put ("</table></div>");

      Put ("<div class=""card"">");
      Put ("<h2>HLR Traceability</h2>");
      Put ("<table><tr><th>Package</th><th>HLR Tags</th></tr>");
      for P in 1 .. Integer (Packages.Length) loop
         if not Packages (P).HLR_Tags.Is_Empty then
            Put ("<tr><td>");
            Put (Packages (P).Name (1 .. Packages (P).Name_Len));
            Put ("</td><td>");
            for T in 1 .. Integer (Packages (P).HLR_Tags.Length) loop
               if T > 1 then
                  Put (", ");
               end if;
               Put
                 (Packages (P).HLR_Tags (T).Tag
                    (1 .. Packages (P).HLR_Tags (T).Len));
            end loop;
            Put ("</td></tr>");
         end if;
      end loop;
      Put ("</table></div>");

      Put
        ("<p style=""color:var(--muted);font-size:0.8em"">Generated by adacovex</p>");
      Put ("<script>");
      Put
        ("(function(){var K='adacovex-theme',R=document.documentElement,"
         & "B=document.getElementById('theme-toggle');");
      Put
        ("function cur(){var t=R.getAttribute('data-theme');if(t==='dark'"
         & "||t==='light')return t;return(window.matchMedia&&"
         & "window.matchMedia('(prefers-color-scheme: dark)').matches)"
         & "?'dark':'light';}");
      Put
        ("function lab(){if(B)B.textContent=cur()==='dark'?'Light mode':'Dark mode';}");
      Put ("var s=null;try{s=localStorage.getItem(K);}catch(e){}");
      Put
        ("if(s==='dark'||s==='light')R.setAttribute('data-theme',s);");
      Put
        ("if(B)B.onclick=function(){var n=cur()==='dark'?'light':'dark';"
         & "R.setAttribute('data-theme',n);try{localStorage.setItem(K,n);}"
         & "catch(e){}lab();};");
      Put ("lab();})();");
      Put ("</script>");
      Put ("</body></html>");

      return To_String (Result);
   end Render_Dashboard;

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
