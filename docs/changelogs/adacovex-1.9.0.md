# adacovex 1.9.0

Date: _2026-08-14_

Version bumped 1.8.0 -> 1.9.0.

## Changes

### C1: Honest GNATprove parse across gnatprove v15/v16

`Adacovex.Parsers.GNATprove` now reconciles the command-line `Summary of
SPARK analysis` "Total" row between gnatprove 15.x and 16.x: the row layout
differs between versions (the prover and unproved columns are centered and
the "Justified"/"Unproved" columns are blank (`.`) in one format and populated
in the other). A field-based reader (`Get_Column_Number`) extracts each column
by its padded column span instead of by "nth number in the line", so a
justified-VC percentage that was mistaken for the unproved percentage on the
   shared 15.x/16.x layout no longer corrupts the summary. This fixes the
   self-assessment: the previous "Platinum / all VCs proved" report was a parser
   artifact that read the unproved column as zero. The honest level immediately
   after this fix was Silver; the proof fixes in C5 then closed the real gap, so
   the self-assessment is genuinely Platinum again (see Proof Results).

### C2: Global gnatprove version pin (`adacovex.toml` / env)

`covex prove` resolves `gnatprove` as: **manifest pin > global pin > PATH >
cache > download**. A new global pin -- the `ADACOVEX_GNATPROVE_VERSION`
environment variable or the `[prove] gnatprove-version = "16.1.0"` key in
`~/.adacovex/adacovex.toml` -- deploys the exact gnatprove binary crate
standalone via `alr -n get` and runs it directly, with the same
authoritative, never-fall-back semantics as a manifest pin. It applies only
to projects whose own manifest does not declare gnatprove (the manifest pin
always wins), so a single workstation/CI can fix every proof on one prover
without touching each project's manifest. The provenance and the pin are
folded into the proof result-cache identity, so proofs from different provers
never mix.

### C3: CI threshold gates (`--require-spark` / `--require-docstrings` / `--require-tests` / `--require-proof`)

Four `--require-*` flags add explicit minimum-bar checks on top of the DAL
criteria. Off by default; when set, the assessment fails loudly (exit code 1
with an explicit `CI GATE:` reason) if the target falls below the required
level: `--require-spark=LVL` (Stone..Platinum), `--require-docstrings=PCT`
and `--require-proof=PCT` (percent, 0-100), and `--require-tests=N` (passing
test count). The GitHub Action exposes matching `require-spark`,
`require-docstrings`, `require-tests`, and `require-proof` inputs. Because a
stricter gnatprove can legitimately leave more VCs unproved, the gates are
designed to be set against the results of the prover actually pinned.

### C4: Honest SBOM proof level

`Adacovex.Renderers.SBOM.Proof_Level_Property` now reports the assessed level
verbatim (`Stone`..`Platinum`) instead of collapsing every non-Platinum result
to `"Gold"`, so an SBOM never overstates assurance (Silver with unproved VCs
is reported as `"Silver"`). The proof-level postcondition was widened to the
full range accordingly.

### C5: Proof fixes to 0 unproved (Platinum under gnatprove 16.1.0)

Eliminated every unproved VC so the self-assessment reaches **Platinum**:
**343 VCs, 343 proved, 0 unproved** across 38 analyzed units under gnatprove
16.1.0, with no `SPARK_Mode(Off)` and no justified VCs. The bulk of the debt
was solver step-limit timeouts, not genuine proof gaps; the rest needed real
contract and structure fixes:

- `covex prove` now passes `--steps=5000` by default (an explicit `--steps=`
  still wins), replacing gnatprove's low default step budget that reported
  "provers reached step limit" as unproved VCs. The CLI `--steps` default
  stays `-1` so non-prove invocations are unaffected.
- `Adacovex.Renderers.SBOM`: strengthened the `I2S`/`Pad2` contracts with
  `Result'First`/`Result'Last` bounds; restructured the ISO epoch year/month
  loops behind explicit guards with a `Days_Remaining` loop invariant; hoisted
  per-iteration helper calls into constants; guarded `Dy + 1`; extracted the
  timestamp `&` chain into an `Assemble_ISO` helper with a tight `Pre`; and
  delegated the `Proof_Level_Property` postcondition to `Types.To_String`.
- `Adacovex.IR_Synthesiser`: narrowed the append cursor `RLen` to
  `Natural range 0 .. Max_Pkg_Len` so the buffer write can never overflow
  `Natural'Last`.
- `Adacovex.Parsers.Tests`: added a cursor-bound assert inside the
  `K >= S'First` guard of `Number_Before_Word` so the quantified digit-check
  loop invariants can discharge their array-access checks.

The earlier "509 VCs / 168 unproved / Silver" figure is not reproducible by
any documented gnatprove invocation and was retired; see
`docs/proof/16.1.0-ledger.md`.

### C6: Manifest-declared dependencies registered in the SBOM graph

`Adacovex.Parsers.Manifest.Build_Dependency_Graph` now registers every
dependency declared in the manifests even when no GPR `with`-clause or
`alire.lock` entry resolves it: base deps from `alire.toml` (scope `base`)
and dev deps from `alire-dev.toml` (scope `dev`). Previously the manifest was
parsed only to classify the scope of GPR/lock-resolved components, so a
zero-`with` project whose toolchain deps live solely in `alire-dev.toml`
(e.g. adacovex itself: `gnatprove`, `gnatdoc_bin`, `gnatformat_bin`) produced
an SBOM with no dependency components. Unresolved manifest deps appear
name-only with a `pkg:alire/<name>` purl, exactly like GPR-only deps.

### C7: GNATprove info-warning cleanup

Removed the persistent `info:` noise from the standard prove run by making
gnatprove analyze each flagged subprogram independently:

- `Min_SPARK_For` and `Need_Tests` moved from the body of
  `Adacovex.Compliance.DAL` into the spec (public API with docstrings), so
  they are no longer "only analyzed in the context of calls".
- `Starts_With` moved from the body of `Adacovex.Parsers.Tests` into the spec,
  dropping its in-context-analysis note.

The remaining in-context note (`Append`'s nested loop in
`Adacovex.IR_Synthesiser`) is left as-is: hoisting it to package level to
silence the note introduced unproved range-check VCs, so the benign message
was kept over worse proof debt.

## Test Suite

368 tests (was 336 native + new cases). Added: gnatprove v15/v16 Total-row
reconciliation cases (`Get_Column_Number`), CI-threshold default/set checks in
`adacovex_config_tests` (the CLI gnatprove-version pin was removed), the
honest SBOM proof-level mapping in `adacovex_sbom_tests`, and a
both-manifests fixture in `adacovex_sbom_tests` verifying base/dev manifest
deps are registered without GPR `with`-clauses or a lockfile.

## Proof Results

Self-assessment reports **Platinum**: **343 VCs, 343 proved, 0 unproved** under
gnatprove 16.1.0 across 38 analyzed units (no justified VCs). gnatprove 16.1.0
generates stricter overflow/counterexample checks than 15.x; after the C1
parser fix the honest level was Silver, and the C5 proof fixes (plus the
`--steps=5000` default) then discharged every remaining VC. The interim
"509 VCs / 168 unproved / Silver" figure was a stale count that no documented
gnatprove invocation reproduces. The CI gates
(`require-spark=Platinum`, `require-proof=100` in the Makefile and workflows)
match this state.

## Traceability

No new HLR tags were added. The changed packages are covered by the existing
tags:
- `-- HLR-PROOF` on `Adacovex.Parsers.GNATprove` -- parser reconciliation.
- `-- HLR-PROVE` on `Adacovex.Prove` -- global gnatprove pin + resolution order,
  default `--steps=5000` proof budget.
- `-- HLR-CLI` on `Adacovex.Config` -- `--require-*` CI gates (CLI parsing).
- `-- HLR-SBOM` on `Adacovex.Renderers.SBOM` -- honest proof-level property,
  ISO epoch proof fixes.
- `-- HLR-IR` on `Adacovex.IR_Synthesiser` -- bounded append-cursor fixes.
- `-- HLR-TEST` on `Adacovex.Parsers.Tests` -- digit-scan cursor bound.
- `-- HLR-MANIFEST` on `Adacovex.Parsers.Manifest` -- manifest-declared
  base/dev deps registered in the SBOM dependency graph.