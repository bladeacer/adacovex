# adacovex 1.12.0

Date: _2026-08-18_
Version bumped 1.11.0 -> 1.12.0.

## Changes

### C1: `--theme=NAME` flag and a light/dark/system theme dropdown

`--serve` gains a `--theme=NAME` flag (`system` | `light` | `dark`, default
`system`) that sets the dashboard's initial theme. The header control is now
a **dropdown with three options -- light mode, dark mode, and system theme**
-- instead of a two-state button. `system` follows
`prefers-color-scheme`.

### C2: contextual `help` keyword with flag/subcommand topics

`help` is now a subcommand-like keyword that prints **contextual help** for a
single flag or subcommand instead of the full usage. The topic is matched
case-insensitively with an optional leading `--`, and may appear on either
side of the keyword: `adacovex help serve`, `adacovex help --serve`, and
`adacovex --serve help` all print the serve-specific help. `adacovex help`
(with no topic) and `--help` print the full usage. Unknown topics print the
full usage with an "Unknown topic" notice.

### C3: Save settings button with CLI-overrides-persisted theme priority

Theme persistence moved from automatic (saving on every dropdown change) to
an explicit **Save settings** button next to the dropdown, which writes the
current selection to `localStorage` (with a brief "Saved" confirmation).
Theme resolution on page load is now: an explicit CLI theme
(`--theme=light` / `--theme=dark`) always wins; otherwise the saved
`localStorage` choice if one was saved; otherwise the system
`prefers-color-scheme`. `--theme=system` (or no flag) leaves the browser's
saved choice in control.

### C4: man page rendering fixed (no more runaway gaps)

Two roff bugs made the man page render with broken spacing. The SYNOPSIS
used the `.RI` macro with separate arguments, which groff concatenates
without spaces (`[--format=FMT][--out=PATH]`), and long option lines
interleaved with `.br` caused groff's terminal output to pad the paragraph
with tab stops (`adacovex<big gap>sbom`). Each SYNOPSIS line is now a single
quoted `.B` argument, and every MODES / EXIT-STATUS description is a single
logical line that groff wraps with the proper hanging indent, so the page
renders cleanly.

### C5: JSON API documented and contextual help extended to all flags

The `--serve` documentation now explains the JSON API end to end: start the
server with `adacovex --target=. --serve --port=8080`, then
`curl http://localhost:8080/api/metrics`; the response fields (`spark_level`,
`total_vcs`, `proved_vcs`, `tests_passed`, `tests_failed`, `doc_coverage`,
`standard`, `level`, `dal_status`, and the per-standard `standards` object)
are documented in the CLI reference and README. Contextual help topics were
added for the remaining flags: `--emit-svg` / `--no-svg`,
`--emit-markdown`, `--skip-dir` / `--relaxed`, `--verbose`, `--no-sbom` /
`--sbom-format`, the `prove` subcommand options (`--jobs`, `--level`,
`--timeout`, `--steps`, `--memlimit`, `--force`, `--no-loop-unrolling`,
`--no-inlining`), and the `man` flags (`--check`, `--dir`).

### C6: `?theme=` query parameter on the dashboard URL

The served dashboard accepts a `?theme=light|dark|system` query parameter
(for embedding), which takes priority over everything else. Theme
resolution on page load is now: query parameter, then explicit CLI
`--theme=light|dark`, then the saved `localStorage` choice, then the system
`prefers-color-scheme`. Theme persistence remains **localStorage-only** --
no cookies are used anywhere.

### C7: adacovex action builds the target's native tests before running them

The composite action's `run-tests` input claims to "build and run the native
test suite", but in a consumer workspace the `build: true` step builds
adacovex in a scratch checkout and never touched the target -- so
`test-command: ./test_crdt` failed with `./test_crdt: No such file or
directory` (exit 127), which broke Ada_CRDT's release workflow. The action
now runs `alr build` in the target root before executing `test-command`
(in the self-assessment case that is an incremental no-op after the adacovex
build). The man-page test suite gained a SYNOPSIS regression check (no
`.RI` concatenation artifacts).

### C8: dashboard HTML is a real file bundled at build time

The `--serve` dashboard's static shell (doctype, CSS, header with the theme
dropdown + Save settings button, footer with an embed hint, and the theme
script) moved out of the Ada renderer's line-by-line string literals into a
single HTML file, `resources/dashboard.html`. `tools/gen-dashboard.py`
(pure stdlib, typed, `--check` mode like gen-version.py) bundles it into
`src/adacovex-dashboard_template.ads` at `make build` (committed and
byte-identical when unchanged), and `Adacovex.Renderers.HTML` now only
builds the dynamic card markup, injecting it at the `__CARDS__` placeholder
and filling the `__THEME__` initial-theme marker. Editing the page chrome
is now a plain HTML edit with no Ada knowledge required.

### C9: embed hint on the dashboard

The dashboard footer now shows "Embed: append `?theme=light|dark|system` to
the URL to pin the theme", and the theme dropdown carries a matching
`title` attribute, so embedders discover the query-param pinning from the
page itself.

### C10: man page documents theme priority and the JSON API

The man page's `--serve` entry now documents the full theme resolution
order (`?theme=` query param, then explicit `--theme=light`/`dark`, then the
saved `localStorage` choice, then the system preference), that persistence
is localStorage-only (no cookies), and the `GET /api/metrics` JSON endpoint
with a curl example.

### C11: action integration test for consumer `run-tests`

A new `consumer-run-tests` CI job restructures the workspace into a minimal
zero-dependency fixture crate (no `adacovex.gpr`, so the action's consumer
branch triggers), copies the action in, and runs it with `build: true` +
`run-tests: true` + `test-command: ./fixture_main`. This pins the fix for
the Ada_CRDT release failure (the action must build the target's native
tests before running `test-command`); the target build runs in the target
root so subdirectory `target` values work too. The action's internal
`Checkout` step is now conditional (only re-checks-out when the workspace is
empty) so a consumer fixture already present in the workspace survives, and
the scratch source clone cleans its directory first.

### C12: `man --force` and the OPTIONS wrap fix

The man renderer's OPTIONS descriptions carried a leading tab that misaligned
every wrapped continuation line (groff placed the first line at the `.TP`
tab stop but wrapped lines at the paragraph indent). Descriptions are now
emitted as single logical lines so groff wraps them with the proper hanging
indent -- the whole page (SYNOPSIS, MODES, OPTIONS, ENVIRONMENT, EXIT
STATUS) renders cleanly. `man` also gains `--force`: normally `adacovex man`
skips re-installing when the installed page already matches the binary, and
`--force` always overwrites (useful to repair a corrupted page or re-run
`mandb`).

### C13: unknown flags rejected with a "did you mean" suggestion

An unknown `--flag` now fails with exit code 1 and prints "Unknown option"
plus a suggestion of the closest known flag (edit distance <= 2), so a typo
like `--target=. --theme=dar` or `--srev` is caught instead of silently
ignored. Known flags are unaffected and `help` topics still resolve for
unknown-but-fuzzy-matching inputs.

### C14: doc-sync tools scan the whole tree (no hardcoded file lists)

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
`tools/update-doc-links.py` gained the same. A stale `401/401 VCs` phrasing
in CONTRIBUTING.md and the missed `(401/401 VCs proved)` description pattern
are covered by new anchored patterns.

### C15: `make check` gate ordering + tree-wide count-sync checks

`make check` now runs cheap static gates first (ascii, spark-off, changelog,
version source, doc links) so a formatting or sync problem fails before the
expensive build + SPARK proof, then build / test / prove / doc / sbom, then
the count-sync checks (`test-count --check`, `proof-status --check`,
`description --check`) so a stale metric anywhere in the tree fails the gate
loudly instead of silently drifting into the next release. The README's
Makefile-targets section, `make help`, and the AGENTS.md table were updated
accordingly.

### C16: README slimmed (433 lines, was 508)

Detail duplicated from the docs was trimmed and pointed at its canonical
page: the VCS snapshot table (now one line, pointing at cli-reference's
VCS section), the compliance-artifacts-identical paragraph (pointing at
standards.md), the full Makefile-targets table (pointing at AGENTS.md), the
install/bundle instructions (condensed with the attestation + Linux-x86-64
notes kept), and the trust section (tightened). The JSON API section, flag
table, and examples remain in the README.

## Test Suite

653 tests (was 501), across 12 categories. The CLI-config category (118
checks, up from 112) adds: `man --force` parsing (with and without the
prove-options guard), unknown-flag rejection with exit code 1, and "did you
mean" suggestions for near-miss flags (single/multi character edits,
missing dashes); the HTML/Markdown renderers category (34 checks) covers the
dashboard's theme dropdown (all three options, the `data-initial-theme`
CLI-theme marker, the Save settings button, `saveTheme` persistence, the
`?theme=` query param, the embed hint, the bundled template shell,
`data-theme` override, `prefers-color-scheme`, and `localStorage`, plus no
leftover `__CARDS__`/`__THEME__` placeholders) on top of the standard-aware
dashboard and JSON output; the DAL compliance category (16) gained the
cached-HLR parse round-trip; the SBOM generator category (118) gained the
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
with no proof obligations; the CLI config parser, VCS, and man-page packages
are non-SPARK I/O code and add no proof obligations. Proven with `make
prove` under gnatprove 16.1.0 (`--steps=10000`).

## Traceability

No new HLRs. The dashboard/theme/help work stays covered by the existing
`HLR-CLI` (`src/core/adacovex-config.ads`) and `HLR-RENDER-HTML`
(`src/renderers/adacovex-renderers-html.ads`/`.adb`) tags; the bundled
template package is generated data (no subprograms, no HLR), and the action
and CI changes are workflow files that add no traceability.
