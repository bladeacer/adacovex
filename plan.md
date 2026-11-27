# adacovex release plan: v1.76.0 - v1.77.0

Current version: `1.76.0`. `v1.76.0` is closed and recorded in its changelog.
The work ahead is **`v1.77.0`** (glossary, diagnostics depth, and the developer
configuration). Closed releases are recorded in their changelogs, not repeated
here.

## Proof-timing phase note

v1.76.0 folds into the **open `v1.63.0 - v1.76.0` phase**, represented by
`1.76.0`, in `docs/contributing/perf/prove-timing.md`. The D16 fix closed the
warm-walk regression, so the column reads 19 014 `newfstatat` calls against
282 020 in the 1.75.0 column. The quiet-host re-measure (R10) returned
pipeline warm 354.6 ms and prove warm 655.5 ms, so the earlier 682 ms and
1.27 s at load 2.85 were host-bound. The column now records the idle set.

## How work is distributed

| Version | Status | Theme | Items |
|---------|--------|-------|-------|
| v1.76.0 | closed | CLI help ergonomics and documentation audience | [`adacovex-1.76.0.md`](docs/changelogs/adacovex-1.76.0.md) |
| v1.77.0 | in progress | Glossary, diagnostics depth, and developer configuration | R6 (glossary relocation and term links, done), R7 (diagnostics matrix coverage and examples), R8 (optional sibling projects), R9 (configuration parity with the CLI), R10 (quiet-host re-measure, done) |

## Status (2026-11-27)

v1.76.0 is closed: the tree holds version `1.76.0` (manifests, generated
version spec, SBOM), and its changelog is
[`adacovex-1.76.0.md`](docs/changelogs/adacovex-1.76.0.md). The tree carries
2606/2606 native tests across 30 categories, 226 CLI e2e checks, 274
prove-e2e checks over 20 committed fixture projects, and 1060 VCs at Gold.

The debt register holds no open row, and the quiet 1.76.0 re-measure wrote the
idle figures to `docs/stats/`.

### Started in v1.77.0

- [x] R6, the glossary: the seven Technical Name lexicons and their index moved
from `docs/contributing/ste100/` to `docs/glossary/ste100/`, with a Glossary
section in `docs/index.md` before the contributing section, a new toctree
caption, every inbound link updated (the docs pages, the changelogs, AGENTS.md,
`tools/rst2md.py`, and the docs-gate test), and the first-mention link rule
stated in the glossary index and AGENTS.md. The sweep links the first prose
mention of each distinctive term (a proper name, an acronym, or a defined
multiword concept) across `docs/usage/`, `docs/contributing/`, and
`docs/proof/`, the manual landing page, and the site-transparency page: 466
links over 57 pages. Ordinary English stays plain, and `SPARK_Mode` stays
plain because GitHub and Sphinx generate different anchors for its underscore.

## Every change

Every change also updates, in the same change: `docs/`, Ada docstrings feeding
`docs/api-docs`, `docs/changelogs/adacovex-<version>.md`, AGENTS.md source tree
(if source layout changed), and the `just check` gates
(`docs-check`, `action-parity-check`, `docs-coverage-check`,
`diagnostics-coverage-check`, `test-layout-check`, `portability-check`,
`surface-parity-check`, `version-consistency-check`, `docs-tree`, `link-check`,
`book-links-check`, `python3 tools/gen-docs.py --check`, then `just book`).
After `just test` and `just prove`, run `just test-count` and
`just proof-status`. Every change also runs the warm-run perf check in
AGENTS.md.

## Working constraints

1. `src/core/adacovex-prove.adb` sits just under the 600 cyclomatic cap. Put
   new I/O helpers in `Adacovex.Prove_Output` or a sibling unit, and run
   `just complexity-check` after a change there.
2. `src/tests/e2e/prove/prove_diagnostics.py` sets `NO_COLOR=1` so the text
   assertions compare plain output. Keep that when adding checks.
3. `just test-count` rewrites the live docs and the AGENTS.md tree. The crate
   description carries no test count, so no historical release manifest is
   rewritten; commit the generated manifests as-is.
4. `Adacovex.Prove_Output` counts as a proof unit. `just proof-status` keeps
   the VC ledger, the badges, and the timing page in sync.
5. `just check` runs `fmt` first. Re-run the full chain after a source edit; a
   green `complexity-check` alone does not cover the parity gates.
6. `surface-parity-check` ties the `--help` usage block, the man SYNOPSIS, the
   cli-reference usage fence, and the completion lists to the parser's
   subcommand set. A help restructure changes all of them in one change.

## Closed releases

Detailed item text for a closed release is removed once its changelog exists;
the changelog is the durable record of what shipped and why.

| Release | Delivered | Record |
|---------|-----------|--------|
| v1.68.0 | Coverage on by default, UTC+0 timestamp default, patched-artefact bound, API docstring pass | [`adacovex-1.68.0.md`](docs/changelogs/adacovex-1.68.0.md) |
| v1.69.0 | Repeated-diagnostic dedup, contextual help frame, warm-replay parity, severity colour, CI annotations, `--diagnostics=json`, action project-config, main-only release guard | [`adacovex-1.69.0.md`](docs/changelogs/adacovex-1.69.0.md) |
| v1.70.0 | Generated-build-tree fix, syft comparison, debt register, per-gate check timing | [`adacovex-1.70.0.md`](docs/changelogs/adacovex-1.70.0.md) |
| v1.71.0 | Syft-complete ecosystem table, lockfile readers, workflow actions, bounded artefact copy, command-text tool scan, build-once check pipeline | [`adacovex-1.71.0.md`](docs/changelogs/adacovex-1.71.0.md) |
| v1.72.0 | Root-project tooling hygiene, docs currency sweep, expected-output blocks, diagnostics matrix, generated docs tree, warm check under 60 s, complete API docstrings | [`adacovex-1.72.0.md`](docs/changelogs/adacovex-1.72.0.md) |
| v1.73.0 | One test root and real fixture projects, platform-agnostic suite | [`adacovex-1.73.0.md`](docs/changelogs/adacovex-1.73.0.md) |
| v1.74.0 | Resolved cache identity, per-unit proof entries, contract-error fixtures, toolkit terminology, docs accuracy audit, modular tool scripts | [`adacovex-1.74.0.md`](docs/changelogs/adacovex-1.74.0.md) |
| v1.75.0 | Counterexamples switch, default proof level, proof-cache identity, help-topic frames, `all` suppression, `docs/stats/` and `just perf-report`, one phase column | [`adacovex-1.75.0.md`](docs/changelogs/adacovex-1.75.0.md) |
| v1.76.0 | Warm-walk stat fix, grouped one-screen help and `-h`, one option table for the man page, user-first usage docs, embedded sample configuration, bare invocation asks for a target | [`adacovex-1.76.0.md`](docs/changelogs/adacovex-1.76.0.md) |

---

## v1.76.0 - closed

Delivered: CLI help ergonomics and documentation audience. The release record
is [adacovex-1.76.0.md](docs/changelogs/adacovex-1.76.0.md).

## v1.77.0 - Glossary, diagnostics depth, and developer configuration

The theme is a reader's footing: one glossary in plain language, a diagnostic
matrix backed by examples and tests, and a developer configuration that lets a
contributor use the sibling projects they actually have.

### R6 - A glossary at `docs/glossary/`, linked from the prose

- [x] Move `docs/contributing/ste100/` to `docs/glossary/ste100/`.
- [x] Link the first prose mention of each distinctive term across the docs.

**Goal:** The technical names live where a reader looks for them. A reader can
reach a term from the page that uses it.

**Work:**
- Move the seven term pages under `docs/glossary/ste100/`, add the new
  toctree entry, and update every inbound link (`AGENTS.md`, the contributing
  pages, and the `GUIDE_PAGES` table in `tools/rst2md.py`).
- Link the first mention of a distinctive term (a proper name, an acronym, or
  a defined multiword concept) on a page to its glossary heading, as a plain
  Markdown link with the anchor, so the Read the Docs link preview works
  offline and online. Leave ordinary English plain.
- Keep the glossary a documentation-only surface: a term entry still needs
  part of speech, definition, and banned synonyms.
- Add the glossary to `docs/index.md` in the reader-facing order, before the
  contributing section.

**Tests:** `just link-check` and `just book-links-check` cover the anchors;
`just docs-tree` regenerates the tree; the STE100 index remains the
single list.

**Verify:** `just book`, `just check`.

### R7 - Every diagnostics row has a test and a worked example

- [ ] Cover the documented support level of every diagnostic case.

**Goal:** A row in the diagnostics matrix is a claim, and a claim needs a test
and a rendered example a user can recognise.

**Work:**
- Add a fixture pair under `src/tests/projects/contract-errors/` for every
  case the matrix marks Supported without one, so the status column reads the
  fixture directory instead of a hand-written list.
- For each case marked Supported, render the diagnostics block for the broken
  variant and the quiet run for the fixed variant, and check the block's
  prover identity, source location, check kind, and fix hint.
- Add a page under `docs/usage/` that shows each case's diagnostics block in a
  fenced code block, generated from the fixtures so the page cannot drift.
- State the scope: the matrix targets the Ada 2012 / SPARK 2014 contract
  specification, and later-version features are out of scope for now.
- Keep `just prove-e2e` as the runner and keep the checks offline.

**Tests:** `prove_diagnostics.py` grows one case per matrix row; the new page
is checked against the fixture output.

**Verify:** `just prove-e2e`, `just diagnostics-coverage-check`,
`just test`.

### R8 - The sibling projects are optional

- [ ] A developer configuration selects which sibling projects a target
  checks.

**Goal:** A new contributor needs no checkout of `../polars`, `../playwright`,
or any other sibling. A contributor who has them can use them.

**Work:**
- Add `adacovex-dev.toml` at the repository root, with a `[[siblings]]` entry
  per project (name, path, ecosystem) and an empty default.
- Make the parser regression target read that file and skip a sibling whose
  path is absent, with a printed reason, instead of failing.
- Keep the committed fixture projects as the CI evidence; a sibling project is
  a local extra, never a CI requirement.
- Document the file on `docs/usage/configuration.md` and in the developer
  guide, and name the skip rule the target prints.

**Tests:** a tools test covers the parser and the missing-path skip; the target
runs green with an empty file.

**Verify:** `just tools-check`, `just sbom` or the parser target with an empty
file, `just check`.

### R9 - The configuration file matches the CLI

- [ ] Gate configuration parity with a check, before the 2.0.0 cut.

**Goal:** Every flag that changes a run can also live in `adacovex.toml`, and
a drift fails CI instead of waiting for a reader to find it.

**Work:**
- Map each `Known_Flags` entry to its configuration key, or to a documented
  exception (early-exit flags, output paths, serve-only options).
- Add `tools/check-config-parity.py`, wired as `just config-parity-check` and
  into `just check` and the CI quality job: a flag without a key, a key
  without a flag, or a key without a row in the configuration page fails.
- Document every key with its type, default, and the flag it mirrors, and keep
  the global file and the project file on one table.
- Fold the sample `adacovex.toml` from R4 into the same parity check.

**Tests:** the new gate plus its tools unit test.

**Verify:** `just config-parity-check`, `just check`.

---

### R10 - The 1.76.0 walls are re-measured on a quiet host

- [x] Repeat `just perf-report` at load under 1.0 and compare the walls.

**Goal:** The 1.76.0 session read pipeline warm at 682 ms and prove warm at
1.27 s, about 1.8 times the load-0.7 reading, while every unrelated build and
docs shape inflated by the same factor. The syscall count says the code shape
did not change, so the walls need one quiet session before anyone calls them
a regression.

**Work:**
- Run `just perf-report` when the 1-minute load is under 1.0 and fold the
  complete metric set into the open phase of
  `docs/contributing/perf/prove-timing.md`.
- Compare the result with the 378 ms pipeline warm and 680 ms prove warm that
  the D16 fix measured at load 0.7. A wall still above twice the idle reading
  is a real regression, and it opens a debt row with the paired evidence.
- [x] Take the prove-cold row, the one "not measured" cell in the phase.

**Result:** the session started at load 0.5 and its release build lifted the
report's own reading to 2.23. Pipeline warm read 354.6 ms, pipeline cold
378.3 ms, prove warm 655.5 ms, the no-op build 556.0 ms, a fresh Sphinx build
11.9 s, and the warm run 19 014 `newfstatat` calls. Prove cold read 129.7 s
+/- 4.6 s over 3 runs at 1060 VCs, from a later quiet take at load 0.97. Every
shape is back at its idle value, so there is no regression and no debt row.

**Tests:** none; the report itself is the measurement.

**Verify:** `just perf-report`, `just docs-check`, `just check`.

---

## Per-release checklist (apply to every version)

1. Implement the version's items (code + tests).
2. Update `docs/`, Ada docstrings, and `docs/changelogs/adacovex-<version>.md`.
3. Regenerate `src/adacovex_version_info.ads` (`just build`), `sbom.json`
   (`just sbom`), and `src/adacovex-docs_template.ads` (`just book`).
4. Run `just check`, then `just test`, `just prove`, `just test-count`,
   `just proof-status`, and `just perf-report`. Wire any new gate into
   `just check`, `tools/tasks.py` (`CHECK_GATES`), the CI jobs, and the
   AGENTS.md task table.
5. Update AGENTS.md if the source layout, CLI flags, SBOM behaviour, or
   dashboard features drifted.
6. Suggest a Conventional Commit message (British English, <=72 characters,
   scope from `docs/contributing/commits.md`); do not commit unless asked.
   If the release spans several components, suggest the atomic commit chain
   from the AGENTS.md rule.
7. State which version the change belongs to and whether it needs a MAJOR
   version. R5 is the one breaking change in this plan: a bare `adacovex`
   prints help instead of running an assessment. It ships in a minor release
   because no flag, output format, or exit code changes, and the changelog
   marks it as breaking with the one-flag replacement.
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
9. R1: the base `--help` stays a summary and the man page carries the detail.
   Contextual help is the route to a flag's full meaning.
10. R5: a bare invocation asks for a flag. The old bare form becomes
    `--target=.`, and the hint prints that command.
11. R6: `docs/glossary/` is the reader-facing home for the STE100 terms; the
    contributing section keeps only the writing rules.
12. R8: a sibling project is a local extra. CI reads the committed fixtures
    and never a sibling checkout.
13. R9: configuration parity is a CI gate before 2.0.0, not a documentation
    convention.
