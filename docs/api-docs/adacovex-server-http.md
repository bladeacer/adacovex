# Adacovex.Server.HTTP

Multi-threaded HTTP/1.1 server built on GNAT.Sockets.
The server uses a bounded Ada task pool for concurrent request handling.
The server supports keep-alive connections. It serves the web dashboard,
the JSON API, and the SVG badge endpoints.
HLR-SERVER: HTTP server

**See also:** [Web dashboard](../dashboard.md)

> **Note:** All items in this package are public.

## Types

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
Route_Docs,
Route_Not_Found);
```

### type Server_State

```ada
type Server_State is record
Port          : Positive := 8080;
Doc_Metrics   : Types.Docstring_Metrics;
Proof         : Types.Proof_Summary;
Tests         : Types.Implementation.Test_Summary;
DAL_Assess    : Types.Implementation.DAL_Assessment;
Packages      : Types.Implementation.Package_Vectors.Vector;
Graph         : Types.Implementation.Component_Vectors.Vector;
All_Standards : Boolean := False;
Theme         : Types.Dashboard_Theme := Types.System_Theme;
end record;
```

## Functions

### function Route (Path : Standard.String) return Adacovex.Server.HTTP.Route_Kind `[Global]` `[SPARK]`

| Parameter | Description |
|-----------|-------------|
| `Path` |  |

## Procedures

### procedure Start (State : Adacovex.Server.HTTP.Server_State) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `State` |  |
