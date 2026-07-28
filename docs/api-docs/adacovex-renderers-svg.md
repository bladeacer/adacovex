# Adacovex.Renderers.SVG

Render a SPARK-level badge (Stone/Bronze/Silver/Gold/Platinum).
Returns SVG markup for a Shields.io-style badge with the SPARK level
as the label and the level name as the value, colour-coded by level.
@param Level  SPARK certification level.
@return SVG badge markup.

> **Note:** All items in this package are public.

## Functions

### function Render_DO178C_Badge (Assess : Adacovex.Types.DAL_Assessment) return Standard.String `[Post]` `[Global]`

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

### function Render_Tests_Badge (Tests : Adacovex.Types.Test_Summary) return Standard.String `[Post]` `[Global]`

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
