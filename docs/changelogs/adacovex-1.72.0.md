# adacovex 1.72.0

Date: _2026-11-17_

Version bumped 1.71.0 -> 1.72.0.

## Changes

### C1: A root-project command touches only the root project

`just fmt` now skips the fixture roots as well as the generated specs, so
gnatformat never formats a file the root project does not own and no longer
prints `Warning: Formatting ... which is not visible to the provided project`
for the ecosystem fixtures' packages.

The two e2e suites report `SKIP` with a reason instead of a failure when a
prerequisite is absent. The CLI suite counts a skipped check apart in its
summary, and a missing sibling checkout, gnatprove, or git is never a pass and
never a failure. `just e2e` skips the Playwright dashboard suite when pnpm is
absent or the Chromium download fails, and `just prove-e2e` skips when no
prover is resolvable.

### C2: The documentation describes the tree at this release

The performance pages keep one column per phase with its representative
version, and they label a historical measurement as history. The figures that
describe current behaviour now carry the current values. The rest of
`docs/usage/` and `docs/contributing/` was swept for dated references, stale
VC and gate counts, and prose that presented a superseded release as the
present.

The check-pipeline page records the v1.72.0 warm run and the serial and
parallel phase layout.

### C3: The CLI reference shows what each command prints

`docs/usage/cli-reference-flags.md` carries one expected-output block for
`prove`, `status`, `complexity`, and `spark-coverage`, and
`docs/usage/platforms.md` carries one for `status --export`. Each block was
captured from a real run on the self tree and trimmed to its stable lines. The
volatile lines (paths, timings, counts) use a placeholder that the page defines
once.

The blocks stay sparse: one per command or mode, never one per flag, and each
block sits beside the prose that explains the flag.

### C4: The diagnostics matrix is documented and gated

`docs/contributing/proving-diagnostics.md` states which SPARK checks the
diagnostics block and its counterexamples support. The matrix holds 22 rows:
nine supported classes with a fixture pair, five hinted classes, seven
fallback classes, and the two compile-error shapes.

`tools/check-diagnostic-coverage.py` compares the matrix with the `Fix_Hint`
branches in `Adacovex.Prove_Output` and with the fixtures in
`tests/e2e/prove_diagnostics.py`. `just diagnostics-coverage-check` gates the
page, and the `diagnostics-coverage` job runs it in CI.

A new classification now adds its `Fix_Hint` branch, its broken and fixed
fixture, and its matrix row in one change.

### C5: The manual's tree is generated from the pages

`tools/gen-docs-tree.py` renders the hand-written docs under `docs/` as an
ASCII tree with each page's own H1 title, and it treats the generated
`api-docs/` and `changelogs/` directories as notes. It rewrites the `docs-tree`
block in AGENTS.md, and `--check` is the `docs tree` gate.

The flat `tools/doc-links.map` and `tools/update-doc-links.py` are retired.
`just doc-links` became `just docs-tree`, and it is wired through
`tools/tasks.py`, the justfile, the Makefile, and the AGENTS.md task table.
AGENTS.md gains a change-to-page routing table, and plan.md drops the repeated
session histories.

### C6: A warm `just check` passes 32 gates in 38.77 s

The warm run on 2026-11-16 finished in 38.77 s, under the 60 s budget. The sum
of the gate times is 70.30 s, so the parallel phase removes 31.53 s of serial
wall time. No gate is weakened and no check is dropped.

`tools/live_files.py` prunes build and vendored trees while it walks, so the
test-count and proof-metrics checks fell from 15.34 s and 9.72 s to 0.36 s and
0.37 s. `fmt` and gnatdoc store a digest of their inputs and skip an unchanged
source set, which removed 22.95 s and 3.79 s from those gates.

`task_check` runs three short serial phases around one parallel phase. The
independent gates capture their child output and print in the declared order.
The CLI suite runs four shards and the prove-diagnostics suite runs one process
per fixture case, so the two longest gates overlap the rest.

### C7: Every API item carries a description

`tools/rst2md.py` now reads the prose of each `.ads` docstring and renders it
as the item description. gnatdoc does not copy a subprogram or type description
into its RST directives, so the API reference named items without describing
them.

Every public type in the tree now carries a one-line description, including the
IR scalar types, the dashboard state records, and the SBOM records. The run
fails when a rendered item has no description, an empty parameter row, or an
empty Returns line, so the next undocumented item fails `just doc` instead of
shipping.

Debt D13 closed in the same work. Debt D11 and D7 stay open with their owning
releases (v1.74.0 and v1.75.0), and no other defect from v1.69.0-v1.75.0 is
unrecorded.

## Fixes

### H1: `Run_Prove` describes itself again

The description and `@param` block of `Run_Prove` sat above `Replay_Stats`, so
the API reference showed the procedure with parameters but with no summary, and
the record took the parameter names. The block moved to the procedure, and each
item now documents only its own declaration.

### H2: A trailing comment no longer swallows a type body

A multi-line enumeration whose last alternative carried a comment left the type
body open, because the line ended with comment text rather than `;`. Every
subprogram after it lost its annotation block, so `Write_Sample_Project_File`
rendered an empty parameter table. The parser now closes the body on the code
part of the line.

## Test Suite

`tools/tests.py` adds five checks: the docstring prose reaches the item
description, a wrapped annotation stays with its parameter, a trailing comment
on a last enumeration alternative still closes the type body, and the
completeness report names each kind of gap while a complete item passes.

Native suite: 2394/2394 passing (29 categories). The tools suite passes 224
tests. `just prove-e2e` passes 132 checks, and `just cli-e2e` passes 165 (one
check skips when no prover is resolvable).

## Proof Results

The Ada change is comment-only: this release adds docstrings and moves one of
them. No `SPARK_Mode (Off)` pragma was added, and the two exempt packages are
unchanged.

The tree proves at the default budget (gnatprove 16.1.0: 1058 VCs, 0 unproved,
0 justified). Self-assessment: Gold, 100% docstrings, DAL-C Achieved, ASIL B
and Class A Achieved under `--standard=all`.

## Traceability

HLR-ARCH: `just doc` fails on an API item that has no description, an empty
parameter row, or an empty Returns line, and `just docs-tree` generates the
manual's tree from the pages.

HLR-METRICS: The API reference renders the docstring prose that the
docstring-coverage metric counts, so a documented item and a described page
agree.

HLR-CLI: The diagnostics block states, in one documented matrix, which SPARK
checks it classifies, which it reports as a fallback, and which carry a fixture
pair.
