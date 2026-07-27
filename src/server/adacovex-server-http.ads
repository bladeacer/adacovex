with Adacovex.Types;
with Adacovex.Config;

--  Lightweight HTTP/1.1 server built on GNAT.Sockets.
--  Serves the web dashboard, JSON API, and SVG badge endpoints.
--  HLR-SERVER: HTTP server

package Adacovex.Server.HTTP is
   pragma SPARK_Mode (On);

   type Server_State is record
      Port        : Positive := 8080;
      Doc_Metrics : Types.Docstring_Metrics;
      Proof       : Types.Proof_Summary;
      Tests       : Types.Test_Summary;
      DAL_Assess  : Types.DAL_Assessment;
      Packages    : Types.Package_Array;
      Pkg_Count   : Natural;
      Running     : Boolean := False;
   end record;

   --  Start the HTTP server loop (blocks until error or Ctrl+C).
   --  Binds to the configured port, accepts HTTP/1.1 requests, and serves
   --  the HTML dashboard, JSON API, and SVG badge endpoints. Runs until
   --  a fatal socket error or external interrupt.
   procedure Start (State : Server_State)
     with Pre => State.Port > 0;

end Adacovex.Server.HTTP;
