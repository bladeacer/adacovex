# adacovex release plan: v1.68.0 - v1.75.0

Current version: `1.71.0`. Work is scoped across **eight minor releases**:
`v1.68.0` through `v1.71.0` (closed), then `v1.72.0` through `v1.75.0`.
Closed releases are recorded in their changelogs, not repeated here.

## Proof-timing phase note

All of these land in the **open `v1.61.0 -` phase** (representative `1.63.0`)
of `docs/contributing/perf/prove-timing.md`. The methodology is unchanged
(gnatprove-driven prove via the `prove` subcommand, result cache keyed the
same way, bundle specs excluded from the proof-input hash), so no phase
boundary or methodology-shift note is required. Item 18 changes what a warm
cache hit is keyed on, not how gnatprove runs; if the representative figures
move, record the open-phase column from one run's complete metric set rather
than cherry-picking rows across versions.

## How work is distributed

| Version | Status | Theme | Items |
|---------|--------|-------|-------|
| v1.68.0 | closed | Output defaults and time | changelog `adacovex-1.68.0.md` |
| v1.69.0 | closed | Compiler-style diagnostics and output | changelog `adacovex-1.69.0.md` |
| v1.70.0 | closed | SBOM robustness and debt | changelog `adacovex-1.70.0.md` |
| v1.71.0 | closed | SBOM depth and pipeline speed | changelog `adacovex-1.71.0.md` |
| v1.72.0 | planned | Performance close-out and documentation currency | 15c, 8c, 9 close-out, 21, 22, 23 |
| v1.73.0 | planned | Test suite portability and layout | 20 (test root and fixture projects), 16 (platform-agnostic suite) |
| v1.74.0 | planned | Cache identity and diagnostics coverage | 18 (resolved-path, per-unit cache; 7-day expiry), 17a (contract-error matrix) |
| v1.75.0 | planned | Dogfood close-out and CLI cohesion | 17b (Ada_CRDT robustness), 19 (contextual help audit), final docs/STE pass |

## Session status (2026-11-16, v1.72.0 work started)

v1.72.0 now also carries the tool-hygiene and documentation items 21-23. Item
21 is done in this change: `fmt` formats only files the root project sees, so
the ecosystem fixture's `mini.gpr`/`mini.ads` no longer produce the "not
visible to the provided project" warning, and the e2e suites SKIP a check
whose prerequisite is absent (a sibling checkout, Playwright/pnpm, Chromium, a
prover, or git) instead of failing it. Item 22 is the documentation currency
audit (prove-timing, perf, architecture, and surface pages); item 23 adds
expected command output to the CLI reference in sparse code blocks.

## Session status (2026-11-16)

v1.71.0 is closed. Item 8b removed the padded proof-artefact name array (one
`Max_Path` check now serves every artefact), documented the tier of every
`Max_*` constant in the overflow contract, stopped the tool scan reading
comment text, and added `meson` so the curated table covers the fixture
projects' build tools. Debt D3, D5, and D14 closed. Item 15b memoises the
build, the bundled offline manual, and the proof across a `just check` run,
and moved the build gate before every gate that needs the binary, so the
compile is one row of the gate table. The tree holds 2394/2394 tests, 165
CLI e2e checks, and 132 prove-e2e checks at Gold (1058 VCs). The 60 s
warm-tree budget stays with item 15c in v1.72.0.

## Session status (2026-11-15)

v1.71.0 has landed both SBOM items. Item 6b-i gave the ecosystem table
every language syft catalogues from a source tree, plus Ada. Item 6b-ii
reads the lockfiles (Cargo.lock, poetry.lock, Gemfile.lock, composer.lock,
package-lock.json, packages.lock.json, Package.resolved, pubspec.lock,
mix.lock), so a package only a lockfile names is a transitive component,
and it catalogues GitHub Actions workflow actions as dev-scope
`pkg:github` components. Debt D15 closed: an SPDX licence expression now
takes CycloneDX `license.expression`. The tree holds 2387/2387 tests. The
remaining v1.71.0 items (8b's bounded-string debt, 15b's single build and
single proof run) stay open.

## Session status (2026-11-14)

v1.68.0 through v1.70.0 are closed. v1.70.0 fixed the generated-build-tree
false positive that put `cargo` and `go` in a C project's SBOM, measured the
parser against syft, started the debt register, and recorded the per-gate
`just check` timings. The tree holds 2180/2180 tests, 165 CLI e2e checks, 132
prove-e2e checks, and 1057 VCs at Gold. The plan now runs to v1.75.0 with the
SBOM-depth, performance, test-layout, portability, cache-identity,
diagnostics-coverage, and help-audit workstreams. This file is the single
source of truth for release scope; completed work is recorded in the
changelogs.

Every change also updates, in the same change: `docs/`, Ada docstrings feeding
`docs/api-docs`, `docs/changelogs/adacovex-<version>.md`, AGENTS.md source tree
(if source layout changed), and the `just check` gates
(`docs-check`, `action-parity-check`, `docs-coverage-check`,
`surface-parity-check`, `version-consistency-check`, `doc-links`, `link-check`,
`book-links-check`, `python3 tools/gen-docs.py --check`, then `just book`).
After `just test` and `just prove`, run `just test-count` and
`just proof-status`.

## Working constraints

1. `src/core/adacovex-prove.adb` sits just under the 600 cyclomatic cap. Put
   new I/O helpers in `Adacovex.Prove_Output` or a sibling unit, and run
   `just complexity-check` after a change there.
2. `tests/e2e/prove_diagnostics.py` sets `NO_COLOR=1` so the text assertions
   compare plain output. Keep that when adding checks; item 20 moves the file
   to `src/tests/e2e/prove/`.
3. `just test-count` rewrites the test count in every historical release
   manifest. Commit the generated manifests as-is.
4. `Adacovex.Prove_Output` counts as a proof unit. `just proof-status` keeps
   the VC ledger, the badges, and the timing page in sync.
5. `just check` runs `fmt` first. Re-run the full chain after a source edit; a
   green `complexity-check` alone does not cover the parity gates.

## Closed releases

Detailed item text for a closed release is removed once its changelog exists;
the changelog is the durable record of what shipped and why.

- **v1.68.0** delivered the coverage-on-by-default behaviour, UTC+0 timestamp
  default with `--tz=local`, the 17-character patched-artefact bound, and the
  API docstring pass. See
  [`docs/changelogs/adacovex-1.68.0.md`](docs/changelogs/adacovex-1.68.0.md).
- **v1.69.0** delivered repeated-diagnostic dedup, the unified contextual
  help frame with option spacing, warm-replay parity, severity colour,
  GitHub Actions annotations, compiler-style findings with
  `--diagnostics=json`, the diagnostics mode matrix, the
  composite-action project-config job, and the main-only release guard. See
  [`docs/changelogs/adacovex-1.69.0.md`](docs/changelogs/adacovex-1.69.0.md).
- **v1.70.0** delivered the generated-build-tree fix that removed the false
  `cargo` / `go` components from a C project's SBOM, the syft comparison and
  its gap decisions, the technical debt register, and the per-gate `just
  check` measurement. See
  [`docs/changelogs/adacovex-1.70.0.md`](docs/changelogs/adacovex-1.70.0.md).
- **v1.71.0** delivered the syft-complete ecosystem table, the nine lockfile
  readers and the workflow-action components, the single bounded copy for the
  proof artefacts, the command-text tool scan and its `meson` coverage, and
  the build-once / bundle-once / prove-once check pipeline. See
  [`docs/changelogs/adacovex-1.71.0.md`](docs/changelogs/adacovex-1.71.0.md).

The v1.65.0-v1.67.0 plan is also closed and `old-plan.md` is deleted.
Old-plan 3.1 (the action honours a project `adacovex.toml`) closed in
v1.69.0. Old-plan 3.4 measured a 344 s warm-tree `just check` on 2026-11-06. Item 15a
retired that figure with the per-gate measurement of 2026-11-14 (452.99 s
warm, all 31 gates) in
[`docs/contributing/perf/check-pipeline.md`](docs/contributing/perf/check-pipeline.md),
and the 60 s gap is carried by item 15c: item 15b removed the repeated build,
docs bundle, and proof from a run in v1.71.0.

---

## v1.72.0 - Performance close-out and documentation currency

- [x] Item 21 - Root-project tooling hygiene

**Goal:** A root-project command never reads or formats a file the root
project does not own, and an e2e check whose prerequisite is absent SKIPs with
a reason instead of failing.

**Work:**
- `tools/tasks.py`: `fmt_sources` excludes the fixture roots
  (`src/tests/fixtures/`, `src/tests/projects/`) as well as the generated
  specs, so gnatformat no longer prints `Warning: Formatting ... which is not
  visible to the provided project` for the ecosystem fixture's `mini.ads`.
- `tests/e2e/cli_flags.py`: a check that cannot run reports `SKIP` with its
  reason and is counted separately in the summary; a missing sibling
  checkout, gnatprove, or git is never a pass or a failure.
- `tools/tasks.py`: `just e2e` SKIPs the Playwright dashboard suite when pnpm
  is absent and when the Chromium download fails; `just prove-e2e` SKIPs when
  no prover is resolvable.
- `tools/tests.py`: pin the fmt exclusion and the source it still formats.

**Files:** `tools/tasks.py`, `tools/tests.py`, `tests/e2e/cli_flags.py`,
`docs/contributing/developer-guide.md` (skip policy).

**Verify:** `just fmt` (no fixture warning), `just tools-check`,
`just cli-e2e`, `just e2e` on a host without pnpm.

---

- [ ] Item 22 - Documentation currency audit

**Goal:** The user docs and contributor docs describe the tree at v1.72.0, not
an earlier release. A dated figure stays only where the page needs it (a phase
column, a changelog, or an optimisation record), and every other stale
reference is removed or restated as current behaviour.

**Work:**
- Audit `docs/contributing/perf/` first: `prove-timing.md` still introduces
  itself through the 1.46.0 SIMD review, `benchmarks-timings.md` compares
  pipeline figures from 1.47.0-1.52.0, `check-pipeline.md` records the v1.70.0
  and v1.71.0 runs, and `index.md` describes the 1.63.0 memo as the current
  explanation. Keep the phase table's representative versions (the AGENTS.md
  rule), and retire prose that describes a superseded release as the present.
- Sweep the rest of `docs/usage/` and `docs/contributing/` for dated version
  references that no longer explain a current behaviour (`grep -rn
  '1\.[0-9][0-9]\.[0-9]' docs`); a changelog and a proof ledger keep theirs.
- Re-read the surface pages against the binary: every `Known_Flags` entry in
  the CLI reference, every dispatched dashboard route, every action input,
  and the `--serve`/`prove`/`sbom` descriptions in AGENTS.md.
- Fold the outcome into `docs/changelogs/adacovex-1.72.0.md`.

**Verify:** `just docs-check`, `just docs-coverage-check`,
`just surface-parity-check`, `just link-check`.

---

- [ ] Item 23 - Expected command output in the docs

**Goal:** A reader sees what a command prints without running it, in a fenced
block that matches the real binary. Blocks stay sparse: one per command or
mode, not one per flag.

**Work:**
- Add one expected-output block to each of `prove` (coverage summary plus one
  finding), `status`, `complexity`, and `spark-coverage` in
  `docs/usage/cli-reference-flags.md`, and one to `docs/usage/platforms.md`
  for `status --export`.
- Capture each block from a real run on the self tree and trim it to the
  stable lines; mark the volatile ones (paths, timings, counts) with a
  placeholder the page defines once.
- Keep the blocks inside the 4-sentence paragraph rule and do not let a block
  replace the prose that explains the flag.

**Verify:** `just docs-check`, `just link-check`, `just book` and
`python3 tools/gen-docs.py --check`.

---

- [ ] Item 15c - Close the 344 s -> 60 s warm-tree gap

**Goal:** `just check` finishes under a minute on the dev machine with a warm
cache and a warm gnatprove session. No gate is weakened and no check is
dropped. Group the native tests, the CLI e2e checks, and the diagnostics
fixtures into one invocation each; run independent gates in parallel with the
standard library, a CPU cap, and the unchanged PASS/FAIL/SKIP summary.

**Files:** `tools/tasks.py`, `tools/tests.py`,
`docs/contributing/perf/check-pipeline.md`,
`docs/contributing/perf/prove-timing.md`.

**Verify:** a recorded warm run with the complete metric set for the open
phase's representative version.

---

- [ ] Item 8c - Debt paydown close-out

**Goal:** Every open register entry is closed or explicitly accepted with a
reason. No new debt from v1.69.0-v1.75.0 remains unrecorded.

**Verify:** the register plus `just check`.

---

- [ ] Item 9 close-out - API docstring completeness

**Goal:** `just doc` produces no empty description, `@param`, or `@return`.
`just docs-coverage-check` passes.

**Verify:** `just doc`, `just docs-coverage-check`.

---

## v1.73.0 - Test suite portability and layout

- [ ] Item 20 - One test root and generated fixture projects

**Goal:** All tests live under `src/tests`, e2e tests are categorised, and no
Ada fixture is written inline in a workflow. A fixture project is a real
directory with its own `alire.toml`, `.gpr`, `src/`, and a README that states
what it proves.

**Work:**
- Move `tests/e2e` to `src/tests/e2e` and split it by category:
  `cli/` (`cli_flags.py`), `prove/` (`prove_diagnostics.py`), `dashboard/`
  (Playwright specs and server helper), `action/` (action fixtures), and
  `lib/` for shared Python helpers.
- Create `src/tests/projects/` with one directory per fixture:
  `consumer-action/`, `action-project-config/`, and
  `contract-errors/<class>/{broken,fixed}/`. Each carries an `alire.toml`,
  a project file, and a README naming the check it exercises.
- Replace the inline heredocs in `.github/workflows/ci.yml` with a copy of
  the relevant `src/tests/projects/<name>` tree. Keep the consumer-workspace
  restructure: the action's consumer branch needs a workspace without
  `adacovex.gpr`.
- Keep fixture projects out of the root build: the GPR lists source
  directories explicitly and `src/tests` is already skipped by the scanner
  and the proof walk. Add the complexity/docstring opt-out markers to fixture
  sources that are deliberately incomplete, and confirm `alr build` never
  compiles them. Confirm that `just run-self`, `just sbom`, and
  `just complexity-check` do not treat a fixture as a project input; extend
  the skip lists if they do.
- Update `just` targets, `.gitignore` (`node_modules`, `playwright-report`,
  `test-results`), CI paths, `tools/tasks.py`, `tools/agents-tree.map`,
  `AGENTS.md`, `docs/contributing/developer-guide-layout.md`, and
  `CONTRIBUTING.md`.
- Add `tools/check-test-layout.py` (stdlib) as `just test-layout-check`: every
  `src/tests/projects/*` has a manifest, a project file, and a README, and no
  workflow contains an inline Ada project heredoc. Wire it into `just check`.

**Tests:** the moved suites still pass from their new paths; `just cli-e2e`,
`just prove-e2e`, and `just e2e` run the same checks as before.

**Verify:** `just check`, `just e2e`, `alr build` leaves
`src/tests/projects` uncompiled.

---

- [ ] Item 16 - Platform-agnostic test suite

**Goal:** The native suite and the e2e suites pass on Windows, macOS, and
Linux. A test checks the platform instead of assuming it, and a genuine
platform dependency is an explicit skip with a reason.

**Work:**
- Audit the tests for POSIX assumptions: `/tmp`, `/`, `:` in `PATH`, `sh -c`,
  `rm -rf`, `chmod`, symlinks, case-sensitive names, CRLF, drive letters,
  `mandb` / `makewhatis`, `/proc`, `uname`, locale, and timezone.
- Extend `Adacovex.Test_Support` with `Temp_Dir` (create and remove under
  `$TMPDIR` / `%TEMP%`), `Join`, `To_Native`, `Run_Command` (argument vector,
  no shell), and `Skip_On` / `Skip_Without` with a named reason. Replace
  shell-string spawning with argument vectors and use `Adacovex.Paths` for
  separators and `Expand_User`.
- Make every skip visible in the run summary. A skipped test is not a pass.
- Add an OS matrix to CI for `just test` and the Python e2e suites on
  `ubuntu-latest`, `macos-latest`, and `windows-latest`. Run a fast subset on
  pull requests and the full matrix on `main`; keep the Playwright dashboard
  job on Linux. `prove-e2e` SKIPs when no gnatprove is resolvable.
- Add `tools/check-test-portability.py` (stdlib) as
  `just portability-check`: flag known POSIX-only literals and shell idioms in
  tests, with a documented allow-list. Wire it into `just check`.
- Document the matrix, the skip policy, and the Windows path rules in
  `docs/usage/platforms.md` and `docs/contributing/developer-guide.md`.

**Tests:** self-tests for `Temp_Dir`, `Run_Command`, and the Windows
drive-letter / separator cases; the path suite already covers both separator
shapes.

**Verify:** the CI matrix is green on all three systems; `just portability-check`;
`just test`.

---

## v1.74.0 - Cache identity and diagnostics coverage

- [ ] Item 18 - Cache by resolved location, per unit, with expiry and clear

**Goal:** The same project hits the same cache entry whether `prove` runs from
`/path/a`, `/path/b/c`, or the project itself, because the key uses the
resolved filesystem location rather than the target string or the current
directory. A small source edit misses only the changed unit and its
dependents, so most entries stay hits; the `result cache:` line shows the
split. Entries expire after a configurable duration (7 days by default), and
the user can clear the cache on demand.

**Work:**
- Resolve the target once at startup through a new path helper
  (`Adacovex.Paths.Resolve`): expand `~`, make absolute against the current
  directory, collapse `.` and `..`, normalise separators, and fold case on
  Windows. Use the same helper for the root project file.
- Audit every cache key for a whole-tree input. A per-file scan, docstring,
  test, or HLR entry must depend only on that file's content and its own
  options; a tree hash, the target string, or the current directory must not
  leak into an unrelated key.
- Replace every proof-cache key input that currently hashes the caller's
  `Target_Dir` or `GPR` string with the resolved absolute paths. The
  proof-input walk hashes `Dir & Options` at each level today, so two cwds
  produce two keys.
- Split the proof cache from one whole-run entry into per-unit entries. A unit
  key covers the unit's content, its `with` dependency closure, the resolved
  path, the options, and the prover identity. A run manifest references the
  unit keys, and the summary, SARIF, and replay artefacts are assembled from
  the units that hit. A one-file edit misses only that unit and the units
  that depend on it.
- Make the `result cache:` line report those unit outcomes. A warm no-change
  run keeps the documented shape (`32 hit(s), 0 miss(es), 0 evicted`); a
  one-file edit in a 32-unit fixture must keep at least 31 hits and miss only
  the changed closure. A broad refactor may miss many units, and the line must
  show that rather than hide it.
- Add a small fixed header to each cache entry: the entry format tag and the
  write time in OS seconds. `Load` strips the header before it returns the
  payload, so callers see the same bytes. Use the header time for the TTL,
  not the file mtime, because a CI cache restore or a copy rewrites mtime and
  would make an old entry look new.
- Add `Default_Expiry_Days : constant := 7`; a load older than the TTL is a
  miss and the entry is removed. Expiry runs before the `--cache-max` count
  cap, and oldest-first eviction uses the same header time. A zero expiry
  means "never expire".
- Add `[cache] expiry-days = 7` to `adacovex.toml`, `--cache-expiry=DAYS`, and
  `--cache-clear`. The bare `cache` word stays the `--cache` alias; do not add
  a conflicting `cache` subcommand. `--cache-clear` deletes the resolved cache
  root, prints the path and entry count, and exits 0.
- Make clear refuse a path outside the cache root and use the path helper for
  removal, so a bad `--cache-dir` can never delete an unrelated tree.
- Bump `Cache_Schema` to `s12`; old entries are abandoned, so no entry
  without a header is ever read.
- Document the key rule, the TTL, and clear in
  `docs/usage/configuration.md`, `docs/usage/cli-reference-options.md`, and
  `docs/usage/performance.md`. Update `AGENTS.md` if the cache description
  drifts.
- Wire `--cache-expiry` and `--cache-clear` through `action.yml` and the
  `docs/usage/ci-cd.md` Inputs table, or add them to the documented
  `CLI_ONLY` allow-list. `just action-parity-check` fails on an unwired flag.

**Tests:** `adacovex_cache_tests.adb` covers the TTL boundary, a rewritten
mtime that disagrees with the stored header time, a negative age (clock
skew), expiry 0, clear-root safety, and relative/absolute key equality. A CLI
e2e runs `prove` from two different working directories against one project
and asserts the second run reports a cache hit. A fixture with 32 cached file
entries edits one unit and asserts `result cache:` keeps at least 31 hits,
reports at most one miss, and names no eviction.

**Verify:** `just test`, `just cli-e2e`, two `prove` runs from different cwds,
`just bench` if the warm figures move.

---

- [ ] Item 17a - Contract-error coverage matrix and fixtures

**Goal:** The diagnostics documentation states which contract and runtime
checks adacovex classifies, which it reports only as raw fallback, and which
it does not yet support. Every supported class has a broken/fixed fixture
pair.

**Work:**
- Inventory `Fix_Hint` in `Adacovex.Prove_Output` and the current e2e cases:
  index, overflow, division, precondition, invariant, invariant entry, flow,
  typo attribute, and typo identifier. `Fix_Hint` already names hints for
  division, range/index/overflow/discriminant, precondition, postcondition,
  assertion, invariant, termination, and initialisation; every other kind
  falls through to the generic hint.
- Add fixtures for postcondition, assertion, range check, discriminant check,
  null access, subtype conversion, predicate, ghost/lemma, termination,
  modular arithmetic, floating point, and aliasing/ownership. Put each pair
  under `src/tests/projects/contract-errors/<class>/{broken,fixed}/`.
- Classify a class as **supported** only when the block names the check and
  gives a fix a user can apply. Otherwise mark it **fallback** (raw message,
  location only) or **not yet supported** (no fixture; listed as a gap).
- Add the matrix to `docs/contributing/proving-diagnostics.md`: class,
  gnatprove check or SARIF rule, status, fixture, and the fix hint.
- Add `tools/check-diagnostic-coverage.py` (stdlib) as
  `just diagnostics-coverage-check`: every fixture directory maps to a matrix
  row and every supported row has a fixture. Wire it into `just check`.

**Tests:** `tests/e2e/prove_diagnostics.py` iterates the fixture projects,
asserts the classified kind and hint for supported classes, and asserts the
documented fallback shape for the others.

**Verify:** `just prove-e2e`, `just diagnostics-coverage-check`,
`just docs-check`.

---

## v1.75.0 - Dogfood close-out and CLI cohesion

- [ ] Item 17b - Ada_CRDT dogfood: useful, robust diagnostics

**Goal:** The diagnostics earned on `../Ada_CRDT` are accurate, quiet, and
actionable, and the remaining gaps are documented rather than hidden.

**Work:**
- Run `just run-ada-crdt` with `--diagnostics=text` and `--diagnostics=json`;
  record every finding by class, location, and whether the block is
  actionable.
- Fix grouping and dedup gaps the dogfood exposes: missing source locations,
  multi-line messages, inlined call sites, warnings without a line, and
  solver attribution when a category has more than one prover.
- Confirm `--suppress-warnings`, `--quiet`, and `--verbose` keep their
  contracts on the dogfood tree.
- Copy representative Ada_CRDT findings into synthetic fixtures under
  `src/tests/projects/contract-errors/` (with attribution in the README) so
  CI covers them; CI must not require the sibling checkout.
- Document a "Dogfood: Ada_CRDT" section in
  `docs/contributing/proving-diagnostics.md` with counts by class, the
  actionable findings, the fallback findings, and the link to the item 17a
  gaps. Update `docs/usage/target-projects.md` if the behaviour changes.
- If a finding is an adacovex false positive rather than a gnatprove
  diagnostic, fix it and add a regression test.

**Tests:** the new fixtures, plus the existing `just run-ada-crdt` gate.

**Verify:** `just run-ada-crdt`, `just prove-e2e`, `just test`.

---

- [ ] Item 19 - Contextual help audit and Unix CLI cohesion

**Goal:** Every help topic reads like one Unix tool. `prove` help is the
reference frame; the main `--help` and every contextual topic share it.

**Work:**
- Audit every topic the parser dispatches: `prove`, `serve`, `status`,
  `sbom`, `complexity`, `spark-coverage`, `man`, `tldr`, `init`,
  `completion`, and `cache`. Each topic gets a `Usage:` block, a one-line
  summary, aligned option columns with wrapped descriptions, one example,
  exit codes where they are not 0/1, a `See also` line, and the standard
  footer.
- Keep the option layout and blank-line grouping from `prove` help. Do not
  put developer commands (`just`, `alr build`) in help or dashboard prose.
- Make an unknown topic list the valid topics and suggest the nearest match,
  in the same style as `Suggest_Flags`.
- Keep `help <topic>` and `<subcommand> --help` byte-identical, and keep a
  flag before `--help` selecting the main usage.
- Do not add a pager or colour outside a TTY; the output must pipe cleanly.
- Update `docs/usage/cli-reference.md` and the flag-detail pages for any
  wording or grouping change.

**Tests:** `adacovex_config_tests.adb` snapshots each topic's frame and
option order; `cli-e2e` asserts every topic has `Usage:`, `Options:`, and the
footer, and that no developer command appears.

**Verify:** `just test`, `just cli-e2e`, `just surface-parity-check`,
`just docs-coverage-check`.

---

- [ ] Final docs, STE, and parity drift pass

**Goal:** Re-read the user docs against the codebase surface after the
v1.73.0-v1.75.0 changes: every `Known_Flags` entry in the CLI reference,
every dashboard route in the dashboard page, every action input in the CI/CD
inputs table, every new Technical Name in the STE100 list, and every new test
category in the CONTRIBUTING table. Fix drift in place; no follow-ups.

**Verify:** the full `just check` chain.

---

## Per-release checklist (apply to every version)

1. Implement the version's items (code + tests).
2. Update `docs/`, Ada docstrings, and `docs/changelogs/adacovex-<version>.md`.
3. Regenerate `src/adacovex_version_info.ads` (`just build`), `sbom.json`
   (`just sbom`), and `src/adacovex-docs_template.ads` (`just book`).
4. Run `just check`, then `just test`, `just prove`, `just test-count`,
   `just proof-status`. Wire any new gate into `just check`,
   `tools/tasks.py` (`CHECK_GATES`), the CI jobs, and the AGENTS.md task
   table.
5. Update AGENTS.md if the source layout, CLI flags, SBOM behaviour, or
   dashboard features drifted.
6. Suggest a Conventional Commit message (British English, <=72 characters,
   scope from `docs/contributing/commits.md`); do not commit unless asked.
   If the release spans several components, suggest the atomic commit chain
   from the AGENTS.md rule.
7. State which version the change belongs to and whether it needs a MAJOR
   version (none of these items break the CLI contract, so no MAJOR).
8. When the release closes, replace its item detail in this plan with a
   changelog link. A closed release leaves no checklist text behind.

## Decisions (resolved)

1. Item 2: `--tz=local` is the local-timezone opt-in; the default is UTC+0.
2. Item 4: `--help` and `help` stay byte-identical; every topic renders the
   same frame.
3. Item 6: syft is reference material, never a runtime dependency.
4. Item 9: front-load docstrings; close the pass in v1.72.0.
5. Item 11: blank lines separate options in the main usage and in the prove
   topic; continuation lines stay attached.
6. Item 12: a cache hit is not a silent run. The replay is cached as plain
   text and printed again, so warm and cold output tell the same story.
7. Item 13: reuse `Adacovex.Ansi`; never store escape codes in the cache.
8. Item 14: annotations are emitted only when `GITHUB_ACTIONS` is set; a local
   run keeps the text block.
9. Item 15: the 60 s budget is split into measure (v1.70.0), build-once
   (v1.71.0), and close-out (v1.72.0), so no release promises an unmeasured
   speed-up.
10. Item 16: a platform dependency is an explicit skip with a reason, never a
    silent pass.
11. Item 18: the cache identity is the resolved absolute project path, the
    TTL is 7 days by default, and `--cache-clear` is a flag, not a new
    subcommand, because `cache` already selects `--cache`.
12. Item 20: one test root under `src/tests`; fixture projects live under
    `src/tests/projects` and are never compiled by the root GPR.
13. Item 17: a class counts as supported only when it is classified and gives
    an actionable fix; otherwise it is documented as fallback or a gap.
14. Item 19: `prove` help is the reference frame for every contextual topic.
