# adacovex 1.49.0

Date: _2026-09-14_

Version bumped 1.48.0 -> 1.49.0.

## Changes

### C1: Phase-based `make prove` timing table

The `make prove` timing table on
[docs/contributing/perf/prove-timing.md](../contributing/perf/prove-timing.md)
now keeps one column per **phase** instead of one per release. A phase is a
range of versions whose implementation methodology is largely similar: the
table carries 1.40.0-1.41.0, 1.42.0-1.44.0, and 1.45.0-1.47.0. Each phase
has one representative version (1.41.0, 1.44.0, and 1.47.0) that supplies
the phase's complete metric set, so a column is never assembled from the
best value of each row across different versions. The page is split into a
phase-rule section plus pipeline, prove, and warm-syscall tables, it marks
the 1.48.0 phase as open, and it carries per-phase reading notes.

### C2: AGENTS.md proof-timing phase rule

`AGENTS.md` now lists `docs/contributing/perf/prove-timing.md` among the
documents every change must keep current, and states the phase rule that
governs the table. A new version folds into the open phase while the
methodology holds; a methodology shift closes the phase and opens a new one.
Each phase keeps exactly one representative version, and the metrics carry
that version's complete set. The Verification section points at the
per-phase table beside the performance page.

### C3: Performance docs split into a hub and sub-pages

`docs/contributing/perf.md` was a 250-line page that mixed the benchmark
categories, the methodology, the sample output, the serve-API figures, the
binary size, and the interpretation. It is now a hub: the benchmark
category reference, the expected numbers, the phase rule, CI, and the
regression triage. The how-to, the benchmark machine, the sample output,
the single-shot recipe, the binary size, the probe cache, and the serve-API
load test moved to the new
[Benchmarking adacovex](../contributing/perf/benchmarks.md) page. The hub
cross-links the phase rule on the [prove-timing
page](../contributing/perf/prove-timing.md).

### C4: STE100 dictionary split into a hub and six lexicons

`docs/contributing/ste100-technical-names.md` was 817 lines, the largest
page in the tree. It is now a hub with the categories, the required fields,
the key rules, and the entry template, and six lexicon pages carry the
entries: the [Ada language
constructs](../contributing/ste100/ada-terms.md), the [proof and compliance
terms](../contributing/ste100/proof-terms.md), the [tooling and workflow
terms](../contributing/ste100/tooling-terms.md), the [hardware and system
entities](../contributing/ste100/entities.md), the [tools and
files](../contributing/ste100/identifiers.md), and the [reports and
concepts](../contributing/ste100/concepts.md). Every entry keeps its exact
text and field order; only the heading level changed.

### C5: Proof ledger split into the ledger and the audit

`docs/proof/16.1.0-ledger.md` was 276 lines. The skipped-units audit, the
irreducible `SPARK_Mode (Off)` exceptions, and the formal-containers
experiment moved to the new [proof-debt
audit](../archive/16.1.0-ledger-audit.md) page. The ledger keeps the
baseline, the per-package fixes, and the verification commands, and links
the audit page.

### C6: Documentation, docstring, unit-test, and proving gap audit

The release audited the four coverage surfaces. It found no docstring gap
(179 of 179 subprograms documented) and no proving gap (880 VCs, 0 unproved,
0 justified, Platinum), and every user page now sits under the 250-line cap
except the one historical changelog that carries a line-cap opt-out marker.
It found five unit-test gaps -- `Adacovex.Dir_Cache`, `Adacovex.Opt_Outs`,
`Adacovex.Diff`, `Adacovex.Prove`, and `Adacovex.Renderers.ANSI` had no
dedicated test category -- and the same change closes all five (see C7).

### C7: Five new native test categories close the audit gaps

The suite grows from 17 to 22 categories and from 1404 to 1518 checks. Each
new category unit-tests the component's own logic rather than its downstream
effect:

- **Opt-out markers** (16 checks) drives `Adacovex.Opt_Outs.File_Opts_Out`
  over written fixtures: one gate per marker, the case-insensitive match, the
  `no-covex-analysis` catch-all, the Markdown, Python, and Ada comment
  carriers, a prose mention that must not count, a marker below the header
  block, and the 24-line header window.
- **Dir cache** (22 checks) drives `Adacovex.Dir_Cache`: the entry
  classification helper, an unreadable directory, the first-touch miss and
  second-touch hit, the relative-versus-absolute spelling sharing one slot,
  `Reset`, and both truncation paths.
- **Diff reports** (36 checks) captures the
  `--compare-base` / `--coverage-delta` output and asserts every independent
  regression rule: a coverage drop, a skipped source, lost HLR traceability,
  new orphan tags, a SPARK level drop, a proved-VC drop, new test failures,
  and a DAL regression, plus the no-regression and empty-base cases, the
  colour path, and the VCS detection helpers.
- **Prove runner** (12 checks) pins the `prove` subcommand's command line:
  the default `-j / --steps / --no-loop-unrolling` shape, an explicit step
  budget, every configured switch in order, the raw `--args` passthrough, and
  the root `.gpr` lookup (none, one, ambiguous, missing).
- **ANSI terminal report** (28 checks) captures `Render_Summary` and asserts
  the coverage, proof, unit, test, cache, compliance, undocumented-subprogram,
  unproved-VC, and HLR lines, the `--standard=all` expansion, and the plain
  (no escape sequence) versus coloured output.

Each category is wired into `test_runner.adb`, the `tools/update-test-count.py`
map, `tools/agents-tree.map`, and the CONTRIBUTING category table.

### C8: Three more native test categories close the second audit pass

A second gap pass over the remaining packages found three untested areas, and
the same change closes them. The suite grows from 22 to 25 categories and
from 1518 to 1599 checks:

- **CPU and jobs** (24 checks) drives `Adacovex.CPUs`: the core count, the
  shell and temp-directory resolution (with the TMPDIR/TEMP/TMP chain), the
  CI marker list, the auto job default with and without CI, the `-j0` /
  explicit / auto resolution, the serve-pool bounds (2..8), and every verbose
  justification string.
- **HLR/LLR parsing** (33 checks) drives `Adacovex.Parsers.Read_Line` and
  `Adacovex.Parsers.DO178C`: a short line, an over-long line that is flagged
  and drained, the line after a drain, an exactly-full-buffer line, the HLR
  and LLR fixture parses (identifiers, descriptions, HLR references, prose
  excluded), a missing requirements file, the documented `hlr:` content-hash
  cache key and its round trip, and source-tag matching.
- **Completion scripts** (24 checks) drives `Adacovex.Completion`: each of the
  four shells and its distinct entry point, case-insensitive shell names, the
  bash fallback for an unknown or empty name, and the live `Flag_List`
  reaching every script.

### C9: Documentation moved into real folders

The perf and STE100 families became real directories instead of sibling
files: `docs/contributing/perf/` (index, benchmarks, prove-timing,
optimisation-history) and `docs/contributing/ste100/` (index, ada-terms,
proof-terms, tooling-terms, entities, identifiers, concepts). Every inbound
link was repaired -- the Sphinx toctrees, `tools/doc-links.map`, the API
reference links in `tools/rst2md.py`, the guide pages, the credits, and the
third-party notices.

### C10: At-cap pages split

`docs/contributing/architecture.md` and `docs/usage/dashboard.md` sat at the
250-line cap. The dependency-management half of the architecture page moved
to [Architecture -- dependencies](../contributing/architecture-dependencies.md),
and the chart and playground half of the dashboard page moved to [Dashboard --
charts and panels](../usage/dashboard-charts.md). Both hubs keep their sections
and cross-link their new sub-pages.

### C11: Four more pages split, every hub under 160 lines

Four of the largest remaining pages were split along their natural seams, and
every hub in the split is now under 160 lines:

- `docs/usage/cli-reference-options.md` (228) keeps the serving, CI, and tool
  flags; the emitted-report flags, the scan-scope flags, and the differential
  modes moved to [CLI flag details: emitted reports and differential
  modes](../usage/cli-reference-emit.md).
- `docs/contributing/developer-guide.md` (242) keeps setup, testing, tooling,
  the proof discipline, and the workflows; the source tree, the pipeline, and
  the generated artifacts moved to [Contributor guide: repository layout and
  generated artifacts](../contributing/developer-guide-layout.md).
- `docs/contributing/architecture-outputs.md` (245) keeps the output formats,
  the gates, and the reading contract; the platforms, delivery, linker note,
  pipeline order, and compiler swap moved to [Architecture: pipeline,
  platforms, and delivery](../contributing/architecture-pipeline.md).
- `docs/contributing/perf/optimisation-history.md` (243) keeps 1.43.0 and
  later; the 1.42.0 to 1.27.0 entries moved to [Performance optimisation
  history: earlier
  releases](../archive/optimisation-history-archive.md).

Every moved section kept its text and heading level, and the inbound anchor
references were repointed (`AGENTS.md` now links the pipeline anchor on the
new page).

## Fixes

### H1: Stale VC count in the proof index

`docs/proof/index.md` quoted 724 VCs, the count from the 1.28.0 era, while
the ledger and the live self-assessment report 880. The index now reads 880
and links both the ledger and the new audit page, so the proof records agree.

### H2: Long entry name hid a whole directory from the shared snapshot

`Adacovex.Dir_Cache.Snapshot` reported an empty directory when any child name
exceeded the 120-character memo limit: the probe returned `Count = 0` with
`Truncated = False`, so every walker that trusts the snapshot skipped the
file's siblings instead of falling back to direct enumeration. The probe now
reports the directory as over-cap, which sets `Truncated = True` and skips
memoisation, exactly as the package contract describes. The new Dir cache
test category covers both truncation paths. The snapshot contract is now
written down in [Architecture -- result caching](../contributing/architecture.md#result-caching).

### H3: A line that exactly filled the read buffer left a spurious blank line

`Adacovex.Parsers.Read_Line` treated an exactly-full buffer as a normal line
and returned without consuming the line terminator. `Ada.Text_IO.Get_Line`
stops at the buffer bound, so the next call then read the leftover terminator
and returned an empty line, which shifted the line numbers of every following
entry in an HLR, LLR, GNATprove, or test-report parse. The reader now calls
`Skip_Line` for that case, so the file sits at the next physical line exactly
as after a drain. The HLR/LLR parsing category and the overflow contract in
[Architecture](../contributing/architecture.md) pin the behaviour.

## Test Suite

The native suite grows from 1404 to 1599 checks (17 to 25 categories), all
passing. The eight new categories are Opt-out markers (16), Dir cache (22),
Diff reports (36), Prove runner (12), ANSI terminal report (28), CPU and jobs
(24), HLR/LLR parsing (33), and Completion scripts (24). The stdlib suite for
the dev tools (`tools/tests.py`) stays at 59 tests.

## Proof Results

Platinum, 0 unproved, 0 justified, 880 VCs (880 proved) under gnatprove
16.1.0. The release adds no proof surface: the eight new test packages, the
`Adacovex.Dir_Cache` fix, and the `Adacovex.Parsers.Read_Line` fix all live in
default-off units (the test harness and the I/O-bound packages), so the VC
count is unchanged. No proof metric regressed.

## Traceability

- No new HLRs. The release restructures the user documentation, records the
  proof-timing phase policy, closes the coverage-surface gaps, and fixes the
  directory-snapshot truncation; the existing `HLR-ARCH`, `HLR-SCAN`, and
  `HLR-DIFF` tags cover it.
- `HLR-ARCH` -- C1 the per-phase timing tables, C2 the AGENTS.md phase
  rule, C3/C9/C10/C11 the page splits and folder moves, C4 the STE100 lexicon
  split, C5 the proof ledger split, C6 the gap audit, and H1 the stale
  VC-count fix.
- `HLR-SCAN` -- C7's Opt-out markers category covers the per-file
  `no-covex-*` annotation detector directly.
- `HLR-CACHE` -- C7's Dir cache category, and H2 the shared
  directory-snapshot truncation fix.
- `HLR-DIFF` -- C7's Diff reports category covers the `--compare-base` /
  `--coverage-delta` regression rules and the VCS detection helpers.
- `HLR-PROVE` -- C7's Prove runner category pins the `prove` command line
  and the root `.gpr` lookup.
- `HLR-RENDER-ANSI` -- C7's ANSI terminal report category covers the
  terminal report sections and the colour gate.
- `HLR-CPU` -- C8's CPU and jobs category pins the core detection, the CI
  markers, and every job-count resolution.
- `HLR-COMPLIANCE` -- C8's HLR/LLR parsing category covers the requirements
  parser and the shared line reader, and H3 fixes the line reader's
  exact-buffer case.
- `HLR-CLI` -- C8's Completion scripts category covers the generator for all
  four shells.
