with Adacovex.Test_Support;
with Adacovex.Server.HTTP;
use Adacovex.Server.HTTP;

package body Adacovex_Server_Tests is

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
   begin
      --  The seven literal routes the server dispatches on.  Route is the
      --  pure path-to-action mapping behind Handle_Request's case statement
      --  (LLR-SERVER-01's dashboard / API / badge surface), so every route
      --  the socket handler can serve is pinned here.
      R.Check (Route ("/") = Route_Dashboard, "dashboard route");
      R.Check
        (Route ("/badge/spark.svg") = Route_Badge_SPARK,
         "spark badge route");
      R.Check
        (Route ("/badge/tests.svg") = Route_Badge_Tests,
         "tests badge route");
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
        (Route ("/api/metrics") = Route_API_Metrics,
         "metrics API route");

      --  Unknown paths are 404s: empty, near-misses of every literal route
      --  (case, trailing slash, wrong extension, prefix, suffix, query
      --  string), and arbitrary URLs.
      R.Check (Route ("") = Route_Not_Found, "empty path is not found");
      R.Check
        (Route ("/index.html") = Route_Not_Found,
         "index.html is not found");
      R.Check
        (Route ("/favicon.ico") = Route_Not_Found,
         "favicon.ico is not found");
      R.Check
        (Route ("/badge") = Route_Not_Found, "/badge alone is not found");
      R.Check
        (Route ("/badge/") = Route_Not_Found, "/badge/ is not found");
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
      R.Check
        (Route ("/api") = Route_Not_Found, "/api alone is not found");
      R.Check
        (Route ("/api/metrics/") = Route_Not_Found,
         "trailing slash on metrics is not found");
      R.Check
        (Route ("/api/metric") = Route_Not_Found,
         "metrics prefix is not found");
      R.Check
        (Route ("/healthz") = Route_Not_Found,
         "health check path is not found");
      R.Check
        (Route ("//") = Route_Not_Found, "double slash is not found");
      R.Check
        (Route ("/../") = Route_Not_Found, "dot-dot path is not found");
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
         and then Route ("/api/metrics") /= Route_Not_Found,
         "all seven served routes are non-404");
   end Run;

end Adacovex_Server_Tests;
