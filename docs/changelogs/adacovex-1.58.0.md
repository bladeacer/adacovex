# adacovex 1.58.0

Date: _2026-10-04_

Version bumped 1.57.0 -> 1.58.0.

## Changes

### C1: The SimpleEnglish skill is now a named third-party component in both notices

The skill is the one third-party work that adacovex vendors into its own
source tree, and neither notices file presented it that way. `docs/CREDITS.md`
gave it a single sentence under a heading named Technical writing guidance, and
`docs/THIRD_PARTY_NOTICES.md` did not mention it at all. A reader who wanted to
know what the documentation rules came from, and under what licence, had to
find `skills/simple-english/` unassisted. The attribution existed, and it was
too quiet to serve as a licence notice.

Both files now carry the skill as a named component with the same detail in
each:

- `docs/CREDITS.md` replaces the Technical writing guidance section with a
  `## SimpleEnglish skill` section placed above the third-party component
  summary. It names the upstream project, the vendored path, the four files the
  directory holds, the MIT licence, and the link to the licence terms.
- `docs/THIRD_PARTY_NOTICES.md` gains a `## Vendored agent skill: SimpleEnglish`
  section ahead of the toolchain section, in the table shape the rest of the
  file uses. The row states the version (1.3.0, ASD-STE100 Issue 9 of
  2025-01-15), the MIT licence with its URL, and the use.
- Both files now state the two project overrides outside `AGENTS.md`:
  British English spelling replaces the American spelling that rule 1.14 names,
  and a paragraph holds at most four sentences, not the six of rule 6.6.
- Both files now point at the controlled list of Technical Names, which is where
  a writer goes before using a word that the standard does not define.

The two notices differ in purpose, so they differ in emphasis. The credits page
tells a reader what shapes the documentation. The notices page tells a
distributor what licence covers a directory in the tree, and it says that the
copy is unmodified upstream text that ships at every checkout, so the notice
covers every reader of the tree and not only the built binary. Both pages state
that the skill governs prose only: it is not linked into the binary, it runs no
code at build time, and no generated file comes from it.

The sibling Ada_CRDT project received the same change in crdt 1.17.0, so the
two trees describe the vendored skill the same way.

### C2: The `spark-coverage` subcommand reports proof coverage as three separate metrics

`adacovex spark-coverage [--target=PATH]` reports how much of the SPARK proof
the target has completed. It reads `obj/gnatprove/gnatprove.out` and
`obj/gnatprove/gnatprove.sarif`; it never runs the prover, so run
`adacovex prove` first. The report carries statement, subprogram, and VC
coverage as three separate metrics, each with its proved and total counts.

`--group=file|folder|package` selects the grouping of the report, and
`--spark-format=json` prints the machine-readable form. `--min-coverage=PCT`
hides group rows below a verified percentage from the display; it filters the
view only and never changes a gate result. The report also breaks the unproved
work into its off classes: irreducible, I/O-bound, work queue, and not covered.

The docs entry is the new `spark-coverage` section of the CLI reference. The
new SPARK coverage test category covers metric selection, grouping, the JSON
report form, and the coverage-gate arithmetic.

### C3: The dashboard and the JSON API carry the proof-coverage report

The Proof tab of the dashboard gains a SPARK proof coverage card. It shows the
statement, subprogram, and VC metrics, the off-class breakdown, and a per-file
table whose column headers sort the table on click. The JSON API gains the
`/api/spark` route, which returns the same data the card renders, and the API
catalog in the dashboard docs lists the route.

`resources/spark.js` is bundled into the dashboard template by
`tools/gen-dashboard.py`, and the server dispatches the route through the same
path as the other API endpoints. The dashboard pages document the card and the
route.

### C4: The coverage gate ships in the CLI, the Action, and the docs

`--require-coverage=PCT` together with
`--gate-metric=statements|subprograms|vcs` exits `1` when the named metric's
proved share falls below the threshold. The failure names the metric, its
numerator, its denominator, and the achieved value. A missing `gnatprove.out`
or `gnatprove.sarif` is also a loud `1`, not a silent pass.

The composite Action gains the `require-coverage` and `gate-metric` inputs,
which map one to one onto the two flags, and `docs/usage/ci-cd.md` gains their
input-table rows. The `action-parity-check` gate holds the three surfaces in
step. The display-only flags (`spark-coverage`, `group`, `metric`,
`spark-format`, `min-coverage`) sit in its `CLI_ONLY` allow-list, because they
drive no CI decision. The end-to-end suite gains checks for the
spark-coverage flags and the gate.

### C5: A tldr page and its lint gate

The tree gains `docs/tldr/adacovex.md`: one-page quick-start examples for the
main workflows, written in the tldr pages format. `tools/check-tldr.py` lints
the page against the tldr style rules, and `make tldr-check` runs it as a gate
inside `make check`. The page is reachable from the docs index and named in
the CLI reference.

### C6: The retired archive is removed from the docs tree

`docs/archive/` held three retired pages: the 16.1.0 proof-debt audit, the
pre-1.42 optimisation history, and the archive index. All three are deleted,
and every page that linked to them now points at the surviving record instead:
`docs/proof/index.md`, `docs/proof/16.1.0-ledger.md`, the optimisation
history page, the 1.49.0 changelog, and the docs index.
`tools/live_files.py` and the doc-links map drop the deleted paths, so the
sync gates no longer see them.

### C7: Thirteen subprograms join the proof

The sweep of default-off subprograms opts thirteen in-package subprograms into
`SPARK_Mode => On`: `Adacovex.CPUs.Parse_Natural`, the six helper
subprograms of `Adacovex.Parsers.Source`, and six of `Adacovex.Config`
(`Set_String`, `To_SPARK_Level`, `Edit_Distance`, `Normalize_Flag`,
`Normalize_Topic`, `Suggest_Flags`). Several needed a bounded rewrite to reach
zero unproved checks: `Parse_Natural` returns `-1` on overflow,
`Edit_Distance` caps its DP row at a bounded subtype with a 64 clamp,
`Normalize_Flag` walks `S'Range` instead of a cursor and now carries a
postcondition on its output length, and `Suggest_Flags` carries quantified
invariants over its match table. The sweep raises the analysed-unit count and
the VC total; the figures are in the Proof Results section below.

### C8: The performance pages state their build profile and re-measure the binary

The benchmark pages now name the build profile behind every figure. The
pipeline and prove timings page carries a build-profile note, and its new
generator-and-bundling section records the measured cost of the four code
generators and of the cold Sphinx build, so the "docs are not the bottleneck"
claim is a recorded number. The binary-size page re-measures the released
artifact after this change set, and states the raw and stripped sizes on this
tree.

## Fixes

### H1: The prove cache no longer reports a warm hit it did not restore

A stored summary that reports unproved VCs comes from a degraded run: the
prover exits `0` even when the solver times out. The cache dropped such a
poisoned blob on read, but the runner still printed "reusing prior proof",
returned success, and skipped the prover, so the pipeline parsed no
`gnatprove.out` and reported Stone with zero VCs. The restore now reports
whether a usable summary reached the canonical path, and the runner falls
through to a real gnatprove run when it did not.

The bug hides behind its own guard: the next run with unchanged inputs takes
the same short-circuit, so only a re-prove of an already-failed tree reaches
it. This release's own proof campaign did exactly that after a degraded run
and exposed it.

## Test Suite

1775 tests across 26 categories, up from 1756 across 25 in 1.57.0. The new
SPARK coverage category carries 18 checks over metric selection, grouping, the
JSON report form, and the coverage-gate arithmetic. Server routing gains one
check for the `/api/spark` dispatch. The end-to-end CLI suite gains checks for
the spark-coverage flags and the coverage gate.

`make test` runs the native suite, `make cli-e2e` runs the end-to-end suite,
and both pass on this tree.

## Proof Results

Unchanged at **Platinum**, 0 unproved, 0 justified, **884 of 884 VCs across 66
analysed units** under gnatprove 16.1.0 at `--level=4`. No Ada source,
contract, pragma, or aspect changed, so the figures were read from the
verification campaign of 1.57.0 rather than re-run, and no proof metric moved.

The version constant in `src/adacovex_version_info.ads` did change, because
`make bump-version` regenerates it. That unit is a generated string constant
with no verification condition, so the proof-input hash is unaffected in every
respect that carries a check.

## Traceability

No new HLR record enters this release, and no tag is added or removed. C1
changes documentation pages only, and no `HLR-*` tag covers a documentation
page: the tags name Ada packages and subprograms. The spark-coverage work of
C2 through C4 extends `HLR-SPARK`, on record since 1.57.0 for
`Adacovex.Spark_Coverage`: the subcommand, the gate, the API route, and the
dashboard card all report the three metrics that tag names.

The packages changed by this release, and the tags already on record that
cover them: `Adacovex.Config` (`HLR-CLI`), `Adacovex.CPUs` (`HLR-CPU`),
`Adacovex.Parsers.Source` (`HLR-SCAN`), `Adacovex.Renderers.HTML`
(`HLR-RENDER-HTML`), `Adacovex.Server.HTTP` (`HLR-SERVER`), `Adacovex.Prove`
(`HLR-PROVE`), and the CLI entry point (`HLR-ARCH`). The sweep in C7 adds no
new requirement: it moves existing in-package subprograms into the proved set.