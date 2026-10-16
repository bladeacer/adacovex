with Adacovex.Types;
with Ada.Calendar;
with Ada.Strings.Unbounded;

--  Multi-threaded HTTP/1.1 server built on GNAT.Sockets.
--  The server uses a bounded Ada task pool for concurrent request handling.
--  The server supports keep-alive connections. It serves the web dashboard,
--  the JSON API, and the SVG badge endpoints.
--  HLR-SERVER: HTTP server

package Adacovex.Server.HTTP is

   --  The action that a request path routes to. The HTTP server serves the
   --  dashboard, the JSON API, the SVG badge endpoints, the server-info
   --  payload, the health probe, and the bundled offline manual (every path
   --  under /docs/). Every other path returns a 404.
   type Route_Kind is
     (Route_Dashboard,
      Route_Badge_SPARK,
      Route_Badge_Tests,
      Route_Badge_DO178C,
      Route_Badge_ISO26262,
      Route_Badge_IEC62304,
      Route_API_Metrics,
      Route_API_Deps,
      Route_API_Endpoints,
      Route_API_Spark,
      Route_API_Info,
      Route_Health,
      Route_Docs,
      Route_Not_Found);

   --  Map a request path to its handler action.
   --  Returns the Route_Kind for the given path. The dashboard is at "/".
   --  The JSON APIs are at "/api/metrics", "/api/deps", "/api/spark",
   --  "/api/info", and the endpoint catalog at "/api/endpoints". The SVG
   --  badge endpoints are at "/badge/*.svg". The health probe is at
   --  "/health". The bundled offline manual is at "/docs" and every
   --  path under "/docs/" (each page, stylesheet, script, and badge of the
   --  bundled Sphinx site). Every other path returns Route_Not_Found.
   --  Routing is pure path routing. The socket dispatch in Handle_Request
   --  switches on the result. The native test suite pins every route.
   --  The function is an expression function: its body is the conditional
   --  mapping, so the implicit postcondition (Result = <mapping>) holds by
   --  definition and the mapping is proved without case-analysis steps.
   --  @param Path  Request path (as extracted by Get_Path).
   --  @return Route_Kind for the path.
   function Route (Path : String) return Route_Kind
   is (if Path = "/"
       then Route_Dashboard
       elsif Path = "/badge/spark.svg"
       then Route_Badge_SPARK
       elsif Path = "/badge/tests.svg"
       then Route_Badge_Tests
       elsif Path = "/badge/do178c.svg"
       then Route_Badge_DO178C
       elsif Path = "/badge/iso26262.svg"
       then Route_Badge_ISO26262
       elsif Path = "/badge/iec62304.svg"
       then Route_Badge_IEC62304
       elsif Path = "/api/metrics"
       then Route_API_Metrics
       elsif Path = "/api/deps"
       then Route_API_Deps
       elsif Path = "/api/endpoints"
       then Route_API_Endpoints
       elsif Path = "/api/spark"
       then Route_API_Spark
       elsif Path = "/api/info"
       then Route_API_Info
       elsif Path = "/health"
       then Route_Health
       elsif Path = "/docs"
       then Route_Docs
       elsif Path'Length >= 6
         and then Path (Path'First .. Path'First + 5) = "/docs/"
       then Route_Docs
       else Route_Not_Found)
   with SPARK_Mode => On, Global => null;

   --  The canonical request path of a route kind, as the server dispatches
   --  it. The mapping is the inverse of Route for every routable kind, so
   --  the native suite pins `Route (Route_Path (K)) = K` over the whole
   --  enumeration. Route_Not_Found is the catch-all bucket of every path
   --  the server does not dispatch on, so its entry is "*".
   --  @param Kind  Route kind to name.
   --  @return The request path, or "*" for the catch-all bucket.
   function Route_Path (Kind : Route_Kind) return String
   is (if Kind = Route_Dashboard
       then "/"
       elsif Kind = Route_Badge_SPARK
       then "/badge/spark.svg"
       elsif Kind = Route_Badge_Tests
       then "/badge/tests.svg"
       elsif Kind = Route_Badge_DO178C
       then "/badge/do178c.svg"
       elsif Kind = Route_Badge_ISO26262
       then "/badge/iso26262.svg"
       elsif Kind = Route_Badge_IEC62304
       then "/badge/iec62304.svg"
       elsif Kind = Route_API_Metrics
       then "/api/metrics"
       elsif Kind = Route_API_Deps
       then "/api/deps"
       elsif Kind = Route_API_Endpoints
       then "/api/endpoints"
       elsif Kind = Route_API_Spark
       then "/api/spark"
       elsif Kind = Route_API_Info
       then "/api/info"
       elsif Kind = Route_Health
       then "/health"
       elsif Kind = Route_Docs
       then "/docs"
       else "*")
   with SPARK_Mode => On, Global => null;

   --  Response counters for one route kind: how many responses the server
   --  sent with a success status and how many with 404.
   type Route_Stats is record
      OK        : Natural := 0;
      Not_Found : Natural := 0;
   end record;

   type Route_Stats_Table is array (Route_Kind) of Route_Stats;

   --  A copy of the live server counters, as /api/info serves them. The
   --  snapshot is copied under the lock, so no lock is held while a socket
   --  send blocks.
   type Runtime_Counts is record
      Requests       : Route_Stats_Table := (others => (0, 0));
      Keep_Alive     : Natural := 0;
      Uptime_Seconds : Natural := 0;
   end record;

   --  The live counters, shared by every worker task. The pool runs
   --  concurrently, so plain shared variables would race on the
   --  increments; the protected store serialises them. The uptime clock
   --  starts at Reset, which Start calls before it accepts a connection.
   protected type Counter_Store is
      --  Clear every counter and start the uptime clock.
      procedure Reset;
      --  Record one dispatched response for a route.
      --  @param Kind   Route the response was sent on.
      --  @param Found  True for a served response, False for a 404.
      procedure Note_Route (Kind : Route_Kind; Found : Boolean);
      --  Record one connection that was served with HTTP keep-alive.
      procedure Note_Keep_Alive;
      --  Copy the counters, reading the uptime clock at call time.
      --  @return The current counters.
      function Snapshot return Runtime_Counts;
   private
      Requests   : Route_Stats_Table := (others => (0, 0));
      Keep_Alive : Natural := 0;
      Started    : Ada.Calendar.Time := Ada.Calendar.Clock;
   end Counter_Store;

   --  The one counter store of this process: the worker tasks update it
   --  and the native tests reset and read it. Its body lives in the package
   --  body (a protected type body is a proper body).
   Counters : Counter_Store;

   --  Strip the query string and fragment off a request path so a URL such
   --  as `/?theme=light` or `/api/deps#top` routes to the same handler as
   --  `/` or `/api/deps`. Browsers append `?query` and `#fragment` to the
   --  path; routing and content negotiation must ignore both. Returns the
   --  path up to (and excluding) the first '?' or '#'.
   --  @param Path  Request path as extracted by Get_Path.
   --  @return The path with any query string (and fragment) removed.
   function Strip_Query (Path : String) return String
   with SPARK_Mode => On, Global => null;

   type Server_State is record
      Port            : Positive := 8080;
      --  HTTP server task-pool worker count (default 4; --serve-workers=N).
      Workers         : Positive := 4;
      Doc_Metrics     : Types.Docstring_Metrics;
      Proof           : Types.Proof_Summary;
      Tests           : Types.Implementation.Test_Summary;
      DAL_Assess      : Types.Implementation.DAL_Assessment;
      Packages        : Types.Implementation.Package_Vectors.Vector;
      Graph           : Types.Implementation.Component_Vectors.Vector;
      All_Standards   : Boolean := False;
      Theme           : Types.Dashboard_Theme := Types.System_Theme;
      --  SPARK proof coverage for the Proof tab panel and /api/spark.
      Spark_OK        : Boolean := False;
      Spark_Totals    : Types.Implementation.Spark_Coverage_Totals;
      Spark_Groups    : Types.Implementation.Spark_Group_Vectors.Vector;
      --  Run metadata for /api/info, all fixed before the server starts.
      --  Target_Path is the audited project and Standard_Target is the
      --  selected compliance standard (All_Standards overrides it to the
      --  joined "all" label).
      Target_Path     : Ada.Strings.Unbounded.Unbounded_String;
      Standard_Target : Types.Compliance_Standard := Types.DO_178C;
      --  Result-cache counters and the wall time of the assessment that
      --  produced the served data, in milliseconds.
      Cache_Hits      : Natural := 0;
      Cache_Misses    : Natural := 0;
      Assessment_MS   : Natural := 0;
   end record;

   --  Render the /api/info payload: the run metadata (bundled version,
   --  audited target, selected standard, port, worker count, result-cache
   --  counters, and assessment time) and the live counters (uptime,
   --  keep-alive connections, and the per-route response counts).
   --  NOTE: Render_Info_JSON is deliberately not SPARK_Mode On, like every
   --  other JSON renderer of Adacovex.Renderers.HTML. It assembles the
   --  server's runtime state with Unbounded_String concatenation, which is
   --  outside the proved surface of this package. Route and Route_Path are
   --  the proved surface here, and the native suite pins both.
   --  @param Target_Path    Audited project path.
   --  @param Standard_Label Selected standard slug, or "all".
   --  @param Version_Text   Bundled adacovex version.
   --  @param Port           Bound port of this server.
   --  @param Workers        Worker count of this server.
   --  @param Counts         Live counters snapshot.
   --  @param Cache_Hits     Results served from the result cache.
   --  @param Cache_Misses   Results recomputed and re-cached.
   --  @param Assessment_MS  Assessment wall time in milliseconds.
   --  @return Pretty-printed JSON object (two-space indent).
   function Render_Info_JSON
     (Target_Path    : String;
      Standard_Label : String;
      Version_Text   : String;
      Port           : Positive;
      Workers        : Positive;
      Counts         : Runtime_Counts;
      Cache_Hits     : Natural;
      Cache_Misses   : Natural;
      Assessment_MS  : Natural) return String
   with Post => Render_Info_JSON'Result'Length > 0, Global => null;

   --  Start the HTTP server (runs until Ctrl+C or socket error).
   --  The server creates a bounded task pool of 4 workers for concurrent
   --  request handling. It supports HTTP/1.1 keep-alive. The server binds to
   --  the configured port. It serves the HTML dashboard, the JSON API, and
   --  the SVG badge endpoints.
   --  @param State  Server configuration and metric data.
   procedure Start (State : Server_State)
   with Pre => State.Port > 0;

end Adacovex.Server.HTTP;
