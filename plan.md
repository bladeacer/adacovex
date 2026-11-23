# adacovex release plan: v1.68.0 - v1.75.0

Current version: `1.74.0`. Work is scoped across **eight minor releases**:
`v1.68.0` through `v1.74.0` (closed), then `v1.75.0`.
Closed releases are recorded in their changelogs, not repeated here.

## Proof-timing phase note

All of these land in the **open `v1.61.0 -` phase** (representative `1.63.0`)
of `docs/contributing/perf/prove-timing.md`. The methodology is unchanged
(gnatprove-driven prove via the `prove` subcommand, result cache keyed the
same way, bundle specs excluded from the proof-input hash), so no phase
boundary or methodology-shift note is required. Item 18 changed what a warm
cache hit is keyed on, not how gnatprove runs, and items 26-28 add measurement
and documentation, not a prover change. When item 26 records fresh figures,
record the open-phase column from one run's complete metric set rather than
cherry-picking rows across versions.

## How work is distributed

| Version | Status | Theme | Items |
|---------|--------|-------|-------|
| v1.68.0 | closed | Output defaults and time | changelog `adacovex-1.68.0.md` |
| v1.69.0 | closed | Compiler-style diagnostics and output | changelog `adacovex-1.69.0.md` |
| v1.70.0 | closed | SBOM robustness and debt | changelog `adacovex-1.70.0.md` |
| v1.71.0 | closed | SBOM depth and pipeline speed | changelog `adacovex-1.71.0.md` |
| v1.72.0 | closed | Performance close-out and documentation currency | changelog `adacovex-1.72.0.md` |
| v1.73.0 | closed | Test suite portability and layout | changelog `adacovex-1.73.0.md` |
| v1.74.0 | closed | Cache identity, diagnostics, terminology, and modularity | changelog `adacovex-1.74.0.md` |
| v1.75.0 | planned | Dogfood close-out, CLI cohesion, and measured performance | 17b (Ada_CRDT robustness), 19 (contextual help audit), 26 (deterministic perf measurement), 27 (docs/stats), 28 (docs-bundle determinism and cost), final docs/STE pass |

## Status (2026-11-23)

v1.74.0 is closed; v1.75.0 is in progress. The tree holds 2486/2486 native
tests across 30 categories, 193 CLI e2e checks (the prove-configuration group
now runs whenever a prover is resolvable, instead of skipping on any host
without one on `$PATH`), 274 prove-e2e checks over the committed fixture
projects, and 1058 VCs at Gold.

### Delivered so far in v1.75.0

- [x] Counterexample switch: `--counterexamples=on|off` on `prove`, on by
default. The switch is part of the option string and therefore of the proof
result-cache identity, and `--counterexamples=off` skips the search.

- [x] Diagnostics accuracy: a finding that carries a counterexample is no
longer reported as a budget failure ("provers gave up"), because a
`+ provers gave up` line can follow a counterexample inside one gnatprove
message block. The block then keeps the actionable fix hint.

- [x] Unknown help topic: the message names the topic, suggests the nearest
known topic or flag, and lists the valid topics before the full usage. The
flag suggestion now closes its parenthesis.

Item 19 stays open for its remaining scope: one `Example` and one `See also`
line per topic, and exit codes where they are not 0/1.

The test tree has one root: `src/tests/` holds the native suite, the e2e
suites in `src/tests/e2e/`, and the fixture projects in
`src/tests/projects/`. `just test-layout-check` and `just portability-check`
keep that shape.

The debt register has no unowned open row: D13 closed with the API docstring
pass, and D11 and D7 stay open with v1.75.0. The v1.74.0 scope carried the
toolkit terminology rename, the documentation accuracy audit, the Python and
test script split, and the per-unit proof cache; v1.75.0 carries the dogfood
close-out, the help audit, and the measured-performance and stats work.

## Every change

Every change also updates, in the same change: `docs/`, Ada docstrings feeding
`docs/api-docs`, `docs/changelogs/adacovex-<version>.md`, AGENTS.md source tree
(if source layout changed), and the `just check` gates
(`docs-check`, `action-parity-check`, `docs-coverage-check`,
`diagnostics-coverage-check`, `test-layout-check`, `portability-check`,
`surface-parity-check`, `version-consistency-check`, `docs-tree`, `link-check`,
`book-links-check`, `python3 tools/gen-docs.py --check`, then `just book`).
After `just test` and `just prove`, run `just test-count` and
`just proof-status`.

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

The v1.65.0-v1.67.0 plan and `old-plan.md` are retired. The warm-tree check
history (344 s, then 453 s), the 60 s budget, and the closing 38.77 s run are
on
[`docs/contributing/perf/check-pipeline.md`](docs/contributing/perf/check-pipeline.md).

---

## v1.72.0 - closed

Performance close-out and documentation currency: items 15c, 21-25, the
debt close-out (8c), and the API docstring pass (9).
Record: [`adacovex-1.72.0.md`](docs/changelogs/adacovex-1.72.0.md).

---

## v1.73.0 - closed

Test suite portability and layout: item 20 (one test root and real fixture
projects) and item 16 (platform-agnostic suite).
Record: [`adacovex-1.73.0.md`](docs/changelogs/adacovex-1.73.0.md).

<!-- v1.73.0 item detail retired with its changelog -->

---

## v1.74.0 - closed

Cache identity, diagnostics, terminology, and modularity: items 18 (resolved
location, per-unit proof entries, lifetime, clear), 17a (contract-error
matrix), 21 (toolkit terminology), 22 (docs accuracy audit), 23 (modular
Python and test scripts), 24 (cache-path audit), and 25 (complexity language
parity). The release also closes the item 18 gap with a per-unit proof cache
and extends the fixtures to every classified check kind.
Record: [`adacovex-1.74.0.md`](docs/changelogs/adacovex-1.74.0.md).

<!-- v1.74.0 item detail retired with its changelog -->

---

## v1.75.0 - Dogfood close-out, CLI cohesion, and measured performance

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

- [ ] Item 26 - Deterministic performance measurement at every release

**Goal:** Every version bump publishes measured timings, not remembered ones.
A figure names its version, its host profile, and the command that produced
it, and a speed-up claim always carries a before/after pair from one host.

**Work:**
- Use `hyperfine` for the stable shapes (`prove` warm/cold, pipeline
  warm/cold, docs bundle), `strace -c` for the syscall profile of the no-op
  and warm shapes, `perf stat` where the host permits it, and the shell `time`
  fallback when a tool is missing. `tools/bench.py` stays the single owner of
  the measurement recipe.
- Add a `just perf-report` task that writes the current table under
  `docs/stats/`, and run it at every version bump. A release without a fresh
  row is incomplete.
- Record the host profile beside each table: CPU, kernel, filesystem, compiler,
  gnatprove version, and the build profile.
- Keep the raw output under `obj/` and the summary in the docs; never edit a
  number by hand.
- Do not claim a speed-up without a same-host, same-profile before/after pair.

**Tests:** the tools suite covers the table formatter and every missing-tool
fallback, so a host without `perf` or `hyperfine` still produces a complete
report.

**Verify:** `just perf-report`, one release dry run, `just tools-check`.

---

- [ ] Item 27 - A stats section for contributors and curious users

**Goal:** `docs/stats/` is the single home for measured numbers: pipeline and
prove timings, binary size, syscall profiles, cache hit rates, bundle size,
and test counts. A reader finds the current value and the method behind it
without reading a changelog.

**Work:**
- Create `docs/stats/` with one page per metric family, and add it to the
  `docs/index.md` toctree.
- Move the current figures from `docs/contributing/perf/` and
  `docs/usage/performance.md` behind links; keep the method and optimisation
  history pages where they are.
- Each page states the version, host profile, command, and raw result. The
  prose explains only what moved and why.
- Keep `docs/contributing/perf/` for method and history; `docs/stats/` is the
  record.

**Tests:** `just docs-tree`, `just docs-coverage-check`, `just link-check`,
and `just book-links-check`.

**Verify:** `just book`, `just check`.

---

- [ ] Item 28 - Make the docs bundle deterministic and cheap

**Goal:** The offline manual stays embedded in the Ada binary, with no new
non-dev dependency, but a docs build is incremental, reproducible, verified,
and cheap.

**Work:**
- Measure the current bundle cost (Sphinx build, gzip, base85, spec write) and
  record it under `docs/stats/`.
- Replace the remaining brittle steps with one content-addressed manifest that
  names every input and output. A missing build directory still falls back to
  the committed spec, never a partial bundle.
- Keep the encoder pure standard-library `gzip` + base85 and parallel across
  cores. Add no JSON, JavaScript, or npm tool.
- Fail loudly when a page is missing from the bundle, a link does not resolve,
  or the fingerprint disagrees with the committed spec.
- Document the rebuild decision tree and the measured cost.

**Tests:** `tools/test_docs_generation.py` covers the fingerprint, the
incremental rebuild, the removed-page sweep, and the canonical search index;
`just book-links-check` and `python3 tools/gen-docs.py --check` cover the
committed artifact.

**Verify:** `just book`, `python3 tools/gen-docs.py --check`,
`just tools-check`.

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

> **Before the v1.75.0 release:** delete `plan.md` and create
> `docs/changelogs/adacovex-1.75.0.md`. The changelog is the durable record
> once the plan retires.

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
12. Item 20: one test root under `src/tests`; the e2e suites live in
    `src/tests/e2e/` by category, and fixture projects live under
    `src/tests/projects` and are never compiled by the root GPR.
13. Item 17: a class counts as supported only when it is classified and gives
    an actionable fix; otherwise it is documented as fallback or a gap.
14. Item 19: `prove` help is the reference frame for every contextual topic.
