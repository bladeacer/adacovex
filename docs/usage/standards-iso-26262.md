# ISO 26262 and the ASIL levels

ISO 26262 is the automotive functional-safety standard. It applies the same
rigour to road-vehicle software, such as braking, steering, and powertrain
control. Every item is assessed at one of four Automotive Safety Integrity
Levels (ASIL A to ASIL D), or as quality-managed (QM).

The ASIL follows the severity of the hazard. ASIL-D covers an uncontrolled,
life-threatening malfunction, and QM covers software with no safety effect.

## The ASIL levels

| ASIL | Severity | Failure condition | Example |
|------|----------|-------------------|---------|
| D | Catastrophic | Uncontrolled, life-threatening malfunction | Steering or brake-by-wire, airbag deployment |
| C | Hazardous | Severe injury, survival uncertain | Stability control, adaptive cruise control |
| B | Major | Non-fatal injury possible | Lane-keeping assist, headlamp control |
| A | Minor | No injury, limited function loss | Window or sunroof control, seat adjustment |
| QM | No effect | No safety effect | Infotainment, navigation |

## What adacovex checks at each level

adacovex evaluates the same four criteria as for DO-178C. Only the level
name and the minimum proof bar change.

### Requirement traceability and orphan tags

| ASIL | Requirement |
|------|-------------|
| A to D | Every HLR is traced by a `-- HLR-XXXX` tag, and every tag maps to a defined HLR |
| QM | Recommended, not enforced |

### Passing tests

| ASIL | Requirement |
|------|-------------|
| A to D | 100% tests passing |
| QM | No requirement |

### Minimum SPARK level

| ASIL | Minimum SPARK level |
|------|---------------------|
| D | Gold |
| C | Silver |
| B | Bronze |
| A | Stone |
| QM | None |

## Mapping to the shared rigour tier

The ASIL levels map onto the shared rigour tier that DO-178C uses. One
assessment therefore satisfies both standards at once.

| ASIL | Shared tier | DO-178C equivalent |
|------|-------------|--------------------|
| D | A | DAL-A |
| C | B | DAL-B |
| B | C | DAL-C |
| A | D | DAL-D |
| QM | E | DAL-E |

## Assessing at an ASIL

Select a level with `--asil`, or select the shared tier with `--dal`:

```bash
adacovex --target=. --asil=B
adacovex --target=. --asil=D
adacovex --target=. --standard=iso26262 --dal=C
adacovex --target=. --standard=all
```

The report prints the ASIL name in place of the DAL name:

```
Target level: ASIL B
Status: Achieved
HLR traced:  24 /  24
Orphan tags: No
Tests passing: Yes
Min SPARK level met: Yes
```

## See also

- [Standards](standards.md) -- the shared rigour tier and the overview of
  all three standards.
- [Selecting a standard](standards-selection.md) -- the CLI flags and the
  reported labels.
- [ASIL levels](../api-docs/adacovex-asil-levels.md) -- the generated
  reference page with the level definitions.
- [DO-178C and the DAL levels](standards-do-178c.md) -- the criteria this
  page re-labels.
