# DO-178C and the DAL levels

DO-178C is the airborne-software standard. It defines how a team designs,
implements, verifies, and certifies software that flies an aircraft. Every
item of flight software is assessed at one of five Development Assurance
Levels (DAL A to DAL E).

The DAL follows the severity of the failure condition. DAL-A covers a
catastrophic failure that prevents continued safe flight, and DAL-E covers
software with no safety effect at all.

## The five DAL levels

| DAL | Severity | Failure condition | Example |
|-----|----------|-------------------|---------|
| A | Catastrophic | Prevents continued safe flight and landing | Flight controls, engine FADEC |
| B | Hazardous | Large reduction in the safety margins | Autopilot, navigation |
| C | Major | Significant increase in crew workload | Flight management system |
| D | Minor | Slight increase in crew workload | Cabin pressure display |
| E | No effect | No impact on safety | In-flight entertainment |

## What adacovex checks at each level

adacovex evaluates four criteria. Only the strictness changes with the level.

### Requirement traceability

| DAL | Requirement |
|-----|-------------|
| A to C | Every high-level requirement (HLR) is traced by a `-- HLR-XXXX` tag in source |
| D and E | Recommended, not enforced |

### No orphan tags

| DAL | Requirement |
|-----|-------------|
| A to C | Every in-source tag maps to an HLR defined in `docs/compliance/HLR.md` |
| D and E | Recommended, not enforced |

### Passing tests

| DAL | Requirement |
|-----|-------------|
| A and B | 100% tests passing, with MC/DC structural coverage analysis |
| C | 100% tests passing, with statement coverage |
| D | 100% tests passing |
| E | No requirement |

### Minimum SPARK level

| DAL | Minimum SPARK level | Requirement |
|-----|---------------------|-------------|
| A | Gold | Core invariants proved, absence of run-time errors achieved |
| B | Silver | Partial proofs, all verification conditions attempted |
| C | Bronze | Flow analysis passes |
| D | Stone | The code is a valid SPARK subset |
| E | None | No proof requirement |

The minimum levels match `Min_SPARK_For` in
`src/compliance/adacovex-compliance-dal.adb`. Gold is the compliance
baseline. Platinum (every functional contract proved) is a best-effort ideal
that adacovex reports when achieved, never a compliance gate.

## Assessing at a DAL

DAL-C is the default. Select another level with `--dal`:

```bash
adacovex --target=. --dal=A
adacovex --target=. --dal=B
adacovex --target=. --dal=D
adacovex --target=. --dal=E
```

The report prints each criterion as met or unmet, then a final
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

- [Standards](standards.md) -- the shared rigour tier and the overview of
  all three standards.
- [ISO 26262 and the ASIL levels](standards-iso-26262.md) and
  [IEC 62304 and the safety classes](standards-iec-62304.md) -- the same
  criteria re-labelled for the other standards.
- [Selecting a standard](standards-selection.md) -- the CLI flags and the
  reported labels.
- [DAL levels](../api-docs/adacovex-dal-levels.md) -- the generated
  reference page with the level definitions.
- [SPARK levels](../api-docs/adacovex-spark-levels.md) -- the proof bar per
  DAL.
