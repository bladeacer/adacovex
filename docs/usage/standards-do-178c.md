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

adacovex evaluates four criteria. Only the strictness of the proof bar and
the test gate changes with the level.

### Requirement traceability

| DAL | Requirement |
|-----|-------------|
| A to E | Every high-level requirement (HLR) is traced by a `-- HLR-XXXX` tag in source |

### No orphan tags

| DAL | Requirement |
|-----|-------------|
| A to E | Every in-source tag maps to an HLR defined in `docs/compliance/HLR.md` |

### Passing tests

| DAL | Requirement |
|-----|-------------|
| A to D | Zero failing tests |
| E | No requirement |

Structural coverage (MC/DC or statement) is not assessed: adacovex reports
the statement, subprogram, and VC coverage gnatprove measures, and the
structural-coverage evidence a DAL A or DAL B campaign needs stays with
the project.

### Minimum SPARK level

| DAL | Minimum SPARK level | Requirement |
|-----|---------------------|-------------|
| A | Gold | Core invariants proved, absence of run-time errors achieved |
| B | Silver | Partial proofs, all verification conditions attempted |
| C | Bronze | Flow analysis passes |
| D | Stone | The code is a valid SPARK subset |
| E | Stone | Any SPARK subset meets it, so no proof requirement |

The minimum levels match `Min_SPARK_For` in
`src/compliance/adacovex-compliance-dal.adb`. Gold is the compliance
baseline. Platinum (every functional contract proved, and full proof coverage:
every subprogram the SPARK coverage report assesses proved) is a best-effort
ideal that adacovex reports when achieved, never a compliance gate.

## Assessing at a DAL

DAL-C is the default. Select another level with `--dal`:

```bash
adacovex --target=. --dal=A
adacovex --target=. --dal=B
adacovex --target=. --dal=D
adacovex --target=. --dal=E
```

The console prints one line for the assessed level, and the generated
`docs/compliance/VERIFICATION.md` carries the criterion rows:

```
  DAL-C: Achieved
```

```
| Criterion | Status |
|-----------|--------|
| Target level | DAL-C |
| Overall Status | Achieved |
| HLR Traced |  61 /  61 |
| Orphan Tags | No |
| Tests Passing | Yes |
| Min SPARK Level | Yes |
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
