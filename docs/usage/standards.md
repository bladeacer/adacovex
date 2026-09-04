# Compliance Standards (DO-178C / ISO 26262 / IEC 62304)

## What are these standards?

**DO-178C** is the avionics software standard. It defines how to design,
implement, verify, and certify software that flies airplanes. Every line of
safety-critical flight software is assessed at one of five **DAL** (Development
Assurance Level) tiers, from **DAL-E** (no safety effect) to **DAL-A**
(catastrophic failure can bring down the aircraft).

**ISO 26262** is the automotive functional-safety standard. It applies the same
rigor to road-vehicle software (braking, steering, powertrain). Its integrity
levels are called **ASIL** (Automotive Safety Integrity Level), from **QM**
(quality management, no hazard) to **ASIL D** (highest hazard).

**IEC 62304** is the medical-device software lifecycle standard. It classifies
software into **safety classes** A, B, and C based on the severity of harm a
failure can cause.

All three demand the same underlying evidence:

1. **Requirement traceability** -- every high-level requirement (HLR) is traced
   by a `-- HLR-XXXX` tag in source.
2. **No orphan tags** -- every tag in source maps to a defined HLR.
3. **Tests passing** -- the test suite has zero failures (except at the lowest
   tier).
4. **Minimum SPARK level** -- the formal-proof bar for the selected rigor tier.

adacovex computes all four checks once and re-labels the result per standard.
The same inputs feed the same outputs. Only the integrity-level label changes.

## When to use which standard

| Domain | Standard | CLI flag | Levels |
|--------|----------|----------|--------|
| Avionics | DO-178C | `--dal=` | A, B, C, D, E |
| Automotive | ISO 26262 | `--asil=` | A, B, C, D, QM |
| Medical | IEC 62304 | `--class=` | A, B, C |

If your project targets multiple domains, `--standard=all` runs one assessment
and emits badges and reports for every standard without re-scanning.

## What the rigor tiers mean

| Rigor tier | DO-178C | ISO 26262 | IEC 62304 | Min SPARK | Tests | HLRs |
|------------|---------|-----------|-----------|-----------|-------|------|
| Catastrophic | DAL A | ASIL D | Class C | Gold | Yes | Yes |
| Hazardous | DAL B | ASIL C | Class B | Silver | Yes | Yes |
| Major | DAL C | ASIL B | Class A | Bronze | Yes | Yes |
| Minor | DAL D | ASIL A | -- | Stone | Yes | Yes |
| No safety effect | DAL E | QM | -- | -- | No | Yes |

The tier placement is a per-project policy choice. The standards do not define a
one-to-one correspondence. adacovex's default mapping is shown above. Use
`--standard=NAME` to select the labelling standard. Use `--dal=LEVEL` to pin
the shared rigor tier.

## Rigor-tier mapping

| Rigor tier | DO-178C | ISO 26262 | IEC 62304 | Min SPARK | Tests | HLRs |
|------------|---------|-----------|-----------|-----------|-------|------|
| Catastrophic | DAL A | ASIL D | Class C | Gold | Yes | Yes |
| Hazardous | DAL B | ASIL C | Class B | Silver | Yes | Yes |
| Major | DAL C | ASIL B | Class A | Bronze | Yes | Yes |
| Minor | DAL D | ASIL A | -- | Stone | Yes | Yes |
| No safety effect | DAL E | QM | -- | -- | No | Yes |

The exact tier placement of each standard's levels is a per-project policy
choice. The standards do not define a one-to-one correspondence. The table
above is adacovex's default mapping. `--standard=NAME` selects the labelling
standard. `--dal=LEVEL` pins the shared rigor tier (see
[Implementation](#implementation)).

## Assessment criteria (shared)

The four checks stay identical across standards. Only the names change:

1. **Requirement traceability** -- every HLR defined in
   `docs/compliance/HLR.md` is traced by a `-- HLR-XXXX` tag in source.
2. **No orphan tags** -- every in-source HLR maps to a defined HLR.
3. **Tests passing** -- zero failures (not enforced at the lowest tier).
4. **Minimum SPARK level** -- the proof bar for the selected rigor tier.

Because the checks are shared, **the compliance artifacts are identical too**:
ISO 26262 and IEC 62304 require no different evidence or documents than
DO-178C. The same inputs (`compliance/HLR.md`, source traceability, proof summary, test
summary) feed the same outputs (`VERIFICATION.md`, `TRACE.md`, the
proof-aware SBOM, and the compliance SVG badges) for every standard. Only the
integrity-level label printed inside them changes (`DAL-C`, `ASIL B`,
`Class A`).

## Selecting a standard on the CLI

Each standard has a dedicated level flag, so your intent is unambiguous on the
command line (full flag details in the
[CLI reference](cli-reference.md)). The flags all resolve to the same shared
rigor tier:

| Standard | Flag | Levels | Example (tier) |
|----------|------|--------|----------------|
| DO-178C | `--dal=` | A, B, C, D, E | `--dal=C` -> DAL-C (Major) |
| ISO 26262 | `--asil=` | A, B, C, D, QM | `--asil=B` -> ASIL B (Major) |
| IEC 62304 | `--class=` | A, B, C | `--class=A` -> Class A (Major) |

You can also use `--standard=iso26262 --dal=C` to get the same result as
`--asil=B`. The dedicated flags exist so a reader of the command line can see
"ASIL B" (or "Class A") without decoding the shared tier.

`--standard=all` runs **one** assessment at the shared tier and emits badges
and reports for **every** standard -- `do178c.svg`, `iso26262.svg`, and
`iec62304.svg` -- without re-scanning, re-proving, or re-parsing anything. The
evidence is identical across standards. The three badges therefore always
agree on Achieved/Unmet. Only the level label changes.

## Dashboard and SBOM standard-awareness

The served [dashboard](dashboard.md) (`--serve`) and the proof-aware
[SBOM](sbom.md) both record the assessment standard and its native level
label, so a browser or a CycloneDX / SPDX / Markdown consumer sees the right
name for the selected standard.
Like the `sbom` subcommand, `--serve` **defaults to all standards** when no
`--standard` / `--asil` / `--class` flag is given. The dashboard renders
every standard's level at the shared tier. An explicit standard flag
narrows it. The SBOM's `adacovex:standard` / `adacovex:level` properties:

| `--` flag | `adacovex:standard` | `adacovex:level` |
|-----------|---------------------|------------------|
| `--dal=C` | `DO-178C` | `DAL-C` |
| `--asil=B` | `ISO 26262` | `ASIL B` |
| `--class=A` | `IEC 62304` | `Class A` |
| `--standard=all` | `DO-178C, ISO 26262, IEC 62304` | `DAL-C / ASIL B / Class A` |

The `adacovex:dal_target` property always carries the shared tier (`DAL-A`..
`DAL-D`) regardless of the labelling standard. `--standard=all` joins all
three standard names and level labels into the single `adacovex:standard` and
`adacovex:level` properties. One document carries every standard's
assessment.

## Implementation

- `Compliance_Standard` type (`DO_178C`, `ISO_26262`, `IEC_62304`) with
  `To_String` / `To_Standard` / `Standard_Slug` conversions and the
  dedicated `To_ASIL` / `To_Class` level parsers in `Adacovex.Types`.
- `--standard=NAME` CLI flag (default `do178c`, plus `all`) selects the
  labelling standard. `--dal=LEVEL` is the shared rigor tier (A--E). The
  dedicated `--asil=LEVEL` / `--class=LEVEL` flags set both the standard and
  the tier in one step.
- `Types.Standard_Level_Name` maps a standard + tier to its label (`DAL-C`,
  `ASIL B`, `Class A`, and more). `Assess_Standard` runs the same evidence
  checks as `Assess_DAL` while recording the standard. Every renderer
  (ANSI report, SVG badge, HTML dashboard, JSON API, Markdown report, and
  SBOM) then prints the standard-specific level without re-running scanning,
  proof parsing, or test parsing.
- `Min_SPARK_For` still drives the per-tier proof bar. The tiers share one
  lookup because the standards only re-label the levels.

Each standard has a dedicated reference page with its level definitions and
criteria:

- [DO-178C DAL levels](../api-docs/adacovex-dal-levels.md)
- [ISO 26262 ASIL levels](../api-docs/adacovex-asil-levels.md)
- [IEC 62304 safety classes](../api-docs/adacovex-class-levels.md)
