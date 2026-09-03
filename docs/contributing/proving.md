# Proving and writing SPARK proofs

adacovex runs gnatprove, reads its summary, and grades the result against
the [SPARK assurance levels](../api-docs/adacovex-spark-levels.md). This page
is the guide to both halves: **how proving works** under adacovex, and
**how to write proofs** -- contracts in your own code, and -- when the code
is vendored and cannot be modified -- **proof patches** that add the
contracts for you.

## Proving a project with adacovex

```bash
adacovex prove --target=.
```

The `prove` subcommand (full options:
[CLI reference -- the `prove` subcommand](../usage/cli-reference.md#the-prove-subcommand)):

1. **Resolves gnatprove** without requiring the target to declare it:
   manifest pin > global pin > `$PATH` > cached toolchain > download. Full
   order and per-method detail:
   [Architecture -- GNATprove toolchain resolution](architecture.md#gnatprove-toolchain-resolution-prove-subcommand).
2. **Runs gnatprove** against the target (or against a patched tree copy
   when proof patches are present -- see
   [Proof patches](#proof-patches-proving-vendored-dependencies) below) and
   writes the summary to `<target>/obj/gnatprove/gnatprove.out` -- the same
   location the assessment pipeline discovers.
 3. **Falls through to the full assessment**. The assessment parses the fresh
    summary. One command both proves and assesses. The `--require-*` CI gates
   apply to the proof run directly (`--require-spark=Platinum
    --require-proof=100` and more; see
   [CLI reference -- CI threshold gates](../usage/cli-reference.md#ci-threshold-gates---require-)).

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

## Proof patches: proving vendored dependencies

Patch files at `<target>/.adacovex/patches/` exist so vendored code you
cannot modify still counts toward the audit. Their best-known job is
overlaying **docstrings** for strict-mode coverage. A patch can also carry
**SPARK proof aspects** so vendored dependencies participate in the proof
with real contracts -- without forking or touching their sources.

### Why proof patches are necessary

Three facts force the design:

 1. **Strict mode counts vendored code.** By default adacovex scans every
    directory except the always-excluded ones. The excluded directories are
    `.git`, `obj`, `tests`, `config`, and `.adacovex`. A vendored dependency's
    missing docstrings and missing contracts count against the target.
    `--relaxed` skips vendored dirs but drops the audit to a quick pass -- not
    an option for a compliance assessment.
 2. **gnatprove analyses a body only when the body itself opts in.** (The
    rule from [Writing proofs](#writing-proofs-spark-contracts) above.) A
    vendored spec with no contracts contributes nothing to the proof. A
    vendored body without `SPARK_Mode` is skipped entirely.
 3. **The vendored sources are immutable.** The dependency ships as-is. You
    cannot add contracts to it. Re-publishing a patched fork defeats the
    point of vendoring.

A proof patch is the merge of these three constraints. It re-declares the
vendored spec with contracts (`.ads` patch). It opts the vendored body into
the proof (`.adb` patch). The `prove` subcommand merges both into a patched
tree copy before running gnatprove -- the originals are never touched.

### How proof patches are applied

1. `Count_Proof_Patches` scans `<target>/.adacovex/patches/` for `.ads` and
   `.adb` files. A patch carrying any of `SPARK_Mode`, `Pre =>`, `Post =>`,
    or `Global =>` is a *proof patch*. A docstring-only patch never engages
    the proof machinery. A target with no proof patches is proved against its
    own tree exactly as before.
2. `Build_Patched_Copy` copies the target tree (excluding `.git`, `obj`,
   and `.adacovex`) into `<target>/obj/adacovex-proof/` and overwrites each
   proof-patched source with its merged form.
3. gnatprove runs against the copy's root project and the resulting
   `gnatprove.out` is copied back to `<target>/obj/gnatprove/gnatprove.out`
   for the assessment pipeline.
4. Patch contents are folded into the prove result-cache key, so a patch
   edit invalidates the cached proof and forces a re-prove (`--force` also
   bypasses the cache).

The patched copy lives under the target's `obj/`, so it is excluded from
scanning, manifest graphs, and the prove input hash.

### Writing a spec patch (`.ads`)

A spec patch mirrors the vendored spec: same package name, same subprogram
declarations (with docstrings, since strict mode requires them), plus the
aspects you want gnatprove to prove:

```ada
--  .adacovex/patches/demo/deps/vt100/vt100.ads
package VT100 with SPARK_Mode => On is

   --  Scroll a region of the screen up.
   --  @param From  Starting line of scroll region.
   --  @param To    Ending line of scroll region.
   procedure Scroll_Screen (From : in Natural; To : in Natural)
     with Pre => From <= To;

end VT100;
```

The merge splices the package-level aspect onto the original package
declaration line and replaces each aspect-carrying subprogram declaration
with the patch's declaration block. Subprograms the patch does not re-declare
with aspects are left untouched, so a patch can add a contract to one
subprogram without disturbing its siblings.

### Writing a body patch (`.adb`)

The spec patch declares the contracts. The **body patch** is what makes
gnatprove actually analyse the vendored body (the body-must-opt-in rule). It
lives at the body's relative path and mirrors the body's declarations with
*stub bodies* that the merge ignores -- the original implementation is
preserved:

```ada
--  .adacovex/patches/demo/deps/vecmath/vecmath.adb
package body Vecmath with SPARK_Mode => On is

   function Clamp (Value : in Integer; Lo : in Integer; Hi : in Integer)
     return Integer with SPARK_Mode => On is
   begin
      null;  --  stub: the original body's implementation is kept
   end Clamp;

end Vecmath;
```

The merge replaces the original declaration (up to its `is`) with the
patch's aspect-carrying declaration and keeps the original body proper, so
the copy gnatprove sees is `package body Vecmath with SPARK_Mode => On is
... <original implementation> ...`. A fully SPARK-clean body needs only the
 package-level aspect. The per-subprogram aspect covers bodies with a mix of
 clean and I/O-bound subprograms.

### Matching rules

The merge matches each patched declaration against the original by **name and
normalised parameter profile**:

- Matching is whitespace-insensitive. A single-line parameter list matches a
  multi-line one.
- The default `in` mode is equivalent to a bare mode (`X : in Integer` matches
  `X : Integer`). `in out` and `out` are distinct modes.
- an overloaded subprogram patches its exact signature -- a patched
  two-argument `Scroll_Screen` replaces the two-argument original, never a
  same-named sibling;
- a spec declaration terminates at its `;`, a body declaration at its `is`;
- a patched subprogram with **no match** in the original fails loudly (the
  patch is skipped and reported) rather than silently dropping the contract.

### Worked example: `Vecmath.Clamp`

A vendored package whose spec and body carry no contracts:

```ada
--  demo/deps/vecmath/vecmath.ads (vendored, unmodified)
package Vecmath is
   function Clamp (Value : in Integer; Lo : in Integer; Hi : in Integer)
     return Integer;
end Vecmath;
```

```ada
--  demo/deps/vecmath/vecmath.adb (vendored, unmodified)
package body Vecmath is
   function Clamp (Value : in Integer; Lo : in Integer; Hi : in Integer)
     return Integer is
   begin
      if Value < Lo then
         return Lo;
      elsif Value > Hi then
         return Hi;
      else
         return Value;
      end if;
   end Clamp;
end Vecmath;
```

The two patch files from above (spec with
`Pre => Lo <= Hi, Post => Clamp'Result in Lo .. Hi`, and body with
`SPARK_Mode => On`) merge into the copy unchanged in behaviour. gnatprove
proves the contract: 2 VCs (the `Clamp` postcondition and its termination
check), 0 unproved. A caller in the target's own code can then rely on the
contract without the vendored sources ever changing.

### When contracts prove -- and when they are skipped

- **SPARK-clean body + body patch** -- gnatprove proves the patched
  contracts outright (the example above).
- **I/O-bound body** (calls `Ada.Text_IO`, which is `SPARK_Mode Off`) --
  gnatprove skips the I/O bodies by design and reports the unit out of proof
  scope. The contracts are still *declared* and the mechanism is exercised,
  but the body is not proved -- and crucially, it never drags the target's
  proof level down. This is the VT100 dogfood case in
  [Ada_CRDT](https://github.com/bladeacer/Ada_CRDT).

### Common pitfalls

- **Spec patch without a body patch.** A SPARK-clean vendored body stays out
  of proof scope. gnatprove reports "no checks generated" or skips the unit.
  Add the `.adb` patch to opt the body in.
- **A patched declaration that does not match anything.** Check the name and
  the parameter list (modes included) against the original. The merge reports
  `could not be merged ... (unmatched subprogram or oversized file)` and skips
  the patch.
- **Patching the wrong overload.** The match is profile-aware, so a patch
  entry replaces exactly the signature it re-declares -- verify you wrote the
  same parameter list as the overload you mean.
- **Expecting contracts to prove against a non-SPARK body.** `Ada.Text_IO`
  and other `SPARK_Mode Off` dependencies cannot be analysed; the patch still
  applies, but the proof does not cover those bodies.

## See also

- [SPARK assurance levels](../api-docs/adacovex-spark-levels.md) -- Stone to
  Platinum, per-category objectives
- [CLI reference -- the `prove` subcommand](../usage/cli-reference.md#the-prove-subcommand)
  -- flags, gnatprove resolution, the fall-through assessment
- [CLI reference -- CI threshold gates](../usage/cli-reference.md#ci-threshold-gates---require-)
  -- `--require-spark` / `--require-proof` / `--require-tests`
- [Target project requirements](../usage/target-projects.md) -- what a project must provide
- [Architecture -- proof patches](architecture.md#proof-patches-spark-contracts-over-vendored-dependencies)
  -- the design, the merge engine, and the patched-copy pipeline
- [Performance](perf.md) -- benchmark categories for the prove scenarios and
  the current timings
- [The proof ledger](../proof/16.1.0-ledger.md) -- how adacovex's own proof
  is tracked
