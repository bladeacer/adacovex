# Adacovex.Renderers.ANSI

Terminal ANSI renderer.
Produces a coloured, human-readable report on standard output using
ANSI escape sequences for highlighting. Supports NO_COLOR and
non-interactive terminal detection.
HLR-RENDER-ANSI: ANSI rendering

> **Note:** All items in this package are public.

## Procedures

### procedure Render_Summary (Doc_Metrics : Adacovex.Types.Docstring_Metrics; Proof : Adacovex.Types.Proof_Summary; Tests : Adacovex.Types.Test_Summary; DAL_Assess : Adacovex.Types.DAL_Assessment; Packages : Adacovex.Types.Package_Vectors.Vector; Use_Color : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `DAL_Assess` | DAL compliance assessment. |
| `Doc_Metrics` | Docstring coverage metrics. |
| `Packages` | Scanned package vector. |
| `Proof` | GNATprove proof summary. |
| `Tests` | Test result summary. |
| `Use_Color` | Enable ANSI color output (default False). |
