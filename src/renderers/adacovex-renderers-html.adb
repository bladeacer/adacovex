package body Adacovex.Renderers.HTML is

   use type Types.Test_Status;
   use type Types.DAL_Status;

   function Render_Dashboard
     (Doc_Metrics : Types.Docstring_Metrics;
      Proof       : Types.Proof_Summary;
      Tests       : Types.Test_Summary;
      DAL_Assess  : Types.DAL_Assessment;
      Packages    : Types.Package_Vectors.Vector) return String
   is
      Result : String (1 .. 32768);
      Pos    : Natural := 1;

      procedure Put (S : String) is
      begin
         for I in S'Range loop
            if Pos <= Result'Last then
               Result (Pos) := S (I);
               Pos := Pos + 1;
            end if;
         end loop;
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
        ("body{font-family:DejaVu Sans,sans-serif;margin:40px;background:#f5f5f5}");
      Put ("h1{color:#333}");
      Put
        (".card{background:#fff;border-radius:8px;padding:20px;margin:16px 0;box-shadow:0 2px 4px rgba(0,0,0,.1)}");
      Put ("table{width:100%;border-collapse:collapse}");
      Put
        ("th,td{padding:8px 12px;text-align:left;border-bottom:1px solid #ddd}");
      Put ("th{background:#f0f0f0}");
      Put (".badge-container{display:flex;gap:16px;flex-wrap:wrap}");
      Put (".badge-container svg{height:20px}");
      Put (".pass{color:#4c1;font-weight:bold}");
      Put (".fail{color:#e05d44;font-weight:bold}");
      Put (".spark-");
      Put (Types.To_String (Proof.Level));
      Put ("{color:");
      Put (Spark_Color);
      Put (";font-weight:bold}");
      Put ("</style></head><body>");

      Put ("<h1>adacovex Coverage & Verification Dashboard</h1>");

      -- Badges
      Put
        ("<div class=""card""><h2>Status Badges</h2><div class=""badge-container"">");
      Put ("<img src=""/badge/spark.svg"" alt=""SPARK Badge"">");
      Put ("<img src=""/badge/tests.svg"" alt=""Tests Badge"">");
      Put ("<img src=""/badge/do178c.svg"" alt=""DO-178C Badge"">");
      Put ("</div></div>");

      -- Source Overview
      Put ("<div class=""card"">");
      Put ("<h2>Source Overview</h2>");
      Put ("<table><tr><th>Metric</th><th>Value</th></tr>");
      Put ("<tr><td>Packages Scanned</td><td>");
      Put (Integer'Image (Integer (Packages.Length)));
      Put ("</td></tr>");
      Put ("<tr><td>Total Subprograms</td><td>");
      Put (Natural'Image (Doc_Metrics.Total_Subprograms));
      Put ("</td></tr>");
      Put ("<tr><td>Docstring Coverage</td><td>");
      Put (Natural'Image (Doc_Metrics.Coverage_Pct));
      Put ("%</td></tr></table></div>");

      -- SPARK Proof
      Put ("<div class=""card"">");
      Put ("<h2>SPARK Proof Analysis</h2>");
      Put ("<table><tr><th>Check Type</th><th>Total</th><th>Proved</th></tr>");
      Put ("<tr><td>Level</td><td colspan=""2"" class=""spark-");
      Put (Types.To_String (Proof.Level));
      Put (""">");
      Put (Types.To_String (Proof.Level));
      Put ("</td></tr>");
      Put ("<tr><td>Flow</td><td>");
      Put (Natural'Image (Proof.Flow_Checks));
      Put ("</td><td>");
      Put (Natural'Image (Proof.Flow_Proved));
      Put ("</td></tr>");
      Put ("<tr><td>Runtime</td><td>");
      Put (Natural'Image (Proof.Runtime_Checks));
      Put ("</td><td>");
      Put (Natural'Image (Proof.Runtime_Proved));
      Put ("</td></tr>");
      Put ("<tr><td>Assertions</td><td>");
      Put (Natural'Image (Proof.Assertions));
      Put ("</td><td>");
      Put (Natural'Image (Proof.Assert_Proved));
      Put ("</td></tr>");
      Put ("<tr><td>Functional</td><td>");
      Put (Natural'Image (Proof.Functional_Ct));
      Put ("</td><td>");
      Put (Natural'Image (Proof.Functional_Proved));
      Put ("</td></tr>");
      Put ("<tr><td>Total VCs</td><td>");
      Put (Natural'Image (Proof.Total_VCs));
      Put ("</td><td>");
      Put (Natural'Image (Proof.Proved_VCs));
      Put ("</td></tr></table></div>");

      -- Test Results
      Put ("<div class=""card"">");
      Put ("<h2>Test Results</h2>");
      Put ("<table><tr><th>Category</th><th>Tests</th><th>Status</th></tr>");
      for C in 1 .. Integer (Tests.Categories.Length) loop
         Put ("<tr><td>");
         Put
           (Tests.Categories (C).Category (1 .. Tests.Categories (C).Cat_Len));
         Put ("</td><td>");
         Put (Natural'Image (Tests.Categories (C).Test_Count));
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
      Put (Natural'Image (Tests.Total_Passed + Tests.Total_Failed));
      Put ("</strong></td><td><strong class=""");
      Put (if Tests.Total_Failed = 0 then "pass" else "fail");
      Put (""">Passed: ");
      Put (Natural'Image (Tests.Total_Passed));
      Put (", Failed: ");
      Put (Natural'Image (Tests.Total_Failed));
      Put ("</strong></td></tr></table></div>");

      -- DO-178C
      Put ("<div class=""card"">");
      Put ("<h2>DO-178C Compliance</h2>");
      Put ("<table><tr><th>Criterion</th><th>Status</th></tr>");
      Put ("<tr><td>Target DAL</td><td>DAL-");
      Put (Types.To_String (DAL_Assess.Target_DAL));
      Put ("</td></tr>");
      Put ("<tr><td>Overall Status</td><td class=""");
      Put (if DAL_Assess.Status = Types.Achieved then "pass" else "fail");
      Put (""">");
      Put (Types.To_String (DAL_Assess.Status));
      Put ("</td></tr>");
      Put ("<tr><td>HLR Traced</td><td>");
      Put (Natural'Image (DAL_Assess.HLR_Found));
      Put (" / ");
      Put (Natural'Image (DAL_Assess.HLR_Total));
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

      -- HLR Traceability
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
        ("<p style=""color:#888;font-size:0.8em"">Generated by adacovex</p>");
      Put ("</body></html>");

      return Result (1 .. Pos - 1);
   end Render_Dashboard;

   function Render_Metrics_JSON
     (Doc_Metrics : Types.Docstring_Metrics;
      Proof       : Types.Proof_Summary;
      Tests       : Types.Test_Summary;
      DAL_Assess  : Types.DAL_Assessment) return String
   is
      Result : String (1 .. 4096);
      Pos    : Natural := 1;

      procedure Put (S : String) is
      begin
         for I in S'Range loop
            if Pos <= Result'Last then
               Result (Pos) := S (I);
               Pos := Pos + 1;
            end if;
         end loop;
      end Put;
   begin
      Put ("{");
      Put ("""spark_level"":""");
      Put (Types.To_String (Proof.Level));
      Put (""",");
      Put ("""total_vcs"":");
      Put (Natural'Image (Proof.Total_VCs));
      Put (",");
      Put ("""proved_vcs"":");
      Put (Natural'Image (Proof.Proved_VCs));
      Put (",");
      Put ("""tests_passed"":");
      Put (Natural'Image (Tests.Total_Passed));
      Put (",");
      Put ("""tests_failed"":");
      Put (Natural'Image (Tests.Total_Failed));
      Put (",");
      Put ("""doc_coverage"":");
      Put (Natural'Image (Doc_Metrics.Coverage_Pct));
      Put (",");
      Put ("""dal_status"":""");
      Put (Types.To_String (DAL_Assess.Status));
      Put ("""");
      Put ("}");

      return Result (1 .. Pos - 1);
   end Render_Metrics_JSON;

end Adacovex.Renderers.HTML;
