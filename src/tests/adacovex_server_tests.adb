with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Adacovex.Docs_Template;
with Adacovex.Test_Support;
with Adacovex.Server.HTTP; use Adacovex.Server.HTTP;

package body Adacovex_Server_Tests is

   --  A base85 encoder for the tests, written independently of the decoder
   --  under test. It follows the documented Z85 contract: four bytes become
   --  five characters, and a short final group is zero-padded and emitted as
   --  one character more than its payload. A round trip therefore compares
   --  the decoder against a second implementation, not against itself.
   function Encode (Data : String) return String is
      Alphabet : constant String :=
        "0123456789abcdefghijklmnopqrstuvwxyz"
        & "ABCDEFGHIJKLMNOPQRSTUVWXYZ.-:+=^!/*?&<>()[]{}@%$#";
      Result   : String (1 .. (Data'Length / 4 + 2) * 5) := (others => '0');
      Digit    : String (1 .. 5) := (others => '0');
      Chunk    : String (1 .. 4) := (others => ASCII.NUL);
      N        : Natural;
      Last     : Natural := 0;
      Pos      : Natural := Data'First;
      Value    : Long_Long_Integer;
   begin
      while Pos <= Data'Last loop
         N := 0;
         while N < 4 and then Pos + N <= Data'Last loop
            Chunk (N + 1) := Data (Pos + N);
            N := N + 1;
         end loop;
         for K in N + 1 .. 4 loop
            Chunk (K) := ASCII.NUL;
         end loop;
         Value := 0;
         for K in Chunk'Range loop
            Value :=
              Value * 256 + Long_Long_Integer (Character'Pos (Chunk (K)));
         end loop;
         for K in reverse Digit'Range loop
            Digit (K) := Alphabet (Integer (Value mod 85) + 1);
            Value := Value / 85;
         end loop;
         for K in 1 .. N + 1 loop
            Last := Last + 1;
            Result (Last) := Digit (K);
         end loop;
         Pos := Pos + 4;
      end loop;
      return Result (1 .. Last);
   end Encode;

   --  Round-trip every length 0..64 plus the two extreme byte patterns. A
   --  short final group only appears at lengths that are not a multiple of
   --  four, so the sweep pins the padding rule the real assets may not
   --  exercise.
   procedure Check_Base85_Round_Trip
     (R : in out Adacovex.Test_Support.Runner'Class) is
   begin
      for Len in 0 .. 64 loop
         declare
            Data : String (1 .. Len);
         begin
            for K in Data'Range loop
               Data (K) := Character'Val ((K * 7 + Len * 3) mod 256);
            end loop;
            R.Check
              (Adacovex.Docs_Template.Base85_Decode (Encode (Data)) = Data,
               "base85 round trip, length" & Natural'Image (Len));
         end;
      end loop;
      declare
         Zeros : constant String (1 .. 8) := (others => ASCII.NUL);
         Highs : constant String (1 .. 8) := (others => Character'Val (255));
      begin
         R.Check
           (Adacovex.Docs_Template.Base85_Decode (Encode (Zeros)) = Zeros,
            "base85 round trip, all zero bytes");
         R.Check
           (Adacovex.Docs_Template.Base85_Decode (Encode (Highs)) = Highs,
            "base85 round trip, all 0xFF bytes");
      end;
   end Check_Base85_Round_Trip;

   --  Hand-computed golden vectors from an independent encoder. A round trip
   --  cannot catch an alphabet-order change, because the encoder would share
   --  the bug; these vectors pin the exact text.
   procedure Check_Base85_Golden
     (R : in out Adacovex.Test_Support.Runner'Class) is
   begin
      R.Check
        (Adacovex.Docs_Template.Base85_Decode ("o<}]Z") = "Man ",
         "base85 golden vector: Man with a trailing space");
      R.Check
        (Adacovex.Docs_Template.Base85_Decode ("nm=QNz.92jz/PV8aP")
         = "Hello, World!",
         "base85 golden vector: Hello, World!");
      R.Check
        (Adacovex.Docs_Template.Base85_Decode ("vpAZ") = "abc",
         "base85 golden vector: three-byte final group");
   end Check_Base85_Golden;

   --  The degenerate group lengths. A final group of n payload bytes carries
   --  n+1 characters, so a 1- or 2-character group is malformed; the decoder
   --  counts Gone - 1 payload bytes and never raises.
   procedure Check_Base85_Degenerate
     (R : in out Adacovex.Test_Support.Runner'Class)
   is
      --  The decoded length of one input. Ada has no attribute reference on
      --  a function call, so a local constant carries the result.
      function Decoded_Length (S : String) return Natural is
         Decoded : constant String := Adacovex.Docs_Template.Base85_Decode (S);
      begin
         return Decoded'Length;
      end Decoded_Length;
   begin
      R.Check (Decoded_Length ("") = 0, "base85 empty input decodes to empty");
      R.Check
        (Decoded_Length ("0") = 0,
         "base85 one-character group yields no payload");
      R.Check
        (Decoded_Length ("00") = 1,
         "base85 two-character group yields one byte");
      R.Check
        (Decoded_Length ("000") = 2,
         "base85 three-character group yields two bytes");
      R.Check
        (Decoded_Length ("0000") = 3,
         "base85 four-character group yields three bytes");
      R.Check
        (Decoded_Length ("00000") = 4,
         "base85 five-character group yields four bytes");
      R.Check
        (Decoded_Length ("000000") = 4,
         "base85 six characters decode as a full group and a spare");
   end Check_Base85_Degenerate;

   --  A character outside the Z85 alphabet decodes to zero rather than
   --  raising, so the lenient contract is pinned and a future strict mode is
   --  a deliberate break.
   procedure Check_Base85_Fallback
     (R : in out Adacovex.Test_Support.Runner'Class)
   is
      Decoded : constant String :=
        Adacovex.Docs_Template.Base85_Decode ("~~~~~");
   begin
      R.Check
        (Decoded'Length = 4, "base85 out-of-alphabet group keeps its length");
      R.Check
        (Decoded = String'(1 .. 4 => ASCII.NUL),
         "base85 out-of-alphabet character decodes to zero");
   end Check_Base85_Fallback;

   --  Is_Gzip => False returns the stored body verbatim, the branch the
   --  server takes for an uncompressed asset. The stored body is the base85
   --  text, so this pins the path without a decode.
   procedure Check_Body_Bytes_Verbatim
     (R : in out Adacovex.Test_Support.Runner'Class)
   is
      First_Body : constant Adacovex.Docs_Template.Body_Index := 1;
      Stored     : constant String :=
        Adacovex.Docs_Template.Asset_Bodies (First_Body).all;
   begin
      R.Check
        (Adacovex.Docs_Template.Body_Bytes (First_Body, False) = Stored,
         "Body_Bytes with Is_Gzip false returns the stored body");
   end Check_Body_Bytes_Verbatim;

   --  The Find normalisation fallbacks: an extensionless leaf resolves to
   --  its .html page, a trailing slash appends index.html, and an absent
   --  path returns zero.
   procedure Check_Find_Fallbacks
     (R : in out Adacovex.Test_Support.Runner'Class) is
   begin
      R.Check
        (Adacovex.Docs_Template.Find ("usage/cli-reference") /= 0,
         "Find resolves an extensionless leaf to its .html page");
      R.Check
        (Adacovex.Docs_Template.Find ("usage/") /= 0,
         "Find appends index.html to a trailing slash");
      R.Check
        (Adacovex.Docs_Template.Find ("_nav/0") /= 0,
         "Find resolves a bundled sidebar variant without an extension");
      R.Check
        (Adacovex.Docs_Template.Find ("no/such/page") = 0,
         "Find returns zero for an absent path");
   end Check_Find_Fallbacks;

   --  Quote a token as a JSON string value: the /api/info checks read the
   --  payload as text, and this keeps the expected spellings readable.
   function J (S : String) return String is
   begin
      return '"' & S & '"';
   end J;

   --  How many times Needle occurs in S (overlapping-free count).
   function Occurrences (S : String; Needle : String) return Natural is
      From : Natural := S'First;
      N    : Natural := 0;
      Hit  : Natural;
   begin
      if Needle'Length = 0 then
         return 0;
      end if;
      while From <= S'Last loop
         Hit := Ada.Strings.Fixed.Index (S (From .. S'Last), Needle);
         exit when Hit = 0;
         N := N + 1;
         From := Hit + Needle'Length;
      end loop;
      return N;
   end Occurrences;

   --  The shared counter store behind /api/info: reset semantics, the
   --  per-route 200 / 404 split, the keep-alive count, and the uptime
   --  clock. The store is process-global, so the checks reset it and leave
   --  it reset for the rest of the suite.
   procedure Check_Counter_Store
     (R : in out Adacovex.Test_Support.Runner'Class)
   is
      Counts : Runtime_Counts;
   begin
      Counters.Reset;
      Counts := Counters.Snapshot;
      R.Check
        (Counts.Requests (Route_API_Info).OK = 0
         and then Counts.Requests (Route_API_Info).Not_Found = 0
         and then Counts.Keep_Alive = 0,
         "reset clears every counter");

      Counters.Note_Route (Route_API_Info, True);
      Counters.Note_Route (Route_API_Info, True);
      Counters.Note_Route (Route_Not_Found, False);
      Counters.Note_Keep_Alive;
      Counts := Counters.Snapshot;
      R.Check
        (Counts.Requests (Route_API_Info).OK = 2,
         "a found response counts on its route");
      R.Check
        (Counts.Requests (Route_API_Info).Not_Found = 0,
         "a found response never counts as 404");
      R.Check
        (Counts.Requests (Route_Not_Found).Not_Found = 1,
         "an unmatched path counts as 404");
      R.Check
        (Counts.Requests (Route_Dashboard).OK = 0,
         "every route keeps its own bucket");
      R.Check (Counts.Keep_Alive = 1, "a keep-alive connection is counted");
      R.Check
        (Counts.Uptime_Seconds < 60,
         "a fresh store reports an uptime under a minute");

      Counters.Reset;
      Counts := Counters.Snapshot;
      R.Check
        (Counts.Keep_Alive = 0
         and then Counts.Requests (Route_API_Info).OK = 0
         and then Counts.Requests (Route_Not_Found).Not_Found = 0,
         "reset clears the keep-alive count too");
   end Check_Counter_Store;

   --  The /api/info payload: every documented field carries the value the
   --  caller passed, the route table holds one entry per route kind, and a
   --  target path with JSON-hostile characters is escaped.
   procedure Check_Info_JSON (R : in out Adacovex.Test_Support.Runner'Class) is
      Counts : Runtime_Counts;
   begin
      Counts.Keep_Alive := 2;
      Counts.Uptime_Seconds := 7;
      Counts.Requests (Route_Dashboard).OK := 5;
      Counts.Requests (Route_Not_Found).Not_Found := 1;
      declare
         Payload : constant String :=
           Render_Info_JSON
             ("/tmp/prj", "all", "1.62.0", 8080, 4, Counts, 3, 1, 42);
      begin
         R.Check
           (Payload'Length > 0
            and then Payload (Payload'First) = '{'
            and then Payload (Payload'Last) = '}',
            "the info payload is a JSON object");
         R.Check
           (Ada.Strings.Fixed.Index
              (Payload, J ("version") & ": " & J ("1.62.0"))
            > 0,
            "the payload carries the bundled version");
         R.Check
           (Ada.Strings.Fixed.Index
              (Payload, J ("target") & ": " & J ("/tmp/prj"))
            > 0,
            "the payload carries the audited target");
         R.Check
           (Ada.Strings.Fixed.Index
              (Payload, J ("standard") & ": " & J ("all"))
            > 0,
            "an all-standards run reports all");
         R.Check
           (Ada.Strings.Fixed.Index (Payload, J ("port") & ": 8080") > 0,
            "the payload carries the bound port");
         R.Check
           (Ada.Strings.Fixed.Index (Payload, J ("workers") & ": 4") > 0,
            "the payload carries the worker count");
         R.Check
           (Ada.Strings.Fixed.Index (Payload, J ("uptime_seconds") & ": 7")
            > 0,
            "the payload carries the uptime");
         R.Check
           (Ada.Strings.Fixed.Index (Payload, J ("assessment_ms") & ": 42")
            > 0,
            "the payload carries the assessment time");
         R.Check
           (Ada.Strings.Fixed.Index (Payload, J ("hits") & ": 3") > 0,
            "the payload carries the cache hits");
         R.Check
           (Ada.Strings.Fixed.Index (Payload, J ("misses") & ": 1") > 0,
            "the payload carries the cache misses");
         R.Check
           (Ada.Strings.Fixed.Index
              (Payload, J ("keep_alive_connections") & ": 2")
            > 0,
            "the payload carries the keep-alive count");
         R.Check
           (Ada.Strings.Fixed.Index (Payload, J ("ok") & ": 5") > 0,
            "the payload totals the served responses");
         R.Check
           (Ada.Strings.Fixed.Index (Payload, J ("not_found") & ": 1") > 0,
            "the payload totals the 404 responses");
         R.Check
           (Occurrences (Payload, J ("path"))
            = Route_Kind'Pos (Route_Kind'Last) + 1,
            "the route table names every route kind once");
      end;
      declare
         Quoted : constant String :=
           Render_Info_JSON
             ("/tmp/a""b", "do178c", "1.62.0", 8080, 4, Counts, 0, 0, 0);
      begin
         R.Check
           (Ada.Strings.Fixed.Index
              (Quoted, J ("target") & ": " & J ("/tmp/a" & '\' & '"' & "b"))
            > 0,
            "a quote in the target path is JSON-escaped");
         R.Check
           (Ada.Strings.Fixed.Index
              (Quoted, J ("standard") & ": " & J ("do178c"))
            > 0,
            "a single standard reports its slug");
      end;
   end Check_Info_JSON;

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
   begin
      --  The literal routes the server dispatches on. Route is the
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
        (Route ("/api/spark") = Route_API_Spark, "spark coverage API route");
      R.Check
        (Route ("/api/endpoints") = Route_API_Endpoints,
         "endpoints catalog route");
      R.Check (Route ("/api/info") = Route_API_Info, "server info API route");
      R.Check (Route ("/health") = Route_Health, "health probe route");

      --  Route_Path is the inverse of Route for every kind, so the counter
      --  table and the /api/info payload can name each bucket with the path
      --  the server dispatches it on. The catch-all bucket names itself
      --  "*", which no client can request as a literal path.
      R.Check
        (Route (Route_Path (Route_Dashboard)) = Route_Dashboard,
         "dashboard path round trip");
      R.Check
        (Route (Route_Path (Route_Badge_SPARK)) = Route_Badge_SPARK,
         "spark badge path round trip");
      R.Check
        (Route (Route_Path (Route_Badge_Tests)) = Route_Badge_Tests,
         "tests badge path round trip");
      R.Check
        (Route (Route_Path (Route_Badge_DO178C)) = Route_Badge_DO178C,
         "do178c badge path round trip");
      R.Check
        (Route (Route_Path (Route_Badge_ISO26262)) = Route_Badge_ISO26262,
         "iso26262 badge path round trip");
      R.Check
        (Route (Route_Path (Route_Badge_IEC62304)) = Route_Badge_IEC62304,
         "iec62304 badge path round trip");
      R.Check
        (Route (Route_Path (Route_API_Metrics)) = Route_API_Metrics,
         "metrics API path round trip");
      R.Check
        (Route (Route_Path (Route_API_Deps)) = Route_API_Deps,
         "deps API path round trip");
      R.Check
        (Route (Route_Path (Route_API_Endpoints)) = Route_API_Endpoints,
         "endpoints API path round trip");
      R.Check
        (Route (Route_Path (Route_API_Spark)) = Route_API_Spark,
         "spark coverage API path round trip");
      R.Check
        (Route (Route_Path (Route_API_Info)) = Route_API_Info,
         "server info API path round trip");
      R.Check
        (Route (Route_Path (Route_Health)) = Route_Health,
         "health probe path round trip");
      R.Check
        (Route (Route_Path (Route_Docs)) = Route_Docs, "docs path round trip");
      R.Check
        (Route (Route_Path (Route_Not_Found)) = Route_Not_Found,
         "catch-all bucket round trip");

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
        (Route (Strip_Query ("/health?poll=1")) = Route_Health,
         "query stripped from health probe");
      R.Check
        (Route (Strip_Query ("/api/info#top")) = Route_API_Info,
         "fragment stripped from server info API");
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
        (Route ("/api/info/") = Route_Not_Found,
         "trailing slash on info is not found");
      R.Check
        (Route ("/api/infos") = Route_Not_Found, "info suffix is not found");
      R.Check
        (Route ("/API/info") = Route_Not_Found,
         "uppercase info path is not found");
      R.Check
        (Route ("/health/") = Route_Not_Found,
         "trailing slash on health is not found");
      R.Check
        (Route ("/healt") = Route_Not_Found, "health prefix is not found");
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
         and then Route ("/api/spark") /= Route_Not_Found
         and then Route ("/api/endpoints") /= Route_Not_Found
         and then Route ("/api/info") /= Route_Not_Found
         and then Route ("/health") /= Route_Not_Found
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

      --  The bundled base85 decoder, exercised with synthetic vectors: a
      --  round trip against an independent encoder, hand-computed golden
      --  vectors, the degenerate lengths, the out-of-alphabet fallback, the
      --  verbatim Body_Bytes path, and the Find fallbacks.
      Check_Base85_Round_Trip (R);
      Check_Base85_Golden (R);
      Check_Base85_Degenerate (R);
      Check_Base85_Fallback (R);
      Check_Body_Bytes_Verbatim (R);
      Check_Find_Fallbacks (R);

      --  The server's runtime surface: the counters /api/info reports and
      --  the payload itself.
      Check_Counter_Store (R);
      Check_Info_JSON (R);
   end Run;

end Adacovex_Server_Tests;
