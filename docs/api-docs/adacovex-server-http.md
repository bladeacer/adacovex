# Adacovex.Server.HTTP

Multi-threaded HTTP/1.1 server built on GNAT.Sockets.
Uses a bounded Ada task pool for concurrent request handling.
Supports keep-alive connections and serves the web dashboard,
JSON API, and SVG badge endpoints.
HLR-SERVER: HTTP server

> **Note:** All items in this package are public.

## Types

### type Server_State

```ada
type Server_State is record
Port        : Positive := 8080;
Doc_Metrics : Types.Docstring_Metrics;
Proof       : Types.Proof_Summary;
Tests       : Types.Implementation.Test_Summary;
DAL_Assess  : Types.Implementation.DAL_Assessment;
Packages    : Types.Implementation.Package_Vectors.Vector;
Running     : Boolean := False;
end record;
```

## Procedures

### procedure Start (State : Adacovex.Server.HTTP.Server_State) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `State` | Server configuration and metric data. |
