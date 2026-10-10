# IEC 62304 and the safety classes

IEC 62304 is the medical-device software lifecycle standard. It classifies
software into safety classes A, B, and C by the severity of the harm that a
failure can cause.

Class C is the highest class, where death or serious injury is possible.
Class A is the lowest class, where no injury or damage to health is possible.

## The three safety classes

| Class | Severity | Possible consequence | Example |
|-------|----------|----------------------|---------|
| C | Highest | Death or serious injury possible | Infusion-pump dosing, radiation-therapy control |
| B | Moderate | Non-serious injury possible | Diagnostic imaging, patient-monitor alarm logic |
| A | Lowest | No injury or damage to health | Administrative software, data logging |

## What adacovex checks at each class

adacovex evaluates the same four criteria as for DO-178C. Only the class
name and the minimum proof bar change.

### Requirement traceability and orphan tags

| Class | Requirement |
|-------|-------------|
| A to C | Every HLR is traced by a `-- HLR-XXXX` tag, and every tag maps to a defined HLR |

### Passing tests

| Class | Requirement |
|-------|-------------|
| A to C | 100% tests passing |

### Minimum SPARK level

| Class | Minimum SPARK level |
|-------|---------------------|
| C | Gold |
| B | Silver |
| A | Bronze |

## Mapping to the shared rigour tier

The safety classes map onto the shared rigour tier that DO-178C uses. One
assessment therefore satisfies both standards at once.

| Class | Shared tier | DO-178C equivalent |
|-------|-------------|--------------------|
| C | A | DAL-A |
| B | B | DAL-B |
| A | C | DAL-C |

## Assessing at a safety class

Select a class with `--class`, or select the shared tier with `--dal`:

```bash
adacovex --target=. --class=A
adacovex --target=. --class=C
adacovex --target=. --standard=iec62304 --dal=C
adacovex --target=. --standard=all
```

The report prints the class name in place of the DAL name:

```
Target level: Class A
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
- [Safety classes](../api-docs/adacovex-class-levels.md) -- the generated
  reference page with the class definitions.
- [DO-178C and the DAL levels](standards-do-178c.md) -- the criteria this
  page re-labels.
