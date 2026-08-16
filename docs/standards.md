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

Because the checks are shared, **the compliance artifacts are identical too**:
ISO 26262 and IEC 62304 require no different evidence or documents than
DO-178C. The same inputs (`HLR.md`, source traceability, proof summary, test
summary) feed the same outputs (`VERIFICATION.md`, `TRACE.md`, the
proof-aware SBOM, and the compliance SVG badges) for every standard -- only
the integrity-level label printed inside them changes (`DAL-C`, `ASIL B`,
`Class A`).

## Selecting a standard on the CLI

Each standard has a dedicated level flag, so your intent is unambiguous on the
command line. The flags all resolve to the same shared rigor tier:

| Standard | Flag | Levels | Example (tier) |
|----------|------|--------|----------------|
| DO-178C | `--dal=` | A, B, C, D, E | `--dal=C` -> DAL-C (Major) |
| ISO 26262 | `--asil=` | A, B, C, D, QM | `--asil=B` -> ASIL B (Major) |
| IEC 62304 | `--class=` | A, B, C | `--class=A` -> Class A (Major) |

You can also use `--standard=iso26262 --dal=C` to get the same result as
`--asil=B`; the dedicated flags exist so a reader of the command line can see
"ASIL B" (or "Class A") without decoding the shared tier.

`--standard=all` runs **one** assessment at the shared tier and emits badges
and reports for **every** standard -- `do178c.svg`, `iso26262.svg`, and
`iec62304.svg` -- without re-scanning, re-proving, or re-parsing anything. The
evidence is identical across standards, so the three badges always agree on
Achieved/Unmet; only the level label changes.

## SBOM standard-awareness

The proof-aware SBOM records the assessment standard and its native level
label, so a CycloneDX / SPDX / Markdown consumer sees the right name for the
selected standard:

| `--` flag | `adacovex:standard` | `adacovex:level` |
|-----------|---------------------|------------------|
| `--dal=C` | `DO-178C` | `DAL-C` |
| `--asil=B` | `ISO 26262` | `ASIL B` |
| `--class=A` | `IEC 62304` | `Class A` |
| `--standard=all` | `DO-178C, ISO 26262, IEC 62304` | `DAL-C / ASIL B / Class A` |

The `adacovex:dal_target` property always carries the shared tier (`DAL-A`..
`DAL-D`) regardless of the labelling standard; `--standard=all` joins all
three standard names and level labels into the single `adacovex:standard` and
`adacovex:level` properties so one document carries every standard's
assessment.

## Implementation

- `Compliance_Standard` type (`DO_178C`, `ISO_26262`, `IEC_62304`) with
  `To_String` / `To_Standard` / `Standard_Slug` conversions and the
  dedicated `To_ASIL` / `To_Class` level parsers in `Adacovex.Types`.
- `--standard=NAME` CLI flag (default `do178c`, plus `all`) selects the
  labelling standard; `--dal=LEVEL` is the shared rigor tier (A--E), and the
  dedicated `--asil=LEVEL` / `--class=LEVEL` flags set both the standard and
  the tier in one step.
- `Types.Standard_Level_Name` maps a standard + tier to its label (`DAL-C`,
  `ASIL B`, `Class A`, ...), and `Assess_Standard` runs the same evidence
  checks as `Assess_DAL` while recording the standard, so every renderer
  (ANSI report, SVG badge, HTML dashboard, JSON API, Markdown report, and
  SBOM) prints the standard-specific level without re-running scanning, proof
  parsing, or test parsing.
- `Min_SPARK_For` still drives the per-tier proof bar; the tiers share one
  lookup because the standards only re-label the levels.

Each standard has a dedicated reference page with its level definitions and
criteria:

- [DO-178C DAL levels](api-docs/adacovex-dal-levels.md)
- [ISO 26262 ASIL levels](api-docs/adacovex-asil-levels.md)
- [IEC 62304 safety classes](api-docs/adacovex-class-levels.md)
