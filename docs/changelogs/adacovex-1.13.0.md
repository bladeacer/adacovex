# adacovex 1.13.0

Date: _2026-08-18_
Version bumped 1.12.0 -> 1.13.0.

## Changes

### C1: `man --force` and the OPTIONS wrap fix

The man renderer's OPTIONS descriptions carried a leading tab that misaligned
every wrapped continuation line (groff placed the first line at the `.TP` tab
stop but wrapped lines at the paragraph indent). Descriptions are now emitted
as single logical lines so groff wraps them with the proper hanging indent --
the whole page (SYNOPSIS, MODES, OPTIONS, ENVIRONMENT, EXIT STATUS) renders
cleanly. `man` also gains `--force`: normally `adacovex man` skips
re-installing when the installed page already matches the binary, and
`--force` always overwrites (useful to repair a corrupted page or re-run
`mandb`).

### C2: unknown flags rejected with a "did you mean" suggestion

An unknown `--flag` now fails with exit code 1 and prints "Unknown option"
plus a suggestion of the closest known flag (edit distance <= 2), so a typo
like `--target=. --theme=dar` or `--srev` is caught instead of silently
ignored. Known flags are unaffected and `help` topics still resolve for
unknown-but-fuzzy-matching inputs.

### C3: doc-sync tools scan the whole tree (no hardcoded file lists)

`tools/update-proof-status.py` and `tools/update-test-count.py` previously
rewrote a hardcoded list of docs, which let stale metrics live in any file
not on the list (e.g. the `601/601` test count in `alire/long-description.txt`
re-propagated to every manifest by the next `make description`). Both tools
now share `tools/live_files.py`, which derives the file set from the tree:
every text file is scanned except generated outputs (docs/api-docs,
docs/badges, docs/test_result.md, sbom.json, the generated Ada specs),
historical records (past-release changelogs and past proof ledgers keep
their release-time numbers), and the tools themselves. Both also gained a
`--check` mode that fails when any live file carries a stale metric, and
`tools/update-doc-links.py` gained the same. The stale pre-1.12.0 VC counts
in CONTRIBUTING.md and the crate-description proved/total phrasing are
covered by new anchored patterns, as are the JSON API sample fields
(`"total_vcs"` / `"proved_vcs"` / `"tests_passed"` / `"tests_failed"` in the
README and CLI reference) and the Makefile help's "Platinum, N VCs" comma
form -- so every number in the docs is anchored to generated artifacts
(`obj/gnatprove/gnatprove.out` and `docs/test_result.md`) rather than a
hand-written claim.

### C4: `make check` gate ordering + tree-wide count-sync checks

`make check` now runs cheap static gates first (ascii, spark-off, changelog,
version source, doc links) so a formatting or sync problem fails before the
expensive build + SPARK proof, then build / test / prove / doc / sbom, then
the count-sync checks (`test-count --check`, `proof-status --check`,
`description --check`) so a stale metric anywhere in the tree fails the gate
loudly instead of silently drifting into the next release. The README's
Makefile-targets section, `make help`, and the AGENTS.md table were updated
accordingly.

### C5: README slimmed (433 lines, was 508)

Detail duplicated from the docs was trimmed and pointed at its canonical
page: the VCS snapshot table (now one line, pointing at cli-reference's VCS
section), the compliance-artifacts-identical paragraph (pointing at
standards.md), the full Makefile-targets table (pointing at AGENTS.md), the
install/bundle instructions (condensed with the attestation + Linux-x86-64
notes kept), and the trust section (tightened). The JSON API section, flag
table, and examples remain in the README.

### C6: AI/LLM usage documented on a dedicated page

The Ken Thompson *Reflections on Trusting Trust* reference, the AI assistance
disclosure, and the "why should I trust your code" argument moved out of the
README into `docs/llm-usage.md`, which also documents how LLM agents are
expected to work on the tree under `AGENTS.md` (match conventions, zero
library dependency, SPARK discipline, `make check` as the contract,
regenerate generated files rather than hand-editing them) and how every
number in the docs is anchored to generated artifacts via the tree-wide sync
tools rather than a written claim. The README now links to the page.

### C7: unknown flags with no suggestion print the full usage

An unknown flag that has no close-enough known flag (edit distance > 2)
now prints the full usage text to stdout after the one-line error, so a
completely unrecognized token lands the user on the flag list instead of a
bare error. Near-miss typos still get just the "did you mean" hint (no
usage dump). A new `Unknown_No_Suggest` config flag drives the behavior;
config tests cover all three cases (no-match flag, near-miss flag, no-match
bare word).

### C8: adacovex action works when referenced via `uses: ./`

The action's build/download steps read `github.action_repository`, which is
**empty** when the action is referenced by a local path (`uses: ./`) -- the
consumer branch then tried to clone `https://github.com/.git` and failed
with exit 128, breaking adacovex's own `consumer-run-tests` CI job. Both
steps now fall back to `github.repository` (the workflow's own repo, which
IS adacovex for the self-test), and the build step falls back to
`github.sha` for the ref so the scratch clone checks out the exact commit
under test.

### C9: installation methods on a dedicated page

`docs/installation.md` now covers the three install routes (Alire manifest
dependency, `alr install`, release bundle / source build), the per-method
version source, and keeping the man page in sync. The README's install
section shrank to a two-line summary pointing at it, the giant CLI flag
table was dropped (the brief subcommand code block remains, with the full
table in docs/cli-reference.md), the JSON API section was condensed to the
endpoint + a curl example, and the README's documentation table now links
the dashboard/JSON-API section directly. The README also now calls out that
`--serve` serves a **viewable HTML dashboard** at `/` (not just an API).

### C10: LLM-usage page expanded

The page gained a "Working in a fork or branch" section (the `make check`
workflow as arbiter), a "served dashboard as a trust surface" section, and
an "honest limits" section (presence vs accuracy, SPARK-proof bar,
changelog validator) -- all anchored to the same gates and artifacts as the
rest of the docs.

### C11: generated-file generators skip rewriting when unchanged

`tools/gen-version.py` and `tools/gen-dashboard.py` now compare the
generated output against the committed file and skip the write (printing
"up to date") when byte-identical, so `make build` no longer touches
two generated files on every run -- `git status` stays quiet and the build
output is shorter.

## Test Suite

659 tests (was 501), across 12 categories. The CLI-config category (124
checks, up from 112) adds: `man --force` parsing (with and without the
prove-options guard), unknown-flag rejection with exit code 1, "did you
mean" suggestions for near-miss flags (single/multi character edits, missing
dashes), and the `Unknown_No_Suggest` contract (set for a no-match unknown
flag and bare word, unset for a near-miss flag that produces a suggestion);
the HTML/Markdown renderers category (34 checks) covers the dashboard's
theme dropdown (all three options, the `data-initial-theme` CLI-theme
marker, the Save settings button, `saveTheme` persistence, the `?theme=`
query param, the embed hint, the bundled template shell, `data-theme`
override, `prefers-color-scheme`, and `localStorage`, plus no leftover
`__CARDS__`/`__THEME__` placeholders) on top of the standard-aware dashboard
and JSON output; the DAL compliance category (16) gained the cached-HLR
parse round-trip; the SBOM generator category (118) gained the
dependency-graph cache round-trip; the Man page renderer category (18
checks) covers page structure, the embedded version, an install/read-back
round-trip, the `Update_Database` man-db contract, and a SYNOPSIS regression
check (single quoted `.B` lines, no `.RI` concatenation); the VCS support
category (29 checks) covers marker-file detection for every VCS, display and
tool-binary names, and the UX-conversion recommendations.

## Proof Results

Platinum, 408/408 VCs proved across 45 analyzed units (up from 44): the
`--theme` additions (the `Dashboard_Theme` type and its `To_String` /
`To_Theme` / `Is_Valid_Theme` conversions in `Adacovex.Types`) reuse the
already-proved uppercase/parse patterns and add 7 VCs, all proved; the new
bundled dashboard template package (`Adacovex.Dashboard_Template`, a String
constant generated from `resources/dashboard.html`) adds one analyzed unit
with no proof obligations; the CLI config parser (including the
`Unknown_No_Suggest` field), VCS, and man-page packages are non-SPARK I/O
code and add no proof obligations. Proven with `make prove` under gnatprove
16.1.0 (`--steps=10000`).

## Traceability

No new HLRs. The `man --force` and unknown-flag work stays covered by the
existing `HLR-CLI` (`src/core/adacovex-config.ads`); the doc-sync, generator,
and gate changes are Python/Makefile tooling that adds no traceability, and
the installation/LLM-usage pages are documentation. The action and CI
changes are workflow files that add no traceability.
