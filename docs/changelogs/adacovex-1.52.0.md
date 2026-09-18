# adacovex 1.52.0

Date: _2026-09-18_

Version bumped 1.51.0 -> 1.52.0.

<!-- no-covex-docs-loc: historical release record, line cap does not apply -->

## Changes

### C1: The self tree is now proved and gated at gnatprove level 4

`make prove` passed `--level=4` to gnatprove. Level 4 is the deepest effort:
it adds stronger solver configurations, more inlining for contextual
analysis, and (in gnatprove 16) a deeper flow analysis that surfaced two
`warning: unreachable code` findings the lower levels never reported. The
level-4 run proves the same 878 checks with 0 unproved and 0 justified, so
the tree now clears the strongest standard configuration gnatprove offers,
not just the default.

The prove subcommand forwards `--level` (and `-l`) verbatim, so a level-4
run costs exactly gnatprove's own solver overhead and nothing from
adacovex. The adacovex-side shapes did not move: the bench session measured
the warm short-circuit at 45.6 +/- 3.0 ms (within noise of the phase's
~55 ms), and the cold path pays only the solver (one full-tree level-4
session measured ~19 s against ~14 s at the default level on the dev
machine). `tools/run.py prove` now passes `-l=4`, and the
prove runner and CLI config test suites pin the forwarding (`-l 4 ==
--level=4`, the 0..4 range with the reject paths, and the built option
string carrying `--level 4`).

### C2: The prove result cache refuses to serve a degraded summary

The prove subcommand's result cache short-circuits when the exact input set
(source tree, `.gpr`, options, prover identity) hashes to a stored proof.
A degraded run could poison that store: gnatprove exits 0 even when solver
timeouts leave checks unproved, and an interrupted level-4 session stored a
summary reporting 15 unproved VCs. Every later run with the same inputs
then served that summary and silently reported Silver, failing the
Platinum gate with no real proof regression anywhere.

The cache-restore path now parses the stored summary before serving it. A
blob whose Total row reports unproved VCs is dropped (the hit marker and
the summary blob both), the run falls through to a real gnatprove run, and
the fresh summary overwrites the store under the same input hash. The
parser grew the pure `Total_Row_Unproved` helper for the last-column read,
and the cache grew the matching `Delete` operation. A healthy all-proved
summary is never dropped, so the warm short-circuit keeps working.

### C3: The sentence-spacing rule covers `.adacovex` patch files

The one-space-after-a-sentence gate (`tools/check-docs.py`) covers the
docs, the changelogs, AGENTS.md, CONTRIBUTING.md, and the Ada comment text
under `src/`. It now also covers every Ada patch file under
`.adacovex/patches/`: a patch file re-declares a vendored spec or body with
docstrings, so its comment text is user-visible prose exactly like a `src/`
docstring. The `--fix` mode collapses a double space there under the same
string-state-aware comment reader it uses for `src/`, so the fixer and the
gate stay in step, and code alignment and string literals are never
touched.

### C4: The cold-clone prove benchmark

`make bench` times a fifth scenario: `prove` against a fresh copy of the
target tree with no result cache, no gnatprove session, and no
`gnatprove.out`. It is the first-run-on-a-new-checkout shape -- prove cold
wipes the session but leaves the summary in place, while a cold clone has
nothing, so nothing can short-circuit. The clone is a copy of the working
tree minus `obj/`, `bin/`, `.git`, and `.adacovex`, so the scenario also
runs on a tree with no git history and never picks up build state. The
category joins the benchmark reference table on the Performance page, the
`make bench` scenario list, and the per-phase timing notes.

### C5: The CI/CD and dashboard guides are split into focused pages

Three pages had grown past 220 lines and mixed two audiences each. The
CI/CD home page keeps the quick start, the GitLab mapping, and other CI
systems; the composite action's design, the full `### Inputs` and
`### Outputs` tables, and result caching moved to
[the composite action](../usage/ci-cd-action.md); and the release
bundling, floating tags, and consumer-manifest prerequisites moved to
[Release bundling, tags, and consumer
manifests](../usage/ci-cd-release.md). The dashboard home page keeps the
tab walkthrough and the endpoint table; the bundled offline manual's
compression, encoding, and sidebar navigation moved to
[The bundled offline manual](../usage/dashboard-docs.md). The
action-parity gate now reads the `### Inputs` table from the action page,
and every new page is reachable from the toctree and the doc-links block.

## Fixes

### H1: A stored summary with unproved VCs could cap the level at Silver

This is C2's user-visible face: on this tree, a partial gnatprove session
left by targeted `-u` runs plus an interrupted level-4 run produced a
stored summary reporting 15 unproved VCs under an input hash that a
healthy run shares. The next `make prove` reported
`SPARK level Silver below required Platinum` with `878 VCs, 0 unproved`
while a direct gnatprove run proved all 878 checks. The cache-poison guard
in C2 removes the failure mode for good: such a blob can no longer be
served, only re-proved.

## Test Suite

The native suite grows from 1624 to 1637 checks across 25 categories, all
passing:

- the CLI config category gains 6 checks: `-l 4 == --level=4` (maximum
  effort), the glued `-l4` form, and the reject paths for `--level=5` and
  `--level=-1`;
- the prove runner category gains 4 checks: the level-4 option string keeps
  the explicit step budget and loop-unrolling opt-out, and level 0
  forwards as the lowest effort;
- the GNATprove parser category gains 7 checks for `Total_Row_Unproved`:
  the all-proved dot cell, the bare `N` and `N (P%)` cells, a dot cell
  never leaking as a count, a header-only row, an empty row, and the
  leading number of a percent-only cell;
- the result-cache category gains 2 checks for `Delete`: a deleted entry
  is gone and the key is reusable, and deleting an absent key succeeds.

The dev-tools suite (`tools/tests.py`) grows from 122 to 126 tests: three
cover the patch-file scope of the spacing rule (patch files join the file
set, a patch comment double space is flagged and fixed, and a repository
without `.adacovex/patches` passes), and one covers the cold-clone helper
(the clone strips `obj/`, `bin/`, `.git`, and `.adacovex`, copies sources
and manifests, and mutating the clone never touches the source tree).

## Proof Results

Platinum, 0 unproved, 0 justified, 878 VCs (878 proved) across 66 analyzed
units under gnatprove 16.1.0 -- now verified at level 4, the deepest proof
effort, with the two unreachable branches level 4 flagged removed
(Match_Keyword's redundant overflow arm, which its precondition already
excluded, and Digit_Value's dead `when others` arm, replaced by a static
`Digit` subtype the ten case branches cover exactly). The VC count drops
from 880 to 878 because the removed dead code carried two VCs; every
remaining check is proved. The cache-poison guard and the parser helper
are fully proved and add no unproved surface.

## Traceability

- No new HLRs. The release tightens the proof gate (level 4), hardens the
  proof result cache, extends the docs gate, extends the bench suite, and
  splits user documentation.
- `HLR-PROOF` -- C1's level-4 forwarding and the option string the runner
  builds; the parser work in C2 and the proof results above.
- `HLR-CACHE` -- C2's poison guard, the `Delete` operation, and the
  summary-restore contract (a stored summary that reports unproved VCs is
  never served).
- `HLR-CLI` -- C1's `-l`/`--level` forwarding pinned by the config and
  prove-runner tests; C3's patch-file scope in the docs gate.
- `HLR-CI` -- C4's cold-clone benchmark scenario and the perf-page
  category rows; C5's split pages stay covered by the docs-coverage gate
  (toctree) and the action-parity gate (the `### Inputs` table now read
  from the action page).
