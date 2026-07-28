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
| Full functional requirements | Complete formal specification of all subprogram behaviour |
| Total correctness | All subprograms have complete Pre/Post contracts covering full behaviour |
| Domain properties | Algebraic properties (commutativity, idempotence, convergence) proved |
| Enforcement | `gnatprove` reports all VCs proved, 0 unproved, 0 justified |

## Level attainment in practice

Each level subsumes all lower levels (Platinum implies Gold through Stone).
The `--dal` analysis checks for a minimum SPARK level. For DAL-C, the
minimum requirement is Bronze (flow analysis passes).

```bash
# Check SPARK level of target project
adacovex --target=../Ada_CRDT --dal=C
```
