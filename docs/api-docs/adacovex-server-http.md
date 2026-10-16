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

### type Route_Stats

```ada
type Route_Stats is record
OK        : Natural := 0;
Not_Found : Natural := 0;
end record;
```

### type Route_Stats_Table

```ada
type Route_Stats_Table is array (Route_Kind) of Route_Stats;
```

### type Runtime_Counts

```ada
type Runtime_Counts is record
Requests       : Route_Stats_Table := (others => (0, 0));
Keep_Alive     : Natural := 0;
Uptime_Seconds : Natural := 0;
end record;
```

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

## Functions

### function Render_Info_JSON (Target_Path : Standard.String; Standard_Label : Standard.String; Version_Text : Standard.String; Port : Standard.Positive; Workers : Standard.Positive; Counts : Adacovex.Server.HTTP.Runtime_Counts; Cache_Hits : Standard.Natural; Cache_Misses : Standard.Natural; Assessment_MS : Standard.Natural) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Assessment_MS` |  |
| `Cache_Hits` |  |
| `Cache_Misses` |  |
| `Counts` |  |
| `Port` |  |
| `Standard_Label` |  |
| `Target_Path` |  |
| `Version_Text` |  |
| `Workers` |  |

### function Route (Path : Standard.String) return Adacovex.Server.HTTP.Route_Kind `[Global]` `[SPARK]`

| Parameter | Description |
|-----------|-------------|
| `Path` |  |

### function Route_Path (Kind : Adacovex.Server.HTTP.Route_Kind) return Standard.String `[Global]` `[SPARK]`

| Parameter | Description |
|-----------|-------------|
| `Kind` |  |

### function Strip_Query (Path : Standard.String) return Standard.String `[Global]` `[SPARK]`

| Parameter | Description |
|-----------|-------------|
| `Path` |  |

## Procedures

### procedure Start (State : Adacovex.Server.HTTP.Server_State) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `State` |  |
