# Adacovex.Server.HTTP

Multi-threaded HTTP/1.1 server built on GNAT.Sockets.
The server uses a bounded Ada task pool for concurrent request handling.
The server supports keep-alive connections. It serves the web dashboard,
the JSON API, and the SVG badge endpoints.
HLR-SERVER: HTTP server

**See also:** [Web dashboard](../usage/dashboard.md)

> **Note:** All items in this package are public.

## Types

### type Counter_Store

```ada
   protected type Counter_Store is
```

> Clear every counter and start the uptime clock.

**Public Operations:**

#### procedure Reset

```ada
      procedure Reset;
```

Clear every counter and start the uptime clock.

#### procedure Note_Route

```ada
      procedure Note_Route (Kind : Route_Kind; Found : Boolean);
```

Record one dispatched response for a route.

| Parameter | Description |
|-----------|-------------|
| `Found` | True for a served response, False for a 404. |
| `Kind` | Route the response was sent on. |

#### procedure Note_Keep_Alive

```ada
      procedure Note_Keep_Alive;
```

Record one connection that was served with HTTP keep-alive.

#### function Snapshot

```ada
      function Snapshot return Runtime_Counts;
```

Copy the counters, reading the uptime clock at call time.

**Returns:** The current counters.

**Private State:**

- `Requests   : Route_Stats_Table := (others => (0, 0));`
- `Keep_Alive : Natural := 0;`
- `Started    : Ada.Calendar.Time := Ada.Calendar.Clock;`
```ada
end Counter_Store;
```

### type Route_Kind

```ada
type Route_Kind is
(Route_Dashboard,
Route_Badge_SPARK,
Route_Badge_Tests,
Route_Badge_DO178C,
Route_Badge_ISO26262,
Route_Badge_IEC62304,
Route_API_Metrics,
Route_API_Deps,
...,
Route_Not_Found);
```

> The action that a request path routes to. The HTTP server serves the dashboard, the JSON API, the SVG badge endpoints, the server-info payload, the health probe, and the bundled offline manual (every path under /docs/). Every other path returns a 404.

### type Route_Stats

```ada
type Route_Stats is record
OK        : Natural := 0;
Not_Found : Natural := 0;
end record;
```

> Response counters for one route kind: how many responses the server sent with a success status and how many with 404.

### type Route_Stats_Table

```ada
type Route_Stats_Table is array (Route_Kind) of Route_Stats;
```

> One response counter per route kind.

### type Runtime_Counts

```ada
type Runtime_Counts is record
Requests       : Route_Stats_Table := (others => (0, 0));
Keep_Alive     : Natural := 0;
Uptime_Seconds : Natural := 0;
end record;
```

> A copy of the live server counters, as /api/info serves them. The snapshot is copied under the lock, so no lock is held while a socket send blocks.

### type Server_State

```ada
type Server_State is record
Port            : Positive := 8080;
Workers         : Positive := 4;
Doc_Metrics     : Types.Docstring_Metrics;
Proof           : Types.Proof_Summary;
Tests           : Types.Implementation.Test_Summary;
DAL_Assess      : Types.Implementation.DAL_Assessment;
Packages        : Types.Implementation.Package_Vectors.Vector;
Graph           : Types.Implementation.Component_Vectors.Vector;
All_Standards   : Boolean := False;
Theme           : Types.Dashboard_Theme := Types.System_Theme;
Watching        : Boolean := True;
Spark_OK        : Boolean := False;
Spark_Totals    : Types.Implementation.Spark_Coverage_Totals;
Spark_Groups    : Types.Implementation.Spark_Group_Vectors.Vector;
Target_Path     : Ada.Strings.Unbounded.Unbounded_String;
Standard_Target : Types.Compliance_Standard := Types.DO_178C;
Cache_Hits      : Natural := 0;
Cache_Misses    : Natural := 0;
Assessment_MS   : Natural := 0;
end record;
```

> Everything the worker tasks need to answer a request: the assessed metrics, the dependency graph, the theme, and the run metadata.

## Functions

### function Render_Info_JSON (Target_Path : Standard.String; Standard_Label : Standard.String; Version_Text : Standard.String; Port : Standard.Positive; Workers : Standard.Positive; Counts : Adacovex.Server.HTTP.Runtime_Counts; Cache_Hits : Standard.Natural; Cache_Misses : Standard.Natural; Assessment_MS : Standard.Natural) return Standard.String `[Post]` `[Global]`

> Render the /api/info payload: the run metadata (bundled version, audited target, selected standard, port, worker count, result-cache counters, and assessment time) and the live counters (uptime, keep-alive connections, and the per-route response counts). NOTE: Render_Info_JSON is deliberately not SPARK_Mode On, like every other JSON renderer of Adacovex.Renderers.HTML. It assembles the server's runtime state with Unbounded_String concatenation, which is outside the proved surface of this package. Route and Route_Path are the proved surface here, and the native suite pins both.

| Parameter | Description |
|-----------|-------------|
| `Assessment_MS` | Assessment wall time in milliseconds. |
| `Cache_Hits` | Results served from the result cache. |
| `Cache_Misses` | Results recomputed and re-cached. |
| `Counts` | Live counters snapshot. |
| `Port` | Bound port of this server. |
| `Standard_Label` | Selected standard slug, or "all". |
| `Target_Path` | Audited project path. |
| `Version_Text` | Bundled adacovex version. |
| `Workers` | Worker count of this server. |

**Returns:** Pretty-printed JSON object (two-space indent).

### function Render_Watch_JSON (Watching : Standard.Boolean; Generation : Standard.Natural) return Standard.String `[Post]` `[Global]`

> Render the /api/watch payload: whether the server watches the target, and the generation of the latest document-metric refresh. A browser polls this and reloads the page when the generation moves.

| Parameter | Description |
|-----------|-------------|
| `Generation` | Refresh counter, incremented on every change. |
| `Watching` | True when watch mode is on. |

**Returns:** JSON object on one line.

### function Route (Path : Standard.String) return Adacovex.Server.HTTP.Route_Kind `[Global]` `[SPARK]`

> Map a request path to its handler action. Returns the Route_Kind for the given path. The dashboard is at "/". The JSON APIs are at "/api/metrics", "/api/deps", "/api/spark", "/api/info", and the endpoint catalog at "/api/endpoints". The SVG badge endpoints are at "/badge/*.svg". The health probe is at "/health". The bundled offline manual is at "/docs" and every path under "/docs/" (each page, stylesheet, script, and badge of the bundled Sphinx site). Every other path returns Route_Not_Found. Routing is pure path routing. The socket dispatch in Handle_Request switches on the result. The native test suite pins every route. The function is an expression function: its body is the conditional mapping, so the implicit postcondition (Result = <mapping>) holds by definition and the mapping is proved without case-analysis steps.

| Parameter | Description |
|-----------|-------------|
| `Path` | Request path (as extracted by Get_Path). |

**Returns:** Route_Kind for the path.

### function Route_Path (Kind : Adacovex.Server.HTTP.Route_Kind) return Standard.String `[Global]` `[SPARK]`

> The canonical request path of a route kind, as the server dispatches it. The mapping is the inverse of Route for every routable kind, so the native suite pins `Route (Route_Path (K)) = K` over the whole enumeration. Route_Not_Found is the catch-all bucket of every path the server does not dispatch on, so its entry is "*".

| Parameter | Description |
|-----------|-------------|
| `Kind` | Route kind to name. |

**Returns:** The request path, or "*" for the catch-all bucket.

### function Strip_Query (Path : Standard.String) return Standard.String `[Global]` `[SPARK]`

> Strip the query string and fragment off a request path so a URL such as `/?theme=light` or `/api/deps#top` routes to the same handler as `/` or `/api/deps`. Browsers append `?query` and `#fragment` to the path; routing and content negotiation must ignore both. Returns the path up to (and excluding) the first '?' or '#'.

| Parameter | Description |
|-----------|-------------|
| `Path` | Request path as extracted by Get_Path. |

**Returns:** The path with any query string (and fragment) removed.

### function Watch_Generation return Standard.Natural

> The current watch generation: 0 before the first refresh. The native suite and the /api/watch handler read it.

**Returns:** The refresh counter.

## Procedures

### procedure Start (State : Adacovex.Server.HTTP.Server_State) `[Pre]`

> Start the HTTP server (runs until Ctrl+C or socket error). The server creates a bounded task pool of 4 workers for concurrent request handling. It supports HTTP/1.1 keep-alive. The server binds to the configured port. It serves the HTML dashboard, the JSON API, and the SVG badge endpoints.

| Parameter | Description |
|-----------|-------------|
| `State` | Server configuration and metric data. |
