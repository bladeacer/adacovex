# adacovex 1.58.0

Date: _2026-10-04_

Version bumped 1.57.0 -> 1.58.0.

<!-- no-covex-docs-loc: historical release record, line cap does not apply -->

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
- Both files state the two project overrides outside `AGENTS.md`: British
  English spelling replaces the American spelling that rule 1.14 names, and a
  paragraph holds at most four sentences, not the six of rule 6.6.
- Both files point at the controlled list of Technical Names, which is where a
  writer goes before using a word that the standard does not define.

The two notices differ in purpose, so they differ in emphasis. The credits page
tells a reader what shapes the documentation. The notices page tells a
distributor what licence covers a directory in the tree, and it says that the
copy is unmodified upstream text that ships at every checkout, so the notice
covers every reader of the tree and not only the built binary. Both pages state
that the skill governs prose only: it is not linked into the binary, it runs no
code at build time, and no generated file comes from it.

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
quantified invariant over its buffer, and `Suggest_Flags` carries quantified
invariants over its match table. H2 later replaced `Normalize_Flag` with
`Normalized`, which returns the same normalised text in a record. The sweep
raises the analysed-unit count and the VC total; the figures are in the Proof
Results section below.

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

### H2: `make prove` runs with no gnatprove warnings, and the fix costs no checks

A clean proof session on this tree printed seven `warning: initialization of
"X" has no effect` messages. Every one named a declaration whose initial value
flow analysis proved was dead: the variable is assigned before any read can
reach it, so the initialiser is a write that no path observes. Five were in the
C7 code (`Edit_Distance` carried `New_Val` and `Prev_Diag`, and
`Suggest_Flags` carried `NFlag` and `NLen`), and two more were in
`Parse_Natural`, which C7 also opted in.

Deleting the initialisers silences all seven, but it is not free. gnatprove can
no longer lean on the initialiser to establish a variable's type invariant, so
it proves that fact at the reads instead, and the campaign grows from 1053 to
1060 checks. That trade is avoidable, because the warning and the extra check
are two views of one fact. **A declaration whose initial value is dead and one
whose initial value is missing both cost something; the fix is to make the
initial value live.** Each of the five declarations was restructured so its
initial value is genuinely read:

- `Parse_Natural` loses `Stop` altogether. The digit run's end position was the
  only thing `Stop` held, and the function never read it after the loop, so one
  cursor now serves both scan phases.
- `Edit_Distance` loses `New_Val`, which becomes a `declare`-block constant read
  by the statements below it. `Prev_Diag` keeps its initialiser and stays
  warning-free because the recurrence now re-primes it at the *end* of each row
  rather than the start. `Row (0)` holds `I - 1` on entry to row `I` either way,
  so the two orderings compute the same value, and priming at the end leaves the
  initial value in place until the inner loop reads it.
- `Suggest_Flags` no longer owns `NFlag` and `NLen`. It passes an `out` buffer
  and an `out` length to `Normalize_Flag`, which writes both before returning,
  so both initialisers were dead. `Normalize_Flag` becomes `Normalized`, which
  returns the normalised text and its length in one `Normalized_Flag` record.
  The caller binds a single `constant`, which has a live initial value and so
  carries neither a dead write nor an initialisation check. The record's `Len`
  component carries the subtype `0 .. 64`, which is the postcondition the caller
  previously needed, so `Text (1 .. Len)` is in range without one.

The result is a session with no warnings and a *smaller* campaign: **1047
checks**, down from 1053. Six checks disappear because three declarations are
gone and the rest no longer need an initialisation proved at their reads. The
whole native suite passes, including the 349 CLI config checks that pin the
"did you mean" suggestions, and `Edit_Distance` returns the same distances for
the same inputs.

### H3: A past release's manifest no longer describes the current tree's proof surface

The crate description ended with a self-assessment line that carried a VC count,
and the sync tool wrote that line into every manifest it touched. A manifest is
a permanent record of one released version, so `covex-1.50.0.toml` ended up
claiming whatever the current campaign measured, which made the whole published
history wrong in a way that grew silently with every release.

The count is a vanity metric: it moves on almost every release and measures the
size of the proof surface rather than its quality. Platinum with 0 unproved and
0 justified is the claim worth publishing, and that figure does not drift. So
the description now states the SPARK level alone:

```
- Self-assessment: 100% docstring coverage, Platinum SPARK, DAL-C / ASIL B /
  Class A Achieved, 1775/1775 native tests passing
```

The fix covers all 114 manifests (56 `alire/releases/`, 57 `index/`, and the two
current ones), each rewritten against its own historical VC form rather than
against the current number, so one pass corrected every past value. The test
count stays, because `require-tests` gates on it and it tracks the suite.

`make description CHECK=1` is the gate that keeps this true, and it is already
wired into `make check`. Two files record the rule so it is not undone: AGENTS.md
places the VC count in the docs and the proof ledger only, and the docstring of
`tools/live_files.py` no longer justifies scanning the manifests by the very
phrase it removed.

### H4: `make check` formats before it gates

`fmt` ran eighteenth in the gate list, immediately before `build`. Everything
upstream of it therefore validated unformatted code, which is the wrong order
twice over. gnatprove analyses the sources, so the proof pass is the one gate
that must see formatted text, and it did -- but every static gate above it
checked a tree the formatter had not yet visited.

The order also left the generated API docs describing whatever formatting
`make doc` happened to find, because `doc` renders `docs/api-docs/` from the
Ada sources and ran long after the gates that had read the tree.

`fmt` now runs first, ahead of every other gate, so every gate that follows
judges the formatted tree. The ordering is verified rather than assumed: a
deliberately misformatted declaration was injected into
`src/core/adacovex-config.adb`, and the full gate run restored it byte for byte
before the second gate started, then passed with the proof clean. `make fmt` is
idempotent, so a second run is a no-op.

### H5: The bundled manual spec is no longer formatted, so `make check` reaches a fixed point

Running `make check` and then `make fmt` and `make doc` again left the tree
dirty, and the bundled manual spec changed on every pass. Two generators and
the formatter disagreed about the same file: `tools/gen-docs.py` writes
`src/adacovex-docs_template.ads` in its own layout, `gnatformat` rewrites the
file almost entirely, and the generator's stale-check is a byte comparison
against its own output. So each mangle made the next generator run report the
file stale and rewrite it, and the next `fmt` mangled it again -- 50 484
differing lines between the two layouts, 2.3 s spent reformatting 26 057 lines
of machine-written data on every gate run.

`make fmt` no longer formats the three generated specs. `gnatformat` has no
exclusion flag, so `fmt` passes it an explicit 187-file source list and skips
`adacovex_version_info.ads`, `adacovex-dashboard_template.ads` and
`adacovex-docs_template.ads`, named in a `GENERATED_SPECS` variable. The
hand-written `adacovex-docs_template.adb` is deliberately still formatted. This
is the same exclusion `make doc` already applies to generated API pages: a file
nobody hand-edits should not be reformatted into disagreement with the tool
that writes it.

Drift detection is unaffected, which was the thing worth checking: with the file
in the mangled state, `tools/gen-docs.py --check` still exits 1 and reports it
stale. The fix was measured end to end -- after a full `make check`, three
further `fmt` and `doc` cycles left both the file's checksum and `git status`
unchanged.

Four tests now enforce the invariant instead of leaving it to convention, since
a hand-written recipe is exactly what let the ordering drift in the first place:
`fmt` is a gate, it runs first, it precedes the gates that read the sources
(`build`, `test`, `prove`, `doc`), and every generated spec is named in the
exclusion list. Moving `fmt` back to just before `build` -- the regression that
actually happened -- fails `test_fmt_runs_first`.

## Test Suite

1775 tests across 26 categories, up from 1756 across 25 in 1.57.0. The new
SPARK coverage category carries 18 checks over metric selection, grouping, the
JSON report form, and the coverage-gate arithmetic. Server routing gains one
check for the `/api/spark` dispatch. The end-to-end CLI suite gains checks for
the spark-coverage flags and the coverage gate.

`make test` runs the native suite, `make cli-e2e` runs the end-to-end suite,
and both pass on this tree.

## Proof Results

**Platinum**, 0 unproved, 0 justified, **1047 of 1047 VCs across 68 analysed
units** under gnatprove 16.1.0 at `--level=4`, with no gnatprove warnings on
a clean session. The C7 sweep moves thirteen in-package subprograms into the
proved set. The campaign therefore grows from 884 VCs across 66 units in
1.57.0 to 1047 across 68, and a clean run on this tree is the source of these
numbers rather than an inherited 1.57.0 result. H2 is why the figure sits below
the 1053 the C7 sweep alone reached: it removes six checks while clearing every
warning.

H1's fix was exercised by that run. The cache held a summary left by a
degraded session, so the runner discarded it and re-proved instead of
reporting a warm hit. The clean re-prove then reached zero unproved VCs.

H1's fix was exercised by that run. The cache held a summary left by a
degraded session, so the runner discarded it and re-proved instead of
reporting a warm hit. The clean re-prove then reached zero unproved VCs.

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