# A gnatprove-friendly IR for lowered code

adacovex audits Ada/SPARK projects. Some of the code it audits is written in
a foreign style: C-style integer types (`int32_t`, `size_t`), unchecked
arithmetic, and subprogram signatures that carry no SPARK contracts. Such
code is hard for gnatprove to prove, because the proof must discover the
bounded intent behind the foreign names and the unchecked operations.

This page records the exploration of an **intermediate representation (IR)**
that makes lowered code friendlier to gnatprove. The IR is not a full
compiler pipeline. It is a set of proved building blocks that synthesise
bounded Ada/SPARK text from foreign-style input. The name "IR" is used here
in the adacovex sense: a lowered, bounded form of the audited code that
gnatprove can discharge, not a control-flow graph.

## The problem: foreign code is hard to prove

A proof run on an audited project succeeds when gnatprove can discharge the
runtime checks and the user assertions. A foreign function such as:

```ada
function Add32 (A, B : Integer) return Integer;
```

carries no contract. gnatprove must either assume the body is safe (which
the proof policy forbids) or prove the body against the widest possible
`Integer` range. The proof then struggles with checks that are only reachable
because the declared type is wider than the foreign intent.

The existing bounded types in `Adacovex.Target_Profiles` (`IR_Int32`,
`IR_UInt64`, and the other `IR_*` scalars) fix half of the problem. They give
lowered code a type whose range is the machine word size, so the arithmetic
is checked against the intent. The `Adacovex.IR_Bounds` fixture proves that
checked additions over these types discharge in one or two VCs.

The other half is the **contract**. Lowered code must carry the half-range
guard that makes the checked arithmetic provable. `Target_Profiles`
demonstrates this guard on a hand-written `Checked_Add32`. The exploration
question is: can adacovex **synthesise** that guard as text, so a foreign
signature lowers onto a bounded, contract-carrying spec automatically?

## The exploration: synthesise the contract, not just the type

`Adacovex.IR_Synthesiser` already lowered foreign type names onto the
bounded IR scalars (`IR_Type_Name`, `Lower_Type_Name`, `Synthesize_Package`).
The 1.41.0 exploration adds a **lean slice** of the next layer:
`Synthesize_Bounded_Function`, which lowers one `P:Type` parameter pair onto
a bounded IR scalar and emits the half-range `Pre` guard in the generated
text.

For the signature `A:IR_Int32`, the generated text is:

```ada
function Inc (A : IR_Int32) return IR_Int32
with
  Pre => A in IR_Int32'First / 2 .. IR_Int32'Last / 2
;
```

The guard is the exact shape gnatprove discharges for
`Target_Profiles.Checked_Add32` and the `IR_Bounds` fixture. A proof run on
the generated text therefore checks only bounded-scalar arithmetic, never
foreign semantics.

### Why the slice is single-parameter

The first prototype handled a comma-separated parameter list: it counted the
pairs, emitted the signature, then emitted one guard per signed parameter.
That generality cost about 110 proof VCs in `ir_synthesiser` (a unit that
was 71 VCs at 1.40.0), because the parser ran three passes over the list and
each pass re-proved the slice arithmetic.

The single-pair form needs no comma-splitting pass. It scans for one colon,
slices the pair once into named constants, and emits the spec in straight
line. The slice and its helpers add about 57 VCs to the synthesiser unit
(128 versus 71 at 1.40.0); the whole-tree total is 791 versus 725 at 1.40.0,
and every check proves. The extra proof cost is the price of keeping a
*proved* slice: gnatprove must discharge the same arithmetic the generated
text will carry.

### The multi-pair design, deferred

The general multi-pair form remains the design goal. Its deferred design
(recorded here so a future change can pick it up):

- Pass one scans the list once and lowers each well-formed pair onto its
  bounded type, recording the signed ones.
- Pass two emits the signature from the lowered pairs.
- Pass three emits the joined `and then` guard chain, one half-range guard
  per signed pair.
- Malformed pairs degrade to the nullary spec (or to an empty string when
  nothing is well formed).

The 16.1.0 ledger records the lessons of the prototype:

- Chained `&` string assembly blows up the solver. Append one slice per
  call, never a chain of slices.
- A named-constant slice is proved once at its declaration site. Repeating a
  slice expression at every `Append` call re-proves the range each time.
- A straight-line emitter stays near the proof cost of the type-lowering
  helpers. Loop contexts multiply the VC count.

A future change that wants the multi-pair form should budget for roughly 90
body VCs on gnatprove 16.1.0 and offset it by simplifying elsewhere, or gate
the general form behind a build flag so the shipped binary keeps the lean
slice.

## The building blocks

The IR exploration is a set of proved pieces, each cheap enough for the
Platinum gate:

| Piece | Unit | What it proves |
|-------|------|----------------|
| Bounded scalars | `Adacovex.Target_Profiles` | `IR_*` types with checked add/sub/mul |
| Lowering fixture | `Adacovex.IR_Bounds` | Checked arithmetic on lowered types discharges in 1-2 VCs |
| Type lowering | `Adacovex.IR_Synthesiser` | Foreign names lower onto bounded declarations |
| Package synthesis | `Adacovex.IR_Synthesiser` | A package skeleton assembles from bounded text |
| Contract synthesis (lean) | `Adacovex.IR_Synthesiser` | A bounded-function spec carries the half-range guard |

`Synthesize_Package` assembles whole package text from comma-separated type
names in 46 checks. The lean bounded-function slice sits next to it: same
bounded buffer, same append discipline, one parameter pair.

## Proof and performance ledger

Measured on the 1.41.0 tree with gnatprove 16.1.0 (12 logical cores, 10
proof jobs, cold caches):

| Tree | VCs | Cold `make prove` wall |
|------|-----|------------------------|
| 1.40.0 | 725 | 39.0 s |
| 1.41.0, multi-pair prototype | 850 | 43.6 s |
| 1.41.0, lean slice | 791 | 42.8 s |

The lean slice keeps the exploration concrete and proved. The remaining gap
to 1.40.0 is the cost of the new proved code; it is documented rather than
hidden. The pipeline and cache work in the same release (see
[Performance](perf.md)) more than offsets it for the runs developers make
most often: an idle `make prove` short-circuits in about 2.5 s, and a warm
cache-hit run re-proves only the changed units.

## Where the IR could go next

The long-term direction, in increasing order of cost:

1. **Multi-pair contract synthesis** from the deferred design above.
2. **Lowered bodies**: synthesise a checked body (not just a spec) whose
   arithmetic is provable by construction, so the proof run sees no
   unchecked operation.
3. **Signature lowering for callers**: given a lowered spec, rewrite foreign
   call sites to pass through the bounded types, so the caller side carries
   the same guarantee.

Each step must stay inside the Platinum gate: zero unproved VCs, zero
justified VCs, and a cold `make prove` that stays within reach of the
1.40.0 baseline. The single-pair slice exists to prove the contract
synthesis is sound before the general form pays for its loops.

## Related reading

- [IR type synthesis API](../api-docs/adacovex-ir_synthesiser.md) -- the
  synthesiser package.
- [Bounded IR types](../api-docs/adacovex-target_profiles.md) -- the `IR_*`
  scalar types.
- [Proving and writing proofs](proving.md) -- how the proof gate works.
- [Performance](perf.md) -- the pipeline and proof timings.
