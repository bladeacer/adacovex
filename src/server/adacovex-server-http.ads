with Adacovex.Types;

--  Multi-threaded HTTP/1.1 server built on GNAT.Sockets.
--  The server uses a bounded Ada task pool for concurrent request handling.
--  The server supports keep-alive connections. It serves the web dashboard,
--  the JSON API, and the SVG badge endpoints.
--  HLR-SERVER: HTTP server

package Adacovex.Server.HTTP is

   --  The action that a request path routes to.  The HTTP server serves the
   --  dashboard, the JSON API, and the SVG badge endpoints. Every other
   --  path returns a 404.
   type Route_Kind is
     (Route_Dashboard,
      Route_Badge_SPARK,
      Route_Badge_Tests,
      Route_Badge_DO178C,
      Route_Badge_ISO26262,
      Route_Badge_IEC62304,
      Route_API_Metrics,
      Route_API_Deps,
      Route_Docs,
      Route_Not_Found);

   --  Map a request path to its handler action.
   --  Returns the Route_Kind for the given path. The dashboard is at "/".
   --  The JSON APIs are at "/api/metrics" and "/api/deps". The SVG badge
   --  endpoints are at "/badge/*.svg". The docs note is at "/docs". Every
   --  other path returns Route_Not_Found.
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
       elsif Path = "/docs"
       then Route_Docs
       else Route_Not_Found)
   with SPARK_Mode => On, Global => null;

   type Server_State is record
      Port          : Positive := 8080;
      --  HTTP server task-pool worker count (default 4; --serve-workers=N).
      Workers       : Positive := 4;
      Doc_Metrics   : Types.Docstring_Metrics;
      Proof         : Types.Proof_Summary;
      Tests         : Types.Implementation.Test_Summary;
      DAL_Assess    : Types.Implementation.DAL_Assessment;
      Packages      : Types.Implementation.Package_Vectors.Vector;
      Graph         : Types.Implementation.Component_Vectors.Vector;
      All_Standards : Boolean := False;
      Theme         : Types.Dashboard_Theme := Types.System_Theme;
   end record;

   --  Start the HTTP server (runs until Ctrl+C or socket error).
   --  The server creates a bounded task pool of 4 workers for concurrent
   --  request handling. It supports HTTP/1.1 keep-alive. The server binds to
   --  the configured port. It serves the HTML dashboard, the JSON API, and
   --  the SVG badge endpoints.
   --  @param State  Server configuration and metric data.
   procedure Start (State : Server_State)
   with Pre => State.Port > 0;

end Adacovex.Server.HTTP;
