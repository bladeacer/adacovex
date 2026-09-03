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

### The multi-pair form (implemented in 1.42.0)

The general multi-pair form ships in 1.42.0, built on the deferred design
recorded above:

- Pass one (`Lower_Pairs`) scans the list once and lowers each well-formed
  `P:Type` pair onto its bounded type, into a fixed-size record array
  (32 pairs, 64-char names, 9-char type names -- every bound a named
  constant).
- Pass two emits the signature from the lowered pairs: one `Append` per
  field slice, pairs joined with `; `.
- Pass three emits the joined `and then` guard chain, one half-range guard
  per signed pair. Unsigned (modular) parameters need no guard; a list
  with no signed parameter emits no contract.
- Malformed pairs, foreign type names, embedded spaces, and lists longer
  than 32 pairs degrade to an empty string (never a truncated spec: a
  truncated list would drop named pairs while keeping the contract that
  references them).

The 16.1.0 lessons held:

- Chained `&` string assembly blows up the solver. Append one slice per
  call, never a chain of slices.
- A named-constant slice is proved once at its declaration site. Repeating a
  slice expression at every `Append` call re-proves the range each time.
- A straight-line emitter stays near the proof cost of the type-lowering
  helpers. Loop contexts multiply the VC count -- but bounded length
  subtypes (`N_Len : Natural range 0 .. Max_Pair_Name`) keep the loop
  VCs tractable: with the bound carried in the subtype, the prover
  discharges the emission-site slices locally instead of re-deriving the
  range from the lowering pass on every iteration.

The three-pass form costs the synthesiser unit 52 body VCs on top of the
lean slice; the whole-tree total is 876, all proved, no justifications.

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
| Contract synthesis (multi-pair) | `Adacovex.IR_Synthesiser` | A comma-list spec carries the joined guard chain |

`Synthesize_Package` assembles whole package text from comma-separated type
names in 46 checks. The multi-pair bounded-function slice sits next to it:
same bounded buffer, same append discipline, a comma-separated `P:Type`
list lowered once and emitted in three passes (the lean single-pair slice
remains for the no-comma case).

## Proof and performance ledger

Measured with gnatprove 16.1.0 (12 logical cores, 10 proof jobs, cold
caches):

| Tree | VCs | Cold `make prove` wall |
|------|-----|------------------------|
| 1.40.0 | 725 | 39.0 s |
| 1.41.0, multi-pair prototype | 850 | 43.6 s |
| 1.41.0, lean slice | 791 | 42.8 s |
| 1.42.0, multi-pair three-pass | 876 | 4.5 s |

The multi-pair slice keeps the exploration concrete and proved. The VC
growth over 1.41.0 (+85) is the price of the proved general form; the cold
wall drop is the 1.42.0 walk-skip and cache work (see
[Performance](perf.md)) -- the IR slice itself proved in the same session
shape as 1.41.0. An idle `make prove` short-circuits in about 2.4 s, and a
warm cache-hit run re-proves only the changed units.

## Where the IR could go next

The long-term direction, in increasing order of cost:

1. **Lowered bodies**: synthesise a checked body (not just a spec) whose
   arithmetic is provable by construction, so the proof run sees no
   unchecked operation.
2. **Signature lowering for callers**: given a lowered spec, rewrite foreign
   call sites to pass through the bounded types, so the caller side carries
   the same guarantee.
3. **Larger pair bounds**: raise the 32-pair / 64-char record bounds if a
   real target needs it, re-proving the slice at the new bounds (the proof
   cost scales with the bound constants only through the loop ranges).

Each step must stay inside the Platinum gate: zero unproved VCs, zero
justified VCs. The multi-pair slice proves the general contract synthesis
is sound; the next steps extend it from specs to bodies and callers.

## Related reading

- [IR type synthesis API](../api-docs/adacovex-ir_synthesiser.md) -- the
  synthesiser package.
- [Bounded IR types](../api-docs/adacovex-target_profiles.md) -- the `IR_*`
  scalar types.
- [Proving and writing proofs](proving.md) -- how the proof gate works.
- [Performance](perf.md) -- the pipeline and proof timings.
