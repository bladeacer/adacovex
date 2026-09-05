# Architecture: verification and proof patches

This page covers the verification machinery: the IR synthesiser, the DO-178C DAL assessment criteria, source scanning, and the patch system (including proof patches that add SPARK contracts over vendored dependencies).  The dependency and proof-level design is on [Architecture Decisions](architecture.md); the renderers, caching, delivery, and execution order are on [Architecture: outputs and pipeline](architecture-outputs.md).

## IR Synthesiser

The `src/ir/` layer starts an intermediate representation for
cross-compilation assessments, so the tool can reason about types as they
exist on a target rather than only as they appear in Ada source:

- `Adacovex.Target_Profiles` defines bounded machine-integer types
  (`IR_Int8`..`IR_Int64`, `IR_UInt8`..`IR_UInt64`) with `Size` clauses and a
  `Target_Config` record (host/target/pointer word sizes). The types are
  SPARK-proved: `Checked_Add32` / `Checked_Add64` show overflow is detected,
  not undefined.
- `Adacovex.IR_Synthesiser` lowers foreign type names (`int8_t`, `size_t`,
  `usize`, `ptrdiff_t`, ...) onto the bounded IR types and synthesizes
  package declarations from a comma/whitespace-separated type list.
- `Adacovex.IR_Bounds` is a gnatprove fixture deriving synthesized-style
  `int32_t` / `int64_t` types and proving their `Add32` / `Add64` overflow
  checks, so absence of integer overflow on the lowered types is
  machine-checked.

## DO-178C DAL Compliance

The DAL assessment evaluates four criteria:

1. All HLRs defined in `docs/compliance/HLR.md` are traced by `-- HLR-XXXX` tags in source
2. No orphan tags (every in-source HLR maps to a defined HLR)
3. All tests passing (zero failures in `test_result.md`)
4. Minimum SPARK proof level met (varies by DAL level)

DAL-C is the default target level. Higher levels (A, B) require stricter proof levels (Gold, Silver respectively).

## Source Scanning

The scanner walks the target directory tree, skipping always-excluded directories (`.git`, `obj`, `tests`, `config`, `.adacovex`). For each `.ads` file found, it extracts:

- Package name from filename
- Subprogram declarations (`procedure`, `function`, `generic procedure`, `generic function`, and `overriding` / `not overriding` variants)
- Docstring annotations (`--  ` prefix with optional `@param`, `@return`, `@field`, `@formal` tags, plus Google `Args:`/`Returns:` blocks and Sphinx `:param:`/`:returns:` fields)
- HLR traceability tags (`-- HLR-XXXX`)

In strict mode (default), the scanner also applies docstring patches from `.adacovex/patches/` to document vendored/third-party code without modifying the originals.

A file can opt out of an individual analysis gate with a marker in its leading comment block: `no-covex-complexity-scan`, `no-covex-docstrings`, `no-covex-spark-proof`, or `no-covex-analysis` for all three. The scanner honours the docstring and proof markers when it reads each `.ads` header; the complexity checker applies the complexity marker to every scanned language, and the `prove` subcommand applies the proof marker to the root project's units (via gnatprove `-u`). See the [CLI reference -- per-file opt-out markers](../usage/cli-reference-flags.md#per-file-opt-out-markers) and `Adacovex.Opt_Outs`.

## Patch System

The `.adacovex/patches/` directory overlays docstring information onto
third-party or vendored code that cannot be modified directly, so strict mode
can still reach 100% docstring coverage without touching the originals.

### Why patches exist

In strict mode (default), all directories except `.git`, `obj`, `tests`,
`config`, and `.adacovex` are scanned. Vendored dependencies (for example a copy of
vt100 in `demo/deps/vt100/`) are scanned, and their undocumented subprograms
count against docstring coverage. Patches document them in place.

### Patch file format

A patch file is a valid Ada `.ads` file containing only the subprogram
declarations to document, each preceded by a docstring:

```ada
--  Package-level comment (optional, not used by patch engine).
package VT100 is

   --  Summary of the procedure.
   --  @param Name  Description.
   procedure Some_Procedure (Name : in Some_Type);

   --  Another procedure with no params.
   procedure No_Param_Proc;

end VT100;
```

Rules:
1. File name must match the original `.ads` (for example `vt100.ads`).
2. Subprogram names must match the originals exactly.
3. Only subprograms with preceding docstrings (`--  ` lines) are merged.
4. Overloaded subprograms: one patch entry per overload. Each patches the next
   undocumented original with the same name.
5. The scanner merges `Has_Docstring`, `Doc_Param_Ct`, and `Doc_Return` into
   the matching originals.

### Patch file location

```
<target-project>/.adacovex/patches/<relative-path>
```

`<relative-path>` is the path from the target root to the `.ads` file. Example:
to patch `Ada_CRDT/demo/deps/vt100/vt100.ads`, create
`Ada_CRDT/.adacovex/patches/demo/deps/vt100/vt100.ads`. The `.adacovex`
directory is always excluded from source scanning.

### Proof patches: SPARK contracts over vendored dependencies

The same `.adacovex/patches/<relative-path>` file can carry **SPARK proof aspects** in addition to docstrings, so vendored dependencies participate in the SPARK proof without modifying their sources. A patch file that includes any of `SPARK_Mode`, `Pre =>`, `Post =>`, or `Global =>` (detected by `Adacovex. Prove_Patch. Has_Proof`) is a *proof patch*.

A patch with only docstrings remains a docstring overlay and never engages the proof machinery. This section is the design. For the user-facing guide -- how proving works, writing SPARK contracts, and the `.ads`/`.adb` patch files with worked examples and pitfalls -- see [Proving and writing proofs](proving.md).

```ada
package VT100 with SPARK_Mode => On is

   --  Scroll a region of the screen up.
   --  @param From  Starting line of scroll region.
   --  @param To    Ending line of scroll region.
   procedure Scroll_Screen (From : in Natural; To : in Natural)
     with Pre => From <= To;

end VT100;
```

The `prove` subcommand merges proof patches before running gnatprove:

1. `Count_Proof_Patches` scans `<target>/.adacovex/patches/` (`.ads` and
   `.adb` patch files). A target with no proof patches is proved against
   its own tree exactly as before.
2. `Build_Patched_Copy` copies the target tree (excluding `.git`, `obj`,
and `.adacovex`) into `<target>/obj/adacovex-proof/` and overwrites each proof-patched source with its merged form -- package-level aspects spliced onto the package declaration line (for a `package body ... is` declaration too), and each aspect-carrying subprogram declaration replaced by the patch's declaration block. The merge matches on name **and** normalised parameter profile (`Param_Profile`), so an overloaded subprogram patches its exact signature and never a same-named sibling. The default `in` mode is equivalent to a bare mode. `in out` and `out` are distinct. A spec declaration terminates at its `;`, a body declaration at its `is` -- so a patched body declaration is replaced without touching the body proper.

The original vendored sources are never touched.

3. gnatprove runs against the copy's root project (`<copy>/<basename>.gpr`)
   and the resulting `gnatprove.out` is copied back to
   `<target>/obj/gnatprove/gnatprove.out` for the assessment pipeline. The
   copy lives under the target's `obj/`, so it is excluded from scanning,
   manifest graphs, and the prove input hash.
4. Proof-patch contents are folded into the prove result-cache key, so a
   patch edit invalidates the cached proof and forces a re-prove.

#### The two patch shapes

A **spec patch** (`.ads` in the patch directory) re-declares the vendored
spec with contracts, exactly as the VT100 example above. gnatprove analyses
a unit's body only when the *body itself* opts in (`SPARK_Mode => On` on
the package body or a subprogram body), so a SPARK-clean vendored body also
needs a **body patch** (`.adb` in the patch directory) that declares the
intended mode. The body patch mirrors the body's declarations with stub
bodies that the merge ignores -- the original body proper is preserved:

```ada
--  .adacovex/patches/demo/deps/vecmath/vecmath.adb
package body Vecmath with SPARK_Mode => On is

   function Clamp (Value : in Integer; Lo : in Integer; Hi : in Integer)
     return Integer with SPARK_Mode => On is
   begin
      null;  --  stub: replaced by the original body's implementation
   end Clamp;

end Vecmath;
```

A worked example end to end: a vendored `Vecmath.Clamp` whose original
spec and body carry no contracts, with the spec patch above declaring
`SPARK_Mode => On` plus `Pre => Lo <= Hi, Post => Clamp'Result in Lo .. Hi`
and the body patch opting the body into the proof. The merged copy is what
gnatprove sees -- `package body Vecmath with SPARK_Mode => On is` with the
original `if Value < Lo ... return Value` implementation intact -- and the
contracts prove: 2 VCs (the `Clamp` postcondition and its termination
check), 0 unproved.

Where the vendored body is SPARK-clean and opted in via a body patch,
gnatprove proves the patched contracts. Where it is not (for example bodies
that call `Ada.Text_IO`, which is `SPARK_Mode Off`), gnatprove skips the I/O
bodies by design and reports the unit out of proof scope -- a proof patch
never drags the target's proof level down. The Ada_CRDT dogfood target
proves the mechanism end to end: its
`.adacovex/patches/demo/deps/vt100/vt100.ads` declares `SPARK_Mode => On`
on the vendored package and pins the `Scroll_Screen` scroll-region
contract (its bodies are Text_IO-bound, so gnatprove skips them by design),
and `make run-ada-crdt` / Ada_CRDT's `make prove` run through the patched
copy, preserving the target's proof.
