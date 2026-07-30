# Adacovex.Renderers.SVG

SVG badge renderer.
Generates Shields.io-style SVG badges for SPARK level, test status,
and DO-178C compliance status.
HLR-RENDER-SVG: SVG badge generation

> **Note:** All items in this package are public.

## Functions

### function Render_DO178C_Badge (Assess : Adacovex.Types.Implementation.DAL_Assessment) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Assess` | DAL assessment record. |

**Returns:** SVG badge markup.

### function Render_Docstring_Badge (Doc_Metrics : Adacovex.Types.Docstring_Metrics) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Doc_Metrics` | Docstring coverage metrics. |

**Returns:** SVG badge markup with coverage percentage.

### function Render_SPARK_Badge (Level : Adacovex.Types.SPARK_Level) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Level` | SPARK certification level. |

**Returns:** SVG badge markup.

### function Render_Tests_Badge (Tests : Adacovex.Types.Implementation.Test_Summary) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Tests` | Test result summary. |

**Returns:** SVG badge markup.

## Procedures

### procedure Write_Badge_To_File (Path : Standard.String; SVG_Content : Standard.String) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `Path` | Filesystem path to write the badge to. |
| `SVG_Content` | SVG markup to write. |
