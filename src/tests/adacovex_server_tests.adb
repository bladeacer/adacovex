with Ada.Exceptions;
with Ada.Text_IO;
with Adacovex.Docs_Template;
with Adacovex.Test_Support;
with Adacovex.Server.HTTP; use Adacovex.Server.HTTP;

package body Adacovex_Server_Tests is

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
   begin
      --  The seven literal routes the server dispatches on. Route is the
      --  pure path-to-action mapping behind Handle_Request's case statement
      --  (LLR-SERVER-01's dashboard / API / badge surface), so every route
      --  the socket handler can serve is pinned here.
      R.Check (Route ("/") = Route_Dashboard, "dashboard route");
      R.Check
        (Route ("/badge/spark.svg") = Route_Badge_SPARK, "spark badge route");
      R.Check
        (Route ("/badge/tests.svg") = Route_Badge_Tests, "tests badge route");
      R.Check
        (Route ("/badge/do178c.svg") = Route_Badge_DO178C,
         "do178c badge route");
      R.Check
        (Route ("/badge/iso26262.svg") = Route_Badge_ISO26262,
         "iso26262 badge route");
      R.Check
        (Route ("/badge/iec62304.svg") = Route_Badge_IEC62304,
         "iec62304 badge route");
      R.Check
        (Route ("/api/metrics") = Route_API_Metrics, "metrics API route");
      R.Check (Route ("/api/deps") = Route_API_Deps, "deps API route");
      R.Check
        (Route ("/api/endpoints") = Route_API_Endpoints,
         "endpoints catalog route");

      --  The bundled offline manual is served at both /"/docs" (no trailing
      --  slash) and "/docs/" (trailing slash), so the dashboard footer link
      --  and a user typing either spelling both reach the manual.
      R.Check (Route ("/docs") = Route_Docs, "docs route");
      R.Check (Route ("/docs/") = Route_Docs, "docs trailing-slash route");

      --  Query-string and fragment stripping: browsers append ?query and
      --  #fragment to the request path, and routing must ignore both so a
      --  themed dashboard URL (`/?theme=light`) serves the dashboard instead
      --  of 404ing.
      R.Check (Strip_Query ("/") = "/", "plain root unchanged");
      R.Check
        (Strip_Query ("/?theme=light") = "/",
         "query string stripped from root");
      R.Check
        (Strip_Query ("/?theme=dark") = "/",
         "dark theme query stripped from root");
      R.Check
        (Strip_Query ("/api/metrics?x=1") = "/api/metrics",
         "query stripped from metrics API");
      R.Check
        (Strip_Query ("/api/endpoints?x=1") = "/api/endpoints",
         "query stripped from endpoints catalog");
      R.Check
        (Strip_Query ("/api/deps#top") = "/api/deps",
         "fragment stripped from deps API");
      R.Check
        (Strip_Query ("/badge/spark.svg?x=1") = "/badge/spark.svg",
         "query stripped from badge");
      R.Check
        (Strip_Query ("/?theme=light#proof") = "/",
         "query and fragment both stripped");
      R.Check (Strip_Query ("") = "", "empty path stays empty");
      R.Check (Strip_Query ("/badge") = "/badge", "no query means unchanged");
      R.Check
        (Strip_Query ("/badge/tests.svg") = "/badge/tests.svg",
         "no query on badge unchanged");

      --  Unknown paths are 404s: empty, near-misses of every literal route
      --  (case, trailing slash, wrong extension, prefix, suffix, query
      --  string), and arbitrary URLs.
      R.Check (Route ("") = Route_Not_Found, "empty path is not found");
      R.Check
        (Route ("/index.html") = Route_Not_Found, "index.html is not found");
      R.Check
        (Route ("/favicon.ico") = Route_Not_Found, "favicon.ico is not found");
      R.Check
        (Route ("/badge") = Route_Not_Found, "/badge alone is not found");
      R.Check (Route ("/badge/") = Route_Not_Found, "/badge/ is not found");
      R.Check
        (Route ("/docs2") = Route_Not_Found,
         "docs-prefixed path is not found");
      R.Check
        (Route ("/manual") = Route_Not_Found, "manual alias is not found");
      R.Check
        (Route ("/badge/spark.svg/") = Route_Not_Found,
         "trailing slash on badge is not found");
      R.Check
        (Route ("/BADGE/spark.svg") = Route_Not_Found,
         "uppercase badge path is not found");
      R.Check
        (Route ("/badge/spark.png") = Route_Not_Found,
         "wrong badge extension is not found");
      R.Check
        (Route ("/badge/spark.svg?x=1") = Route_Not_Found,
         "query string on badge is not found");
      R.Check (Route ("/api") = Route_Not_Found, "/api alone is not found");
      R.Check
        (Route ("/api/metrics/") = Route_Not_Found,
         "trailing slash on metrics is not found");
      R.Check
        (Route ("/api/metric") = Route_Not_Found,
         "metrics prefix is not found");
      R.Check
        (Route ("/healthz") = Route_Not_Found,
         "health check path is not found");
      R.Check (Route ("//") = Route_Not_Found, "double slash is not found");
      R.Check (Route ("/../") = Route_Not_Found, "dot-dot path is not found");
      R.Check
        (Route ("/badge/iec62304.svg.gz") = Route_Not_Found,
         "compressed badge suffix is not found");

      --  Every Route_Kind value is reachable through Route (the enum is
      --  fully covered by the mapping above, so the case dispatch in
      --  Handle_Request cannot hit an uninitialized handler).
      R.Check
        (Route ("/") /= Route_Not_Found
         and then Route ("/badge/spark.svg") /= Route_Not_Found
         and then Route ("/badge/tests.svg") /= Route_Not_Found
         and then Route ("/badge/do178c.svg") /= Route_Not_Found
         and then Route ("/badge/iso26262.svg") /= Route_Not_Found
         and then Route ("/badge/iec62304.svg") /= Route_Not_Found
         and then Route ("/api/metrics") /= Route_Not_Found
         and then Route ("/api/deps") /= Route_Not_Found
         and then Route ("/api/endpoints") /= Route_Not_Found
         and then Route ("/docs") /= Route_Not_Found
         and then Route ("/docs/") /= Route_Not_Found,
         "all served routes are non-404");

      --  The bundled offline manual: every asset body is base85 text that
      --  decodes to a gzip stream, so each one must carry the gzip magic
      --  number the browser's inflater expects, and its decoded length must
      --  match the base85 packing (five characters per four bytes, one
      --  shorter final group). Walking the whole table pins the encoder and
      --  the decoder together: a truncated, shifted, or misaligned body
      --  fails here instead of in the browser.
      declare
         Not_Gzip   : Natural := 0;
         Wrong_Size : Natural := 0;
         Failures   : Natural := 0;
         First_Bad  : String (1 .. 80) := (others => ' ');
         First_At   : Natural := 0;
      begin
         for I in Adacovex.Docs_Template.Asset_Index loop
            begin
               declare
                  L        : constant Natural :=
                    Adacovex.Docs_Template.Asset_Bodies
                      (Adacovex.Docs_Template.Assets (I).Idx).all'Length;
                  B        : constant String :=
                    Adacovex.Docs_Template.Content (I);
                  Expected : constant Natural :=
                    (if L mod 5 = 0
                     then (L / 5) * 4
                     else (L / 5) * 4 + (L mod 5) - 1);
               begin
                  if not Adacovex.Docs_Template.Assets (I).Gzip
                    or else B'Length < 2
                    or else B (B'First) /= Character'Val (16#1F#)
                    or else B (B'First + 1) /= Character'Val (16#8B#)
                  then
                     Not_Gzip := Not_Gzip + 1;
                  end if;
                  if B'Length /= Expected then
                     Wrong_Size := Wrong_Size + 1;
                  end if;
               end;
            exception
               when E : others =>
                  Failures := Failures + 1;
                  if First_At = 0 then
                     First_Bad := Adacovex.Docs_Template.Assets (I).Path;
                     First_At := Natural (I);
                     Ada.Text_IO.Put_Line
                       ("  base85 probe: "
                        & Ada.Exceptions.Exception_Name (E)
                        & " / "
                        & Ada.Exceptions.Exception_Message (E)
                        & " text len"
                        & Natural'Image
                            (Adacovex.Docs_Template.Asset_Bodies
                               (Adacovex.Docs_Template.Assets (I)
                                  .Idx).all'Length));
                  end if;
            end;
         end loop;
         if Failures > 0 then
            Ada.Text_IO.Put_Line
              ("  base85 probe: first failing asset"
               & Positive'Image (First_At)
               & " = "
               & First_Bad);
         end if;
         R.Check
           (Adacovex.Docs_Template.Asset_Count > 100,
            "the manual bundles its whole asset set");
         R.Check (Failures = 0, "every bundled asset body decodes");
         R.Check (Not_Gzip = 0, "every bundled asset body is a gzip stream");
         R.Check
           (Wrong_Size = 0, "every base85 body decodes to its packed length");
      end;

      --  The shared sidebar: the pages carry a stub, and the toctree itself
      --  plus the script that fills it are bundled assets (so a stub can
      --  always resolve, and a page never links a missing file).
      R.Check
        (Adacovex.Docs_Template.Find ("index.html") /= 0,
         "the manual index is bundled");
      R.Check
        (Adacovex.Docs_Template.Find ("_nav/0.html") /= 0,
         "the shared sidebar variants are bundled");
      R.Check
        (Adacovex.Docs_Template.Find ("_static/adacovex-nav.js") /= 0,
         "the sidebar script is bundled");
   end Run;

end Adacovex_Server_Tests;
