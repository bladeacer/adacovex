with Adacovex.Types;

--  Multi-threaded HTTP/1.1 server built on GNAT.Sockets.
--  Uses a bounded Ada task pool for concurrent request handling.
--  Supports keep-alive connections and serves the web dashboard,
--  JSON API, and SVG badge endpoints.
--  HLR-SERVER: HTTP server

package Adacovex.Server.HTTP is

   type Server_State is record
      Port          : Positive := 8080;
      Doc_Metrics   : Types.Docstring_Metrics;
      Proof         : Types.Proof_Summary;
      Tests         : Types.Implementation.Test_Summary;
      DAL_Assess    : Types.Implementation.DAL_Assessment;
      Packages      : Types.Implementation.Package_Vectors.Vector;
      All_Standards : Boolean := False;
      Theme         : Types.Dashboard_Theme := Types.System_Theme;
   end record;

   --  Start the HTTP server (runs until Ctrl+C or socket error).
   --  Creates a bounded task pool of 4 workers for concurrent request
   --  handling with HTTP/1.1 keep-alive support. Binds to the configured
   --  port and serves the HTML dashboard, JSON API, and SVG badge endpoints.
   --  @param State  Server configuration and metric data.
   procedure Start (State : Server_State)
   with Pre => State.Port > 0;

end Adacovex.Server.HTTP;
