# Adacovex.Renderers.ANSI

Terminal ANSI renderer.
Produces a coloured, human-readable report on standard output using
ANSI escape sequences for highlighting. Supports NO_COLOR and
non-interactive terminal detection.
HLR-RENDER-ANSI: ANSI rendering

> **Note:** All items in this package are public.

## Procedures

### procedure Render_Summary (Doc_Metrics : Adacovex.Types.Docstring_Metrics; Proof : Adacovex.Types.Proof_Summary; Tests : Adacovex.Types.Implementation.Test_Summary; DAL_Assess : Adacovex.Types.Implementation.DAL_Assessment; Packages : Adacovex.Types.Implementation.Package_Vectors.Vector; Use_Color : Standard.Boolean; All_Standards : Standard.Boolean; Cache_Hits : Standard.Natural; Cache_Misses : Standard.Natural; Cache_Evictions : Standard.Natural)

| Parameter | Description |
|-----------|-------------|
| `All_Standards` | Print every standard (else the selected one). |
| `Cache_Evictions` | Number of stale entries evicted from the cache. |
| `Cache_Hits` | Number of analysis results served from the cache. |
| `Cache_Misses` | Number of results recomputed and re-cached. |
| `DAL_Assess` | DAL compliance assessment. |
| `Doc_Metrics` | Docstring coverage metrics. |
| `Packages` | Scanned package vector. |
| `Proof` | GNATprove proof summary. |
| `Tests` | Test result summary. |
| `Use_Color` | Enable ANSI colour output (default False). |
