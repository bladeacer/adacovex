# SPARK Assurance Levels

SPARK defines five assurance levels -- Stone, Bronze, Silver, Gold, and
Platinum -- each building on the previous. Higher levels provide stronger
guarantees about absence of run-time errors and compliance with functional
specifications.

## Level Objectives

### Stone

| Criterion | Requirement |
|-----------|-------------|
| Valid SPARK subset | All source code uses SPARK-compatible constructs |
| No restricted constructs | No goto, no anonymous access types, no uncontrolled pointers |
| Enforcement | `gnatprove` runs without compilation errors |

### Bronze

| Criterion | Requirement |
|-----------|-------------|
| Data-flow analysis | Every variable is assigned before use, no uninitialized reads |
| Information-flow analysis | Depends/Global contracts match actual data dependencies |
| Initialization checks | All objects initialized before first use |
| Enforcement | `gnatprove --mode=flow` passes with 0 flow/initialization errors |

### Silver

| Criterion | Requirement |
|-----------|-------------|
| Absence of run-time errors (AoRTE) | All run-time checks proved: index bounds, overflow, division-by-zero, etc. |
| Assertions proved | All user-specified `pragma Assert` and pre/postcondition checks discharged |
| Enforcement | `gnatprove --mode=check` reports 0 unproved run-time checks |
| Justification | Unproved checks may be justified with `pragma Annotate` (limited to false positives) |

### Gold

| Criterion | Requirement |
|-----------|-------------|
| Functional correctness | Key subprogram contracts proved: Pre/Post, Type_Invariant |
| Core invariants | Critical type/system properties specified and verified |
| Enforcement | `gnatprove --mode=prove` reports 0 unproved functional contracts |
| Coverage | At minimum: all public subprograms in core packages have postconditions |

### Platinum

| Criterion | Requirement |
|-----------|-------------|
| Complete formal specification | All subprograms carry functional contracts (Pre/Post, Type_Invariant, and any other functional specification) |
| Total correctness | Every functional contract proved, 0 unproved functional VCs |
| Full functional coverage | Platinum is only reached when the project has functional contracts to prove: a project that proves its flow, run-time, and assertion checks but has no functional contracts is **not** Platinum |
| Full proof coverage | Every subprogram the [SPARK coverage report](../usage/cli-reference-flags.md#spark-coverage) assesses is proved. A subprogram the prover skipped, or a unit it never analysed, leaves the project short of the level |
| Enforcement | `gnatprove` reports all functional contracts proved with 0 unproved, and `adacovex spark-coverage --require-coverage=100 --gate-metric=subprograms` passes |

Platinum is the highest SPARK level. It requires a complete formal specification of all subprogram behaviour, and it is only reached when that specification exists. A project that proves all of its flow, run-time, and assertion checks but carries no functional contracts has not reached Platinum: there is nothing to prove at that level.

Platinum also requires **full proof coverage**: every subprogram the SPARK coverage report assesses must be proved. A project that discharges every check it reports but leaves subprograms outside the proof is Gold, not Platinum, because its formal specification does not cover the whole program.

The proof summary alone cannot show this, so adacovex measures the coverage report and grants Platinum only when subprogram coverage is complete. The gate is therefore: at least one functional contract, every functional contract proved, and every assessed subprogram proved. The artefacts do not say whether each individual subprogram declares a contract of its own, so the SPARK coverage report is the evidence the tool can check.

This is a best-effort ideal, not a DAL compliance gate. Justified VCs
(`pragma Annotate` for decidedly unprovable checks) count neither as proved
nor as unproved and never downgrade the level; only unproved VCs do. The
minimum DAL gates are Gold (DAL-A), Silver (DAL-B), and Bronze (DAL-C/D).

## Level attainment in practice

Each level subsumes all lower levels (Platinum implies Gold through Stone).
The `--dal` analysis checks for a minimum SPARK level. For DAL-C, the
minimum requirement is Bronze (flow analysis passes).

```bash
# Check SPARK level of target project
adacovex --target=../Ada_CRDT --dal=C
```

## See also

- [Standards](../usage/standards.md) -- the minimum proof bar per rigor tier across
  DO-178C / ISO 26262 / IEC 62304
- [DAL Levels](adacovex-dal-levels.md) -- the per-level SPARK gates
  (Gold / Silver / Bronze / Stone)
- [Proof ledger](../proof/16.1.0-ledger.md) -- adacovex's own proof record
  (1054/1054 VCs, 0 unproved, 0 justified under gnatprove 16.1.0; level
  Gold, because its coverage report shows subprograms outside the proof)
