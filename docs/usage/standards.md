# Compliance standards (DO-178C / ISO 26262 / IEC 62304)

adacovex assesses one safety case and re-labels the result for three
standards. **DO-178C** is the avionics software standard, **ISO 26262** is
the automotive functional-safety standard, and **IEC 62304** is the
medical-device software lifecycle standard.

Each standard ranks its software by the severity of a failure. DO-178C uses
Development Assurance Levels (DAL A to DAL E), ISO 26262 uses Automotive
Safety Integrity Levels (ASIL A to ASIL D, plus QM), and IEC 62304 uses
software safety classes (A to C). The level names differ, but the evidence
does not.

All three standards demand the same four pieces of evidence:

1. **Requirement traceability** -- every high-level requirement (HLR) is
   traced by a `-- HLR-XXXX` tag in source.
2. **No orphan tags** -- every tag in source maps to a defined HLR.
3. **Tests passing** -- the suite has zero failures (except at the lowest
   tier).
4. **Minimum SPARK level** -- the formal-proof bar for the selected rigour
   tier.

adacovex computes these checks once and re-labels the result per standard.
One assessment therefore satisfies every standard at once.

## The pages in this category

- [DO-178C and the DAL levels](standards-do-178c.md) -- the five DAL levels
  and the criteria at each level.
- [ISO 26262 and the ASIL levels](standards-iso-26262.md) -- the ASIL levels
  and the QM classification.
- [IEC 62304 and the safety classes](standards-iec-62304.md) -- the three
  safety classes.
- [Selecting a standard and reading the reports](standards-selection.md) --
  the level flags, `--standard=all`, and the dashboard and SBOM labels.

## When to use which standard

| Domain | Standard | CLI flag | Levels |
|--------|----------|----------|--------|
| Avionics | DO-178C | `--dal=` | A, B, C, D, E |
| Automotive | ISO 26262 | `--asil=` | A, B, C, D, QM |
| Medical | IEC 62304 | `--class=` | A, B, C |

If your project targets several domains, `--standard=all` runs one
assessment and emits badges and reports for every standard without
re-scanning.

## The shared rigour tier

The three standards share one rigour tier. adacovex maps the levels onto
that tier with the default mapping below. The tier placement is a
per-project policy choice, because the standards do not define a one-to-one
correspondence.

| Rigour tier | DO-178C | ISO 26262 | IEC 62304 | Minimum SPARK | Tests | HLRs |
|-------------|---------|-----------|-----------|---------------|-------|------|
| Catastrophic | DAL A | ASIL D | Class C | Gold | Yes | Yes |
| Hazardous | DAL B | ASIL C | Class B | Silver | Yes | Yes |
| Major | DAL C | ASIL B | Class A | Bronze | Yes | Yes |
| Minor | DAL D | ASIL A | -- | Stone | Yes | Yes |
| No safety effect | DAL E | QM | -- | -- | No | Yes |

Use `--standard=NAME` to select the labelling standard, and `--dal=LEVEL`
to pin the shared rigour tier.

## The shared assessment criteria

The four checks are identical across standards. Only the level names change:

1. **Requirement traceability** -- every HLR defined in
   `docs/compliance/HLR.md` is traced by a `-- HLR-XXXX` tag in source.
2. **No orphan tags** -- every in-source HLR tag maps to a defined HLR.
3. **Tests passing** -- zero failures, and the lowest tier does not enforce
   this check.
4. **Minimum SPARK level** -- the proof bar for the selected rigour tier.

The compliance artifacts are identical too. ISO 26262 and IEC 62304 require
no different evidence or documents than DO-178C. The same inputs
(`docs/compliance/HLR.md`, source traceability, the proof summary, and the
test summary) feed the same outputs (`VERIFICATION.md`, `TRACE.md`, the
proof-aware SBOM, and the compliance SVG badges). Only the level label
printed inside them changes.

## See also

- [Selecting a standard and reading the reports](standards-selection.md) --
  the CLI flags, `--standard=all`, and the report labels.
- [Compliance outputs](../compliance/index.md) -- `VERIFICATION.md`,
  `TRACE.md`, and the HLR and LLR indexes.
- [DAL levels](../api-docs/adacovex-dal-levels.md),
  [ASIL levels](../api-docs/adacovex-asil-levels.md), and
  [safety classes](../api-docs/adacovex-class-levels.md) -- the generated
  reference pages.
