# adacovex 1.16.0

Date: _2026-08-19_
Version bumped 1.15.0 -> 1.16.0.

## Changes

### C1: proof patches prove SPARK contracts over vendored dependencies

Vendored dependencies can now participate in the SPARK proof without
modifying their sources. The same `.adacovex/patches/<relative-path>` file
that overlays docstrings can carry **proof aspects**: a patch containing any
of `SPARK_Mode`, `Pre =>`, `Post =>`, or `Global =>` is detected by the new
`Adacovex.Prove_Patch.Has_Proof` and becomes a *proof patch*; a docstring-only
patch keeps working as a pure overlay and never engages the proof machinery.

The `prove` subcommand merges proof patches before running gnatprove
(`Run_Prove` integration in `adacovex-prove.adb`):

1. `Count_Proof_Patches` scans `<target>/.adacovex/patches/` for `.ads` and
   `.adb` patch files; a target with no proof patches is proved against its
   own tree exactly as before.
2. `Build_Patched_Copy` copies the target tree (excluding `.git`, `obj`,
   and `.adacovex`) into `<target>/obj/adacovex-proof/` and overwrites each
   proof-patched source with its merged form -- package-level aspects
   spliced onto the package declaration line (a `package body ... is`
   declaration included), and each aspect-carrying subprogram declaration
   replaced by the patch's declaration block. The merge engine (`Apply`)
   matches on name **and** normalized parameter profile, so an overloaded
   subprogram patches its exact signature and never a same-named sibling;
   the default `in` mode is equivalent to a bare mode (`in out` and `out`
   stay distinct). Spec declarations terminate at their `;`, body
   declarations at their `is` -- a patched body declaration is replaced
   without touching the body proper. An unmatched patch reference fails
   loudly instead of being silently dropped.
3. gnatprove runs against the copy's root project and the resulting
   `gnatprove.out` is copied back to `<target>/obj/gnatprove/gnatprove.out`
   for the assessment pipeline. The copy lives under the target's `obj/`,
   so it is excluded from scanning, manifest graphs, and the prove input
   hash. The originals are never touched.
4. Proof-patch contents are folded into the prove result-cache key, so a
   patch edit invalidates the cached proof and forces a re-prove.

The two patch shapes: a **spec patch** (`.ads`) re-declares the vendored
spec with contracts; a **body patch** (`.adb`) opts the vendored body into
the proof -- gnatprove analyzes a unit's body only when the body itself
declares `SPARK_Mode => On`, so a SPARK-clean vendored body needs both.
Where the body is SPARK-clean and opted in, gnatprove proves the patched
contracts (the documented `Vecmath.Clamp` worked example proves its
`Post => Clamp'Result in Lo .. Hi` outright -- all of its VCs proved, none
unproved); where it is
not (e.g. bodies that call `Ada.Text_IO`, which is `SPARK_Mode Off`),
gnatprove skips the I/O bodies by design and reports the unit out of proof
scope -- a proof patch never drags the target's proof level down.

The Ada_CRDT dogfood target proves the mechanism end to end: its
`.adacovex/patches/demo/deps/vt100/vt100.ads` now declares `SPARK_Mode =>
On` on the vendored package and pins the `Scroll_Screen (From, To)`
scroll-region contract, and both `make run-ada-crdt` and Ada_CRDT's own
`make prove` run through the patched copy, preserving the target's proof
(576 VCs, Platinum, DAL-C, 0 unproved). The merge engine is covered by the
new `Proof patches` test category (C3). The patched-tree design and the
patch file format are documented in the new *Proof patches: SPARK contracts
over vendored dependencies* section of `docs/architecture.md` and in
AGENTS.md's patch-directory section.

### C2: server routes made testable

`Adacovex.Server.HTTP` now exposes the request-path mapping as a pure,
SPARK-analyzed function: `Route_Kind` and `Route (Path)` return the route
kind (`Root`, `Badge_Spark`, `Badge_Tests`, `Badge_DO178C`, `Badge_ISO26262`,
`Badge_IEC62304`, `API_Metrics`, or `Not_Found`) and `Handle_Request`
case-dispatches on the result instead of matching path strings inline. The
route mapping carries a full characterization postcondition, so the server's
badge surface is provable rather than only exercised.

The new `Server routing` test category (C3's sibling, 24 tests) pins the
exact mapping for every route the server actually serves -- dashboard,
all five `/badge/*.svg` endpoints, `/api/metrics`, and unknown paths -- so
the dispatch table cannot drift from the routes `Handle_Request` serves.

### C3: proof-patch merge engine tests

New `Proof patches` test category (35 tests) covering the merge engine in
`Adacovex.Prove_Patch.Apply`: package-aspect splicing onto the package
declaration line (specs and `package body` declarations), subprogram
declaration replacement (spec `;` and body `is` terminators), profile-aware
matching that distinguishes overloads (the exact `Scroll_Screen` no-arg vs
two-arg case from the vt100 dogfood) and treats the default `in` mode as
bare (`in out` stays distinct), unmatched-patch rejection, and
patch-content hashing for the prove cache key.

### C4: documentation -- a dedicated proving guide, HLR/LLR links, and full CLI coverage

Proving moved from scattered design notes to a dedicated user-facing page:
new `docs/proving.md` -- *Proving and writing SPARK proofs* -- covers how
`adacovex prove` works (gnatprove resolution, the fall-through assessment,
the result cache), what a proof contains (the VC categories and the
Stone..Platinum model), how to write SPARK contracts (the
body-must-opt-in rule, why `Ada.Text_IO` bodies are skipped), and the full
proof-patch section: **why** patches exist for vendored deps (strict mode
counts vendored code, bodies must opt in, sources are immutable), **how**
to write the `.ads` spec patch and `.adb` body patch, the matching rules, a
worked `Vecmath.Clamp` example that proves its contract, and a pitfalls
section. The page is linked from the README documentation table, AGENTS.md's
Documentation block, the CLI reference, target-projects, and architecture.

The CLI reference gained the missing first-class surfaces: a full **`prove`
subcommand** section (its eight options, the fall-through to the assessment
pipeline, gnatprove resolution, the patched-copy proof tree, and the cache /
`--force` semantics), the **`--no-sbom` / `--sbom-format`** flags for the
automatic SBOM every assessment writes, and **`man --force`** -- and
`docs/sbom.md` now documents the Markdown (`md`) SBOM format alongside
CycloneDX and SPDX. The internal traceability documents `docs/HLR.md` and
`docs/LLR.md` are now linked from the README and AGENTS.md documentation
lists.

## Test Suite

850 tests (was 791), across 14 categories: the C2 `Server routing` category
adds 24 tests (new category) and the C3 `Proof patches` category adds 35
(new category) -- the only test changes; the SVG renderer category stays at
161. All other changes (C1/C2) add aspects and contracts without changing
behavior. The regenerated `docs/badges/*.svg` geometry is unchanged and the
`make run-ada-crdt` dogfood regression still passes. Counts synced with
`make test-count`.

## Proof Results

Platinum, 487/487 VCs proved across 48 analyzed units (up from 484 at
1.15.0): the C2 `Route` mapping in `server-http` (newly `SPARK_Mode => On`
with its path-to-route postcondition) and the newly analyzed units
(`prove_patch`, `server_tests`, `prove_patch_tests`) added 3 provable checks
(484 to 487) -- 230 run-time checks, 78 assertions, 52 functional contracts,
45 data-dependency checks, 4 initialization checks, and 78 termination
checks, all proved. 0 unproved, 0 justified; the I/O- and container-heavy
`prove_patch` bodies stay default-off, so gnatprove analyzes only the
SPARK-clean helpers, exactly as before. Proven with `make prove` under
gnatprove 16.1.0 (`--steps=10000`).

## Traceability

No new HLRs. The proof-patch machinery extends the existing `HLR-PROVE`
tag (`src/core/adacovex-prove_patch.ads`/`.adb` alongside
`adacovex-prove`), covered by the C3 merge-engine tests and the Ada_CRDT
dogfood regression (`make run-ada-crdt`), and documented in the new
`docs/proving.md` guide, `docs/architecture.md`, and AGENTS.md. The
C4 documentation changes are documentation-only (new `proving.md`
page, README/AGENTS.md link tables, CLI-reference and sbom.md coverage) and
carry no HLR tags. The C2 route mapping extends
`HLR-SERVER` / `LLR-SERVER-01`: `Route` is the single pure mapping behind
every `/`, `/badge/*.svg`, and `/api/metrics` route that `Handle_Request`
serves, pinned by the C2 `Server routing` tests and proved by its
postcondition. None of the changes introduce new high-level requirements;
the two new test categories extend the coverage of the existing
`HLR-PROVE` and `HLR-SERVER` tags.
