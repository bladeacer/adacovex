# ISO 26262 ASIL Levels

ISO 26262 defines four Automotive Safety Integrity Levels (ASIL A--D) plus the
quality-managed (QM) classification for road-vehicle functional safety.
adacovex assesses compliance against all of them by re-labelling the same four
evidence checks it computes for DO-178C: HLR traceability, no orphan tags,
passing tests, and a minimum SPARK proof level.

## Level Definitions

| ASIL | Severity | Failure Condition | Example |
|------|----------|-------------------|---------|
| D | Catastrophic | Uncontrolled, life-threatening malfunction | Steering/brake-by-wire, airbag deployment control |
| C | Hazardous | Severe injury, survival uncertain | Stability control, adaptive cruise control |
| B | Major | Non-fatal injury possible | Lane-keeping assist, headlamp control |
| A | Minor | No injury; limited function loss | Window/sunroof control, seat adjustment |
| QM | No effect | No safety effect (quality-managed) | Infotainment, navigation |

## Assessment Criteria

adacovex evaluates the same four criteria for every level; only the level name
and the minimum proof bar change.

### 1. HLR Traceability

| ASIL | Requirement |
|------|-------------|
| A--D | All high-level requirements (HLRs) traced to source-code tags (`-- HLR-XXXX`) |
| QM | Recommended but not enforced |

### 2. Orphan Tags

| ASIL | Requirement |
|------|-------------|
| A--D | Every in-source HLR tag must correspond to a defined HLR in HLR.md |
| QM | Recommended but not enforced |

### 3. Test Pass/Fail

| ASIL | Requirement |
|------|-------------|
| C--D | 100% tests passing |
| A--B | 100% tests passing |
| QM | No requirement |

### 4. Minimum SPARK Level

| ASIL | Minimum SPARK Level |
|------|---------------------|
| D | Gold |
| C | Silver |
| B | Bronze |
| A | Stone |
| QM | None (Stone) |

## Mapping to the shared rigor tier

ISO 26262 ASIL levels map onto the same A--E rigor tier DO-178C uses, so one
assessment satisfies both standards at once:

| ASIL | Shared tier | DO-178C equivalent |
|------|-------------|--------------------|
| D | A | DAL-A |
| C | B | DAL-B |
| B | C | DAL-C |
| A | D | DAL-D |
| QM | E | DAL-E |

## CLI selection

```bash
adacovex --target=. --asil=B          # assess at ASIL B
adacovex --target=. --asil=D          # assess at ASIL D (requires Gold SPARK)
adacovex --target=. --standard=iso26262 --dal=C   # ASIL B via the shared tier
adacovex --target=. --standard=all    # badges for DO-178C + ISO 26262 + IEC 62304
```

See [Standards](../usage/standards.md) for the full cross-standard tier mapping,
[DAL Levels](adacovex-dal-levels.md) for the DO-178C criteria this page
generalizes, and [SPARK Levels](adacovex-spark-levels.md) for the per-level
proof bar.

## Assessment Output

The tool reports each criterion as met/unmet and a final Achieved/Unmet status,
labelled with the ASIL name:

```
Target level: ASIL B
Status: Achieved
HLR traced:  24 /  24
Orphan tags: No
Tests passing: Yes
Min SPARK level met: Yes
```
