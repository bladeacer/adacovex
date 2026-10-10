# IEC 62304 Software Safety Classes

IEC 62304 defines three software safety classes (A, B, C) for the
medical-device software lifecycle, ranked by the severity of the harm a
failure could cause. adacovex assesses compliance against all three by
re-labelling the same four evidence checks it computes for DO-178C: HLR
traceability, no orphan tags, passing tests, and a minimum SPARK proof level.

## Level Definitions

| Class | Severity | Possible Consequence | Example |
|-------|----------|----------------------|---------|
| C | Highest | Death or serious injury possible | Infusion-pump dosing, radiation-therapy control |
| B | Moderate | Non-serious injury possible | Diagnostic imaging, patient-monitor alarm logic |
| A | Lowest | No injury or damage to health | Administrative/scheduling software, data logging |

## Assessment Criteria

adacovex evaluates the same four criteria for every class; only the class name
and the minimum proof bar change.

### 1. HLR Traceability

| Class | Requirement |
|-------|-------------|
| A--C | All high-level requirements (HLRs) traced to source-code tags (`-- HLR-XXXX`) |

### 2. Orphan Tags

| Class | Requirement |
|-------|-------------|
| A--C | Every in-source HLR tag must correspond to a defined HLR in `compliance/HLR.md` |

### 3. Test Pass/Fail

| Class | Requirement |
|-------|-------------|
| A--C | 100% tests passing |

### 4. Minimum SPARK Level

| Class | Minimum SPARK Level |
|-------|---------------------|
| C | Gold |
| B | Silver |
| A | Bronze |

## Mapping to the shared rigor tier

IEC 62304 safety classes map onto the same A--E rigor tier DO-178C uses, so one
assessment satisfies both standards at once:

| Class | Shared tier | DO-178C equivalent |
|-------|-------------|--------------------|
| C | A | DAL-A |
| B | B | DAL-B |
| A | C | DAL-C |

## CLI selection

```bash
adacovex --target=. --class=A          # assess at safety Class A
adacovex --target=. --class=C          # assess at safety Class C (requires Gold SPARK)
adacovex --target=. --standard=iec62304 --dal=C   # Class A via the shared tier
adacovex --target=. --standard=all     # badges for DO-178C + ISO 26262 + IEC 62304
```

See [Standards](../usage/standards.md) for the full cross-standard tier mapping,
[DAL Levels](adacovex-dal-levels.md) for the DO-178C criteria this page
generalizes, and [SPARK Levels](adacovex-spark-levels.md) for the per-level
proof bar.

## Assessment Output

The tool reports each criterion as met/unmet and a final Achieved/Unmet status,
labelled with the safety-class name:

```
Target level: Class A
Status: Achieved
HLR traced:  24 /  24
Orphan tags: No
Tests passing: Yes
Min SPARK level met: Yes
```
