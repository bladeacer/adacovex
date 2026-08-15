# Compliance Standards (DO-178C / ISO 26262 / IEC 62304)

adacovex's default assessment targets DO-178C (avionics). The 1.10.0 feature
set generalizes the compliance model so one assessment can satisfy the
functionally equivalent safety standards for **aviation** (DO-178C),
**automotive** (ISO 26262), and **medical devices** (IEC 62304) at the same
time.

## Why one abstraction

All three standards demand the same underlying evidence, only the names of the
integrity levels differ:

- **DO-178C** -- Development Assurance Levels **DAL A--E** (avionics software).
- **ISO 26262** -- Automotive Safety Integrity Levels **ASIL A--D** plus **QM**
  (road-vehicle functional safety).
- **IEC 62304** -- software safety classes **A, B, C** (medical-device
  software lifecycle).

Each level maps to a required rigor of verification: a minimum formal-proof
bar (SPARK level), a passing test suite, and complete requirement traceability
(HLR coverage, no orphan tags). adacovex already computes all of that
evidence; the abstraction only re-labels the assessment per standard.

## Rigor-tier mapping

| Rigor tier | DO-178C | ISO 26262 | IEC 62304 | Min SPARK | Tests | HLRs |
|------------|---------|-----------|-----------|-----------|-------|------|
| Catastrophic | DAL A | ASIL D | Class C | Gold | Yes | Yes |
| Hazardous | DAL B | ASIL C | Class B | Silver | Yes | Yes |
| Major | DAL C | ASIL B | Class A | Bronze | Yes | Yes |
| Minor | DAL D | ASIL A | -- | Stone | Yes | Yes |
| No safety effect | DAL E | QM | -- | -- | No | Yes |

The exact tier placement of each standard's levels is a per-project policy
choice (the standards do not define a one-to-one correspondence). The table
above is adacovex's default mapping; `--standard=NAME` selects the labelling
standard and `--dal=LEVEL` pins the shared rigor tier (see
[Implementation](#implementation)).

## Assessment criteria (shared)

The four checks stay identical across standards; only the names change:

1. **Requirement traceability** -- every HLR defined in
   `docs/compliance/HLR.md` is traced by a `-- HLR-XXXX` tag in source.
2. **No orphan tags** -- every in-source HLR maps to a defined HLR.
3. **Tests passing** -- zero failures (not enforced at the lowest tier).
4. **Minimum SPARK level** -- the proof bar for the selected rigor tier.

## Implementation

- `Compliance_Standard` type (`DO_178C`, `ISO_26262`, `IEC_62304`) with
  `To_String` / `To_Standard` conversions in `Adacovex.Types`.
- `--standard=NAME` CLI flag (default `do178c`) selects the labelling
  standard; `--dal=LEVEL` is reused as the shared rigor tier (A--E), so
  `--standard=iso26262 --dal=C` assesses ASIL B.
- `Types.Standard_Level_Name` maps a standard + tier to its label (`DAL-C`,
  `ASIL B`, `Class A`, ...), and `Assess_Standard` runs the same evidence
  checks as `Assess_DAL` while recording the standard, so the ANSI report and
  SVG badge print the standard-specific level without re-running scanning,
  proof parsing, or test parsing.
- `Min_SPARK_For` still drives the per-tier proof bar; the tiers share one
  lookup because the standards only re-label the levels.

See [DAL levels](api-docs/adacovex-dal-levels.md) for the existing DO-178C
criteria that the abstraction generalizes.
