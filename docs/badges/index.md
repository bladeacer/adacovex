# Badges

This directory holds the SVG badges that adacovex renders for a target.
`make run-self` and `make prove` regenerate them from the current
assessment.

## Badge set

| File | Badge | Meaning |
|------|-------|---------|
| [spark.svg](spark.svg) | SPARK level | the target's proof level (Platinum for adacovex itself) |
| [tests.svg](tests.svg) | tests | native test pass count |
| [do178c.svg](do178c.svg) | DO-178C | the DAL assessment badge |
| [iso26262.svg](iso26262.svg) | ISO 26262 | the ASIL assessment badge |
| [iec62304.svg](iec62304.svg) | IEC 62304 | the safety-class assessment badge |
| [docs.svg](docs.svg) | docstring coverage | the percentage of documented subprograms |

## How to regenerate

```bash
make prove     # SPARK proof + badges for adacovex itself
make run-self   # full self-assessment + badges
```

The SVG renderer is documented in the
[API reference](../api-docs/adacovex-renderers-svg.md).  Badge fields,
colours, and shapes are part of the renderer contract; see the
[renderer tests](../api-docs/adacovex_renderer_svg_tests.md) for the
exact expectations.

Badge text uses British English and ASD-STE100 Simplified Technical
English.  Technical terms follow the [STE100 Technical Names
dictionary](../contributing/ste100-technical-names.md).