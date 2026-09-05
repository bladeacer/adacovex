# Proof patches: SPARK contracts over vendored code

This page is the guide to proof patches: why they exist, how the `prove` subcommand applies them, writing `.ads` and `.adb` patches, matching rules, worked examples, and the common pitfalls.  The design (the merge engine and patched-copy pipeline) is on [Architecture: verification and proof patches](architecture-verification.md).  Proving a project and writing SPARK contracts are on [Proving and writing SPARK proofs](proving.md).

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

### Opting a unit out of the proof (`no-covex-spark-proof`)

A unit that must not participate in the proof can opt out with a marker in
its leading comment block: `no-covex-spark-proof` (or `no-covex-analysis`
for every gate). Put the marker on the unit's `.ads` spec; the body is
excluded with it.

```ada
--  no-covex-spark-proof
package Generated_Spec is
   ...
```

`adacovex prove` then runs gnatprove with `-u` plus every project unit
except the opted-out ones, so the unit's checks never appear in the output
and never count against the proof metrics. The exclusion works for units of
the root project (those under the root `.gpr`'s literal `Source_Dirs`); when
the `Source_Dirs` attribute is not a plain literal list, adacovex cannot
enumerate the project safely and warns that the opt-out was not applied.
This is the escape hatch for generated or legacy units that cannot be
brought into SPARK -- prefer a proof patch when the unit *can* be proved.

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
