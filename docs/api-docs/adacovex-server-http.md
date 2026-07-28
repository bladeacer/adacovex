# Adacovex.Server.HTTP

Lightweight HTTP/1.1 server built on GNAT.Sockets.
Serves the web dashboard, JSON API, and SVG badge endpoints.
HLR-SERVER: HTTP server

> **Note:** All items in this package are public.

## Types

### type Server_State

```ada
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
```

## Procedures

### procedure Start (State : Adacovex.Server.HTTP.Server_State) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `State` | Server configuration and metric data. |
