# Adacovex.Renderers.SVG

SVG badge renderer.
Generates Shields.io-style SVG badges for SPARK level, test status,
and DO-178C compliance status.
HLR-RENDER-SVG: SVG badge generation

> **Note:** All items in this package are public.

## Functions

### function Render_Compliance_Badge (Assess : Adacovex.Types.Implementation.DAL_Assessment; Standard : Adacovex.Types.Compliance_Standard) return Standard.String `[Post]` `[Global]`

> Render a compliance badge for a specific standard (Achieved / Unmet). Returns SVG markup with the standard's name as the label and its standard-specific level + PASS/FAIL as the value, green for Achieved, red for Unmet.

| Parameter | Description |
|-----------|-------------|
| `Assess` | DAL assessment record (evidence is shared across standards. Only the level label changes). |
| `Standard` | Compliance standard to label the badge with. |

**Returns:** SVG badge markup.

### function Render_DO178C_Badge (Assess : Adacovex.Types.Implementation.DAL_Assessment) return Standard.String `[Post]` `[Global]`

> Render the compliance badge for the standard recorded in the assessment (backwards-compatible convenience wrapper).

| Parameter | Description |
|-----------|-------------|
| `Assess` | DAL assessment record. |

**Returns:** SVG badge markup.

### function Render_Docstring_Badge (Doc_Metrics : Adacovex.Types.Docstring_Metrics) return Standard.String `[Post]` `[Global]`

> Render a docstring-coverage badge showing documented percentage.

| Parameter | Description |
|-----------|-------------|
| `Doc_Metrics` | Docstring coverage metrics. |

**Returns:** SVG badge markup with coverage percentage.

### function Render_SPARK_Badge (Level : Adacovex.Types.SPARK_Level) return Standard.String `[Post]` `[Global]`

> Render a SPARK-level badge (Stone/Bronze/Silver/Gold/Platinum). Returns SVG markup for a Shields.io-style badge with the SPARK level as the label and the level name as the value, colour-coded by level.

| Parameter | Description |
|-----------|-------------|
| `Level` | SPARK certification level. |

**Returns:** SVG badge markup.

### function Render_Tests_Badge (Tests : Adacovex.Types.Implementation.Test_Summary) return Standard.String `[Post]` `[Global]`

> Render a test-status badge showing passed / failed counts. Returns SVG markup showing the total test count and pass/fail breakdown.

| Parameter | Description |
|-----------|-------------|
| `Tests` | Test result summary. |

**Returns:** SVG badge markup.

## Procedures

### procedure Write_Badge_To_File (Path : Standard.String; SVG_Content : Standard.String) `[Pre]`

> Write raw SVG text to a file at the given path. Creates or overwrites the file at Path with SVG_Content as the body.

| Parameter | Description |
|-----------|-------------|
| `Path` | Filesystem path to write the badge to. |
| `SVG_Content` | SVG markup to write. |
