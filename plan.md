# adacovex release plan: v1.76.0 - v1.77.0

Current version: `1.75.0`. Work ahead is scoped across **two minor releases**:
`v1.76.0` (CLI help ergonomics and documentation audience) and `v1.77.0`
(glossary, diagnostics depth, and the developer configuration).
Closed releases are recorded in their changelogs, not repeated here.

## Proof-timing phase note

All of this work lands in the **open `v1.63.0 - v1.75.0` phase**, represented
by `1.75.0`, in `docs/contributing/perf/prove-timing.md`. No item changes how
gnatprove runs or how the proof cache is keyed, so no phase boundary is
required. From `1.75.0` the open column is re-measured at each version, so a
release that moves a figure re-runs `just perf-report`, takes the complete
metric set again, and moves the representative. The v1.75.0 tree fails the
warm-run perf check by 35 times in stat count (debt D16), and the rule reads
against the post-fix baseline.

## How work is distributed

| Version | Status | Theme | Items |
|---------|--------|-------|-------|
| v1.76.0 | in progress | CLI help ergonomics and documentation audience | R1 (help restructure and `-h`, done), R2 (man page as full context, done), R3 (end-user documentation audience, done), R4 (bundled `adacovex.toml`), R5 (bare invocation and level 4) |
| v1.77.0 | planned | Glossary, diagnostics depth, and developer configuration | R6 (glossary relocation and term links), R7 (diagnostics matrix coverage and examples), R8 (optional sibling projects), R9 (configuration parity with the CLI) |

## Status (2026-11-25)

v1.75.0 is closed: the tree holds version `1.75.0` (manifests, generated
version spec, SBOM), and its changelog is
[`adacovex-1.75.0.md`](docs/changelogs/adacovex-1.75.0.md). The tree carries
2501/2501 native tests across 30 categories, 223 CLI e2e checks, 274
prove-e2e checks over 20 committed fixture projects, and 1060 VCs at Gold.

The debt register holds no open row.

### Delivered so far in v1.76.0

- [x] D16 (warm stat regression): the SPARK coverage walker uses the shared
skip predicate and the directory memo, so it no longer enters `.venv`; the
coverage summary line reuses the rollup the level assessment measured instead
of walking the tree a second time; and the vendor-hash discovery walk takes
the memo. A warm run reads 18 904 `newfstatat` and 378 ms, against 282 020 on
the 1.75.0 binary for the same tree. `Skip_Walk_Dir` is now in the
`Adacovex.Parsers.Manifest` spec, so a walker cannot keep a private copy.

- [x] R1, first slice: `-h` equals `--help` in every position, including
`prove -h` and `help`/`-h` topic selection, and the base `--help` is now a
50-line summary grouped under Assess, Report, Prove, Cache and scope, CI
gates, Differential and SBOM, and More detail. Its last group points at
`help TOPIC` and `man`, which carry the detail; the CLI e2e checks the line
count, each heading, and the pointer. The man page option list and the tldr
page keep their flat order until R2 generates both from the same table.

- [x] R3: `docs/usage/index.md` states the reading convention, and installation,
platforms, performance, dashboard HTML, the bundled manual, and the SBOM
ecosystem table move their build, CI, and fixture detail into
`> **For contributors:**` callouts. AGENTS.md carries the rule for later pages.
The audit found the help footer still calling `--help` the full option list and
the syft comparison still claiming no action cataloguer, with stale counts.

- [x] R2: the option text lives in one table, `Adacovex.Cli_Help`, with a
task group per option. The man page renders that table under the console
frame's seven headings, every `Known_Flags` entry appears exactly once, and a
test fails on an unknown option or a missing group. The stub description is
gone.

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

---

## v1.76.0 - CLI help ergonomics and documentation audience

The theme is one question: what does a user see in the first ten seconds. The
tool should read like a Unix program that expects flags, tells a user where the
detail lives, and keeps maintainer material out of the way of the task.

### R1 - A shorter `--help`, grouped, with `-h` and contextual help first

- [x] Accept `-h` wherever `--help` works, including after a subcommand.
- [x] Group and shorten the base `--help` so it fits one screen, and point
  its footer at contextual help and the man page.
- [x] Group the man-page option sections (done in R2). The tldr page keeps
  its flat order: the tldr format has no group heading, and its examples are
  already ordered by the same task sequence.

**Goal:** The base `--help` fits one screen and groups its flags by task. A
user who wants detail reaches it through contextual help, not by scrolling.

**Work:**
- Group the base `--help` flags by intent (assessment, output, cache, serve,
  CI gates, subcommands) with a one-line heading per group, and keep the
  per-flag text to a phrase.
- Point to the detail: the base footer names `adacovex help <topic>`,
  `adacovex <subcommand> --help`, and the man page.
- Apply the same grouping to the man page option sections and to the tldr
  page, keeping the tldr page shorter than the base `--help`.
- Audit `prove --help` first: it is the frame with the most options, so it
  sets the grouping and the wording every other topic copies.
- Keep `help <topic>` and `<subcommand> --help` byte-identical, and keep the
  exit code of a help request at 0.
- Update the CLI reference, the tldr page, and the completion subcommand lists
  in the same change, because `surface-parity-check` reads all of them.

**Tests:** `adacovex_config_tests.adb` snapshots the group order and asserts
`-h` equals `--help` in every position; `cli-e2e` asserts the base frame holds
one screen of lines and that each group heading appears once.

**Verify:** `just test`, `just cli-e2e`, `just surface-parity-check`,
`just docs-coverage-check`.

### R2 - The man page carries the full context

- [ ] Generate each option's man-page description from its `--help` text, so
  no entry reads "See --help for details".

**Goal:** The man page is the complete offline reference: the union of every
help frame, not a synopsis with stubs, generated from the one option table
both surfaces read.

**Work:**
- Build the man page from the same option table the help renderer reads, so a
  description has one source and the man page cannot drift.
- For each option: the summary sentence, the default, an example where the
  flag needs one, and the related flag it is often paired with.
- Order the man sections as the help groups are ordered, and keep the
  SYNOPSIS and the DESCRIPTION tagline that `surface-parity-check` requires.
- Fail the build when an option in the table has no description.

**Tests:** `adacovex_man_tests.adb` asserts that every `Known_Flags` entry has
a non-empty description, that no description contains "See --help", and that
the section order matches the help groups.

**Verify:** `just test`, `just man`, `just surface-parity-check`.

### R3 - The documentation speaks to end users first

- [x] Move maintainer-only detail into blockquotes and callouts.

**Goal:** A user who installs the tool and reads the docs meets the task
first. A contributor still finds every detail, one level down.

**Work:**
- Read `docs/usage/` as an end user and move `just` targets, `alr` recipes,
  fixture layout, gate internals, and CI job wiring into a callout at the
  point they are needed, or into `docs/contributing/`.
- Keep the detail, never delete it: a callout keeps the text and the reason.
- State the user-facing command for every operation a user can perform
  (`adacovex prove`, `adacovex sbom`, `adacovex status`), and leave the
  developer command inside the callout.
- Apply the rule to the dashboard prose too, which must keep naming the
  user-facing subcommands only.
- Use the glossary (R6) for the first mention of a term on a page.

**Tests:** `just docs-check`, `just docs-coverage-check`,
`just docs-tree`.

**Verify:** `just book`, `just check`.

### R4 - The sample configuration ships inside the manual

- [ ] Show the full `adacovex.toml` as a code block on the configuration page.

**Goal:** A reader of the bundled manual copies the complete configuration for
the version they run, without opening the repository.

**Work:**
- Embed the repository's `adacovex.toml` on
  `docs/usage/configuration.md` as a copyable code block, generated from the
  file so the two cannot drift.
- State which version the block belongs to and that every key shows its
  default.
- Add a check that fails when the block differs from the committed file.

**Tests:** the new check joins `just docs-check` or `just tools-check`; the
manual link check covers the page.

**Verify:** `just book`, `just docs-check`.

### R5 - A bare invocation prints help, and `just prove` is level 4

- [ ] `adacovex` with no arguments prints the help frame and exits 0.

**Goal:** The CLI behaves like a Unix tool: flags select work, and a bare
invocation asks for one. Proof targets agree on level 4.

**Work:**
- Make a bare `adacovex` print the main usage and exit 0. A run needs a flag
  (`--target`, `--serve`, or a subcommand). Print a hint that names the flag.
- Record the change as breaking in the changelog, because the old bare form
  ran an assessment on the current directory. Keep `--target=.` the exact
  replacement and say so in the hint.
- Confirm `just prove` and `./bin/adacovex prove` both send level 4, and add a
  check that fails when the task passes another level.
- Update the README quick start, the tldr page, the CLI reference, and the
  action docs.

**Tests:** `adacovex_config_tests.adb` covers the bare form, the hint, and the
exit code; `cli-e2e` asserts the bare form prints the usage and that
`./bin/adacovex prove` reports level 4.

**Verify:** `just test`, `just cli-e2e`, `just surface-parity-check`,
`just action-parity-check`.

---

## v1.77.0 - Glossary, diagnostics depth, and developer configuration

The theme is a reader's footing: one glossary in plain language, a diagnostic
matrix backed by examples and tests, and a developer configuration that lets a
contributor use the sibling projects they actually have.

### R6 - A glossary at `docs/glossary/`, linked from the prose

- [ ] Move `docs/contributing/ste100/` to `docs/glossary/ste100/`.

**Goal:** The technical names live where a reader looks for them. A reader can
reach a term from the page that uses it.

**Work:**
- Move the seven term pages under `docs/glossary/ste100/`, add the new
  toctree entry, and update every inbound link (`AGENTS.md`, the contributing
  pages, and the `GUIDE_PAGES` table in `tools/rst2md.py`).
- Link the first mention of a term on a page to its glossary heading, as a
  plain Markdown link with the anchor, so the Read the Docs link preview works
  offline and online.
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
