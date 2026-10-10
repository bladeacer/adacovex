# Selecting a standard and reading the reports

adacovex computes one safety case and re-labels it per standard. This page
covers the flags that select a standard, and the labels the reports and the
SBOM carry. The per-standard pages are
[DO-178C](standards-do-178c.md), [ISO 26262](standards-iso-26262.md), and
[IEC 62304](standards-iec-62304.md).

## The level flags

Each standard has a dedicated level flag, so the intent is visible on the
command line. Every flag resolves to the same shared rigour tier.

| Standard | Flag | Levels | Example |
|----------|------|--------|---------|
| DO-178C | `--dal=` | A, B, C, D, E | `--dal=C` gives DAL-C (Major) |
| ISO 26262 | `--asil=` | A, B, C, D, QM | `--asil=B` gives ASIL B (Major) |
| IEC 62304 | `--class=` | A, B, C | `--class=A` gives Class A (Major) |

`--standard=NAME` selects the labelling standard, and `--dal=LEVEL` sets the
shared tier. The two forms below are therefore equivalent:

```bash
adacovex --target=. --asil=B
adacovex --target=. --standard=iso26262 --dal=C
```

The dedicated flags exist so that a reader of the command line sees "ASIL B"
or "Class A" without decoding the shared tier. The full flag reference is in
the [CLI reference](cli-reference.md).

## All standards at once

`--standard=all` runs one assessment at the shared tier and emits badges and
reports for every standard: `do178c.svg`, `iso26262.svg`, and
`iec62304.svg`. adacovex does not re-scan, re-prove, or re-parse anything.

The evidence is identical across standards, so the three badges always agree
on Achieved or Unmet. Only the level label inside them changes. Like the
[SBOM](sbom.md) subcommand, `--serve` defaults to all standards when no
standard flag is given.

## Dashboard and SBOM standard-awareness

The served [dashboard](dashboard.md) and the proof-aware [SBOM](sbom.md)
record the assessment standard and its native level label. A browser or a
CycloneDX, SPDX, or Markdown consumer therefore sees the correct name.

The SBOM carries the standard and the level in two properties:

| Flag | `adacovex:standard` | `adacovex:level` |
|------|---------------------|------------------|
| `--dal=C` | `DO-178C` | `DAL-C` |
| `--asil=B` | `ISO 26262` | `ASIL B` |
| `--class=A` | `IEC 62304` | `Class A` |
| `--standard=all` | `DO-178C, ISO 26262, IEC 62304` | `DAL-C / ASIL B / Class A` |

The `adacovex:dal_target` property always carries the shared tier (`DAL-A`
to `DAL-D`), whatever the labelling standard. With `--standard=all` the
three standard names and level labels are joined into the single
`adacovex:standard` and `adacovex:level` properties. One document carries
every standard's assessment.

## Implementation

- The `Compliance_Standard` type (`DO_178C`, `ISO_26262`, `IEC_62304`)
  carries the `To_String`, `To_Standard`, and `Standard_Slug` conversions,
  plus the `To_ASIL` and `To_Class` level parsers, in `Adacovex.Types`.
- `--standard=NAME` (default `do178c`, plus `all`) selects the labelling
  standard, and `--dal=LEVEL` is the shared rigour tier.
- `Types.Standard_Level_Name` maps a standard and a tier to its label
  (`DAL-C`, `ASIL B`, `Class A`, and more). `Assess_Standard` runs the same
  evidence checks as `Assess_DAL` while recording the standard.
- Every renderer then prints the standard-specific level without re-running
  the scan, the proof parse, or the test parse. `Min_SPARK_For` still drives
  the per-tier proof bar, because the standards only re-label the levels.

## See also

- [Standards](standards.md) -- the shared rigour tier and the four shared
  assessment criteria.
- [CLI reference](cli-reference-flags.md) -- the full flag reference.
- [SBOM](sbom.md) -- the standard and level properties in the generated
  document.
