# DO-178C DAL Levels

DO-178C defines five Development Assurance Levels (DAL A--E) corresponding
to the severity of failure conditions. adacovex assesses compliance against
all five levels.

## Level Definitions

| DAL | Severity | Failure Condition | Example |
|-----|----------|-------------------|---------|
| A | Catastrophic | Prevents continued safe flight/landing | Flight controls, engine FADEC |
| B | Hazardous | Large reduction in safety margins | Autopilot, navigation |
| C | Major | Significant increase in crew workload | Flight management system |
| D | Minor | Slight increase in crew workload | Cabin pressure display |
| E | No effect | No impact on safety | In-flight entertainment |

## Assessment Criteria

adacovex evaluates four criteria for each DAL level:

### 1. HLR Traceability

| DAL | Requirement |
|-----|-------------|
| A--C | All high-level requirements (HLRs) traced to source code tags (`-- HLR-XXXX`) |
| D--E | Recommended but not enforced |

### 2. Orphan Tags

| DAL | Requirement |
|-----|-------------|
| A--C | Every in-source HLR tag must correspond to a defined HLR in `compliance/HLR.md` |
| D--E | Recommended but not enforced |

### 3. Test Pass/Fail

| DAL | Requirement |
|-----|-------------|
| A--B | 100% tests passing with MC/DC coverage (structural coverage analysis) |
| C | 100% tests passing (statement coverage) |
| D | 100% tests passing |
| E | No requirement |

### 4. Minimum SPARK Level

| DAL | Minimum SPARK Level | Requirement |
|-----|---------------------|-------------|
| A | Gold | Core invariants proved, AoRTE achieved |
| B | Silver | Partial proofs, all VCs attempted |
| C | Bronze | Flow analysis passes |
| D | Stone | Valid SPARK subset |
| E | None | -- |

The minimum levels match `Min_SPARK_For` in
`src/compliance/adacovex-compliance-dal.adb`. Gold is the minimum compliance
baseline; Platinum (every functional contract proved) is a best-effort ideal
reported when achieved, not a compliance gate. Justified VCs (GNATprove
`pragma Annotate`) count neither as proved nor unproved and never downgrade
the level.

## DAL-C (default)

The default assessment level is DAL-C. To assess at a different level:

```bash
adacovex --target=../Ada_CRDT --dal=A
adacovex --target=../Ada_CRDT --dal=B
adacovex --target=../Ada_CRDT --dal=D
adacovex --target=../Ada_CRDT --dal=E
```

## Assessment Output

The tool reports each criterion as met/unmet and provides a final
Achieved/Unmet status:

```
Target DAL: C
Status: Achieved
HLR traced:  24 /  24
Orphan tags: No
Tests passing: Yes
Min SPARK level met: Yes
```

## See also

- [Standards](../usage/standards.md) -- the cross-standard rigor-tier mapping
  (DO-178C / ISO 26262 / IEC 62304)
- [ASIL Levels](adacovex-asil-levels.md) -- the ISO 26262 levels this page's
  criteria are re-labelled for
- [Safety Classes](adacovex-class-levels.md) -- the IEC 62304 classes this
  page's criteria are re-labelled for
- [SPARK Levels](adacovex-spark-levels.md) -- the proof bar per DAL
  (Gold / Silver / Bronze / Stone)
