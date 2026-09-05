# Proving and writing SPARK proofs

adacovex runs gnatprove, reads its summary, and grades the result against
the [SPARK assurance levels](../api-docs/adacovex-spark-levels.md). This page
is the guide to both halves: **how proving works** under adacovex, and
**how to write proofs** -- contracts in your own code, and -- when the code
is vendored and cannot be modified -- **proof patches** that add the
contracts for you (see [Proof patches over vendored code](proving-patches.md)).

## Proving a project with adacovex

```bash
adacovex prove --target=.
```

The `prove` subcommand (full options:
[CLI reference -- the `prove` subcommand](../usage/cli-reference-flags.md#the-prove-subcommand)):

1. **Resolves gnatprove** without requiring the target to declare it:
   manifest pin > global pin > `$PATH` > cached toolchain > download. Full
   order and per-method detail:
   [Architecture -- GNATprove toolchain resolution](architecture.md#gnatprove-toolchain-resolution-prove-subcommand).
2. **Runs gnatprove** against the target (or against a patched tree copy
   when proof patches are present -- see
   [Proof patches over vendored code](proving-patches.md#proof-patches-proving-vendored-dependencies))
   and writes the summary to `<target>/obj/gnatprove/gnatprove.out` -- the same
   location the assessment pipeline discovers.
 3. **Falls through to the full assessment**. The assessment parses the fresh
    summary. One command both proves and assesses. The `--require-*` CI gates
   apply to the proof run directly (`--require-spark=Platinum
    --require-proof=100` and more; see
   [CLI reference -- CI threshold gates](../usage/cli-reference-options.md#ci-threshold-gates---require-)).

The result cache serves unchanged targets so repeated runs are cheap.
`--force` bypasses the cache and forces a full gnatprove reanalysis. A target
without a `gnatprove.out` at all is graded `Stone` with proof metrics `N/A`.
Run `prove` to generate one.

### The two caches -- why prove timings vary

`prove` interacts with two independent caches, and knowing which one is
cold explains every timing you will see:

- The **result cache** (`~/.adacovex/cache/<version>/`, or `--cache-dir`)
  is adacovex's own store, keyed on the content hash of the proof inputs
  (every `.ads`/`.adb` under the target plus the `.gpr` and the option
  string). A hit serves the stored proof and skips gnatprove entirely --
  this is the short-circuit that makes an unchanged tree prove in tens of
  milliseconds.
- The **gnatprove session store** (`<target>/obj/gnatprove/`) is
  gnatprove's internal per-unit session. When adacovex does spawn
  gnatprove (a result-cache miss), the session decides the cost: a
  complete session re-analyses only changed units; a wiped or partial
  session re-analyses from scratch.

Concretely, for an unchanged target:

| Result cache | gnatprove session | What a `prove` run costs |
|--------------|-------------------|--------------------------|
| hit | any | ~tens of ms -- the short-circuit |
| miss | complete | a few seconds -- gnatprove re-verifies quickly, then re-stores |
| miss | wiped | the full solver run -- tens of seconds on a large proof |
| miss | partial | lands between the two -- gnatprove re-analyses the missing units |

The partial-session row is the easy one to misread: a targeted
`gnatprove -u <unit>` run, a killed proof, or a hand-delete under
`obj/gnatprove/` leaves the session incomplete, and the next result-cache
miss re-proves just the gap -- so consecutive runs alternate between
instant and multi-second. Once one full `prove` completes, the session is
complete again and back-to-back runs stay at the short-circuit. This is
content-keyed cache behaviour, not a cache fault: any source edit (or a
docs edit that changes the bundled manual in `src/`) legitimately changes
the key and re-proves once.

`make bench` samples both extremes (prove warm = hit; prove cold = result
cache *and* session wiped), so its numbers are always one of the stable
shapes. Category definitions and current figures:
[Performance](perf.md).

## What a proof contains

gnatprove reports verification conditions (VCs) per check category. The
summary in `gnatprove.out` breaks them down as:

| Category | What it covers |
|----------|----------------|
| Run-time checks | Index bounds, overflow, division-by-zero, range checks -- absence of run-time errors |
| Assertions | User `pragma Assert` statements and pre/postcondition checks |
| Functional contracts | `Pre` / `Post` / `Global` contract satisfaction |
| Data dependencies | Flow analysis: uninitialized reads, effective `Global` contracts |
| Initialization | All objects initialized before first use |
| Termination | `Loop_Variant` / recursion bounds (subprograms proved terminating) |

The honest **proved** count is `total - justified - unproved` (flow plus
provers). The [assurance level](../api-docs/adacovex-spark-levels.md) is
derived from how many of each category were discharged:

- **Stone** -- no proof run or nothing analyzable;
- **Bronze** -- flow analysis clean (data dependencies, initialization);
- **Silver** -- run-time checks proved, assertions proved;
- **Gold** -- functional contracts proved on top;
- **Platinum** -- every VC proved: **0 unproved** (and, in adacovex's own
  gate, **0 justified** -- no `pragma Annotate` justifications).

Justified VCs count neither as proved nor as unproved. Only unproved VCs
downgrade the level. For a DAL assessment, the level must meet the requirement
of the tier (`--dal=C` needs Bronze, `--dal=A` needs Gold, and more) -- see
[DAL levels](../api-docs/adacovex-dal-levels.md).

## Writing proofs: SPARK contracts

A proof starts with contracts in the source, written as Ada aspects:

```ada
package Body_Vec is

   function Clamp (Value : in Integer; Lo : in Integer; Hi : in Integer)
     return Integer
     with Pre  => Lo <= Hi,
          Post => Clamp'Result in Lo .. Hi;

end Body_Vec;
```

Rules that matter in practice:

- **`SPARK_Mode => On` selects what gnatprove analyses.** Without it a unit
  is out of proof scope. It can be declared on the package
  (`package P with SPARK_Mode => On is`), on individual subprograms, or
  both -- adacovex's own source uses package-level On on pure units and
  per-subprogram On aspects inside default-off bodies.
- **A body is analysed only when the body itself opts in.** Declaring
  `SPARK_Mode => On` on the *spec* does not make gnatprove analyse the body.
  The body must declare it too (on the `package body` line or per subprogram).
  This is the rule that makes proof patches necessary for vendored code -- see
  below.
- **I/O bodies are skipped by design.** A body that calls `Ada.Text_IO` (which
  is `SPARK_Mode Off`) cannot be analysed. gnatprove reports the unit out of
proof scope. This never drags the assessed level down -- it means those
bodies are not proved.
- **Contracts are proved against the body.** gnatprove proves that every
  possible body execution satisfies the declared `Pre`/`Post`. Callers must in
  turn establish the `Pre` before calling.
- **`--steps` controls the proof budget.** gnatprove's default step limit can
  produce solver-timeout false negatives. adacovex runs with `--steps 10000`
  by default so such timeouts are not reported as unproved. An explicit
  `--steps=N` overrides.

The goal for a clean proof: every VC in every category proved, 0 unproved,
0 justified.

## See also

- [Proof patches over vendored code](proving-patches.md) -- the full guide
  to `.ads`/`.adb` patches that add SPARK contracts over vendored
  dependencies
- [SPARK assurance levels](../api-docs/adacovex-spark-levels.md) -- Stone to
  Platinum, per-category objectives
- [CLI reference -- the `prove` subcommand](../usage/cli-reference-flags.md#the-prove-subcommand)
  -- flags, gnatprove resolution, the fall-through assessment
- [CLI reference -- CI threshold gates](../usage/cli-reference-options.md#ci-threshold-gates---require-)
  -- `--require-spark` / `--require-proof` / `--require-tests`
- [Target project requirements](../usage/target-projects.md) -- what a project must provide
- [Architecture -- proof patches](architecture-verification.md#proof-patches-spark-contracts-over-vendored-dependencies)
  -- the design, the merge engine, and the patched-copy pipeline
- [Performance](perf.md) -- benchmark categories for the prove scenarios and
  the current timings
- [The proof ledger](../proof/16.1.0-ledger.md) -- how adacovex's own proof
  is tracked
