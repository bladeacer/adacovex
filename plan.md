# adacovex release plan: v1.68.0 - v1.72.0

Current version: `1.69.0`. Work is scoped across **five minor bumps**:
`v1.68.0` (closing), `v1.69.0`, `v1.70.0`, `v1.71.0`, and `v1.72.0`.

## Proof-timing phase note

All of these land in the **open `v1.61.0 -` phase** (representative `1.63.0`)
of `docs/contributing/perf/prove-timing.md`. The methodology is unchanged
(gnatprove-driven prove via the `prove` subcommand, result cache keyed the
same way, bundle specs excluded from the proof-input hash), so no phase
boundary or methodology-shift note is required. Each release's `just prove`
figures must still use the phase's complete metric set for the representative
version; do not cherry-pick rows across versions.

## How work is distributed

| Version | Status | Theme | Items |
|---------|--------|-------|-------|
| v1.68.0 | closed | Output defaults, time, and old-plan closeout | 1, 2, 7, bulk of 9 |
| v1.69.0 | closed | Compiler-style diagnostics and output | C1-C9 delivered (3 dedup, 4 help frame, 11 help spacing, 12 cache parity, 13 colour, 14 CI annotations, 10a compiler-style findings + JSON, 10b annotation e2e, 10c mode matrix, old-plan 3.1 action project config) |
| v1.70.0 | planned | SBOM robustness and debt | 5 (C-project false positives), 6a (syft comparison), 8a (debt register), 15a (pipeline measurement), remainder of 9 |
| v1.71.0 | planned | SBOM depth and pipeline speed | 6b (lockfiles, indirect deps, scope, licences), 8b (bounded-string and manifest debt), 15b (build-once/prove-once) |
| v1.72.0 | planned | Performance close-out and polish | 15c (parallel gates, caching, 60 s budget), 8c (debt paydown), 9 close-out, docs/STE drift pass |

## Session status (2026-11-11)

v1.68.0 and v1.69.0 are closed. The second session finished items 10a, 10b,
10c, and old-plan 3.1: compiler-style findings with grouping, solver,
counterexamples, source excerpts, and `--diagnostics=json`; an annotation
e2e run; the diagnostics mode matrix; and a real action run against a project
`adacovex.toml`. The tree now holds 2175/2175 tests, 132 prove-e2e checks,
and 1057 VCs at Gold. The detailed handover for v1.70.0 is in
[`impl-session-backlog.md`](impl-session-backlog.md).

Every change also updates, in the same change: `docs/`, Ada docstrings feeding
`docs/api-docs`, `docs/changelogs/adacovex-<version>.md`, AGENTS.md source tree
(if source layout changed), and the `just check` gates
(`docs-check`, `action-parity-check`, `docs-coverage-check`,
`surface-parity-check`, `version-consistency-check`, `doc-links`, `link-check`,
`book-links-check`, `python3 tools/gen-docs.py --check`, then `just book`).
After `just test` and `just prove`, run `just test-count` and `just
proof-status`.

## Audited from the tooling-ergonomics plan (`old-plan.md`)

The v1.65.0-v1.67.0 plan is audited and closed. These items shipped and the
v1.67.0 changelog records them: tldr/man parity (C1/C2), the diagnostics
block, `--fail-on` and `.covex-ignore` (v1.66.0), configuration and `init`
(C2/C3), serve watch with `--no-watch` (C4), the docs map and performance
split (C5), and build-once plus the timing table and the recorded warm-tree
budget (C6). `old-plan.md` is deleted once this section is confirmed complete
(it is: every old checkbox is either closed below or carried as an item).

Two checkboxes were never closed, so they carry into the schedule:

- [x] Old-plan 3.1: an end-to-end test that the composite action behaves like
  the binary when a target repository carries `adacovex.toml` (priority:
  high; it is the only shipped behaviour without a real-run action test).
  **Done in v1.69.0** via the `action-project-config` CI job.
- [x] Old-plan 3.4: a warm-tree `just check` took **344 s** on 2026-11-06
  (12 logical CPUs, warm cache and gnatprove session). The measurement is in
  `docs/contributing/perf/check-pipeline.md`; the 60 s target is not met.
- [ ] Close the 344 s -> 60 s warm-tree gap. The proof gate (100 s) and the
  complexity walk (98 s) are 57 percent of the total, so start there
  (priority: high). **Split across items 15a-15c (v1.70.0-v1.72.0).**

---

## v1.68.0 close-out and early v1.69.0 output work

The output items below (11-14) landed after the v1.68.0 manifest bump, so the
v1.69.0 changelog records them. The v1.68.0 items (1, 2, 7) are closed in
their own changelog.

- [x] Item 1 - Make showing coverage the default when running
  `adacovex prove` / plain `adacovex`.
- [x] Item 2 - Store timestamps as UTC+0 by default; opt in to the local
  timezone with `--tz=local`.
- [x] Item 7 - Sibling-binary bug: `adacovex-prove.adb:2821 length check
  failed` in the patched-proof artefact copy.
- [x] Item 11 - Help options are separated by blank lines.
- [x] Item 12 - A warm `prove` cache hit prints the diagnostics of the run it
  serves, and the coverage line prints once per run.
- [x] Item 13 - The concise prove replay is coloured by severity.
- [x] Item 14 - Unproved findings print GitHub Actions inline annotations.
- [x] Item 9 (bulk) - Docstrings: parameters and returns are described across
  the touched API surfaces.

---

- [x] Item 1 - Proof-coverage summary is the default for plain `adacovex` *(done in v1.68.0)*

**Goal:** A successful `prove` run prints the statement / subprogram / VC
coverage line by default; `--no-coverage` hides it for one run,
`[prove] coverage = false` hides it for every run, and an explicit
`--coverage` wins.

**Result:** `Prove_Show_Coverage` defaults on; the config file and both flags
are honoured; plain `adacovex` prints the line from cached artefacts.

---

- [x] Item 2 - Timestamps are UTC+0 unless the user opts into the local zone *(done in v1.68.0)*

**Goal:** The default is `UTC+00:00`. `--tz=local` selects the operating
system zone, and any explicit IANA name or `UTC+N` offset still wins.
A bad value fails loudly.

**Result:** `Adacovex.Timezones.Default` returns UTC+0; `Default_Local` is
used only when `Is_Local_Spec` matches `--tz=local`.

---

- [x] Item 7 - Patched-proof artefact copy fits a 17-character bound *(done in v1.68.0)*

**Root cause:** the artefact-name array had a 15-character component type and
the padded summary name is 17 characters, so the first patched run raised a
length check after a successful proof.

**Result:** both names share the 17-character bound. `just run-ada-crdt`
proves 972 checks and exits 0.

---

- [x] Item 11 - Blank lines between help options *(done in v1.68.0)*

**Goal:** The main `--help` options list and the contextual `prove` help read
as grouped entries, not one dense block.

**Result:** `Print_Usage` emits a blank line before each new option (a
continuation line gets none), and the `prove` topic lists each flag on its
own line with a short description. `--help` and `help` stay byte-identical.

---

- [x] Item 12 - Warm prove output agrees with a cold prove run *(done in v1.68.0)*

**Goal:** `make prove` in `../Ada_CRDT` (a cold run) and `just run-ada-crdt`
(a warm cache hit) must not disagree about what the prover reported.

**Result:** the quiet replay is written to a temp file, printed with
severity colours, and cached under the proof input hash
(`provereplay:<hash>`). A warm hit prints the cached text, so warnings, the
diagnostics block, and the filtered/duplicates footers appear in both shapes.
The duplicated coverage line is gone: a prove-mode run prints it in
`Run_Prove` only (fresh run and cache hit alike), and the plain pipeline
prints it only when it is not a prove-mode run.

**Residual difference:** the two invocations pass different options
(`just run-ada-crdt` adds `--level 4`), so the printed `options:` line and the
cache key differ. That is caller intent, not a tool inconsistency.

---

- [x] Item 13 - Concise prove output is coloured by severity *(done in v1.68.0)*

**Goal:** Prettify the base stdout with ANSI escape sequences, without
inventing a new colour layer.

**Result:** the replay printer colours errors red, warnings yellow, notices
and locations dim, `Success:` green, and the coverage / cache / proof /
filtered / duplicates lines bold. It reuses `Adacovex.Ansi`, so `CI`,
`NO_COLOR`, and `TERM=dumb` still produce plain text. Cached replay text is
stored without escape codes, so colour is decided at print time.

---

- [x] Item 14 - CI logs show inline proof annotations *(done in v1.68.0)*

**Goal:** An unproved finding should also appear as a GitHub Actions
annotation, not only in a text block.

**Result:** `Annotation_Line` renders
`::error file=...,line=...,col=...,title=SPARK proof failed::<kind>` from the
recorded `file:line:column` and check kind. `Emit_Annotations` prints one
annotation per distinct finding when `GITHUB_ACTIONS` is set. A malformed
location yields no annotation. Wire the workflow-level annotation expectations
in v1.69.0 item 10b.

---

- [x] Item 9 (bulk) - API docstrings describe every parameter and return *(v1.68.0-v1.72.0)*

**Goal:** Generated API pages such as `Adacovex_Man_Tests` / `procedure Run`
must not show empty `@param` / `@return` / description cells. Front-load the
pass and keep it enforced by `just doc` + `just docs-coverage-check`.

**Remainder:** the v1.70.0 and v1.72.0 touch-ups cover packages changed by
their items; item 9 closes in v1.72.0.

---

## v1.69.0 - Compiler-style diagnostics

- [x] Item 3 - `just run-ada-crdt` diagnostics dedup *(C1 in v1.69.0; grouping remains in 10a)*

**Goal:** A repeated warning (one per inlined call site) prints once, and a
check reported twice counts once.

**Result:** `Replay_Suppressed` keeps the first diagnostic line and drops the
repeat with its continuation, and states the count in a `duplicates:` footer.
`Collect_Failures` keys findings on `location|kind`, so the block does not
inflate `Unproved`. What remains for v1.69.0 is item 10's grouping: the same
warning with different `, in call inlined at ...` suffixes is one finding with
several call sites.

**Verify:** `just run-ada-crdt`, `just prove-e2e`.

---

- [x] Item 10a - Findings read like a compiler (`file:line:col: error: kind`) *(done in v1.69.0)*

**Goal:** A `prove` failure names the source file and line, the check that
failed, the exact solver that failed it, a counterexample when one exists, and
one actionable fix. Render each finding as a compiler diagnostic with the
source line and caret, not only a solver transcript.

**Work:**
- Group a finding by its own location and message when only the
  `, in call inlined at file:line` suffix differs; print the call sites once
  on a continuation line.
- Ask gnatprove for counterexamples (`--counterexamples=on`) and read the
  values into the finding, so the block says which input fails.
- Attribute each finding to the solver that produced it (SARIF result and the
  gnatprove summary), not only to the prover version.
- Render `file:line:col: error: <kind>` with the source excerpt, caret, solver,
  counterexample, and one fix hint.
- Add `--diagnostics=text|json` so the same facts are machine-readable.
- Keep the concise default and the `--verbose` contract: the detail extends
  the block, it does not add a third mode.

**Files:** `src/core/adacovex-prove.adb/.ads`, `src/core/adacovex-config.ads/.adb`,
`src/parsers/adacovex-parsers-gnatprove.adb` (SARIF solver field),
`docs/contributing/proving-diagnostics.md`, `docs/usage/cli-reference-flags.md`.

**Result:** each finding renders `file:line:col: error: <kind>` with its
solver set, counterexample, source excerpt and caret, and one fix hint. The
inlined-call-site suffix is grouped into `call sites: N`. `prove` always asks
for counterexamples, and `--diagnostics=json` prints the same facts as one
object. The solver is the summary row's prover set, because gnatprove 16.1
records solvers per category rather than per SARIF result.

**Tests:** `src/tests/adacovex_prove_runner_tests.adb` (counterexample and
solver parsing, inlined-call grouping, JSON shape);
`tests/e2e/prove_diagnostics.py` (one grouped finding for two call sites, the
`file:line:col:` prefix, and the JSON form).

**Verify:** `just prove-e2e`, `just cli-e2e`, `just run-ada-crdt`.

---

- [x] Item 10b - CI annotations end to end (action and workflows) *(done in v1.69.0)*

**Goal:** The annotation `Emit_Annotations` prints is produced by the CI entry
points too, so a failing proof marks the pull request diff inline.

**Work:**
- Confirm the composite action runs the binary with `GITHUB_ACTIONS` intact
  (it is set by the runner; do not scrub the environment).
- Add one workflow fixture that proves a deliberately broken project and
  asserts the annotation line (or a `::error` prefix) appears.
- Document the annotation shape in `docs/usage/ci-cd.md`.

**Result:** `tests/e2e/prove_diagnostics.py` runs the broken index fixture
with `GITHUB_ACTIONS=true` and asserts one `::error file=` annotation per
distinct finding. `docs/usage/ci-cd.md` states the annotation shape and the
runner environment rule.

**Files:** `action.yml`, `.github/workflows/ci.yml`, `tests/e2e/cli_flags.py`
or `tests/e2e/prove_diagnostics.py`, `docs/usage/ci-cd.md`.

**Tests:** a simulated `GITHUB_ACTIONS=true` run of a broken fixture asserts
one `::error file=` line per distinct finding.

**Verify:** `just prove-e2e`, `just action-parity-check`.

---

- [x] Item 10c - Diagnostics documentation and mode matrix *(done in v1.69.0)*

**Goal:** One page states the two modes (concise = replay + block,
`--verbose` = raw stream), where colour applies, and what CI emits. Keep the
`--quiet` / `--suppress-warnings[=SETS]` semantics unchanged.

**Result:** `proving-diagnostics.md` carries the mode matrix (text, JSON,
verbose, quiet, custom quiet), the compiler-style block, and the JSON shape.
`cli-reference-flags.md` documents `--diagnostics` and the counterexample
request. `ci-cd.md` documents the annotation shape.

**Files:** `docs/contributing/proving-diagnostics.md`,
`docs/usage/cli-reference-flags.md`, `docs/usage/ci-cd.md`,
`docs/changelogs/adacovex-1.69.0.md`.

---

- [x] Old-plan 3.1 - Composite action honours a project `adacovex.toml` *(done in v1.69.0)*

**Goal:** A real action run against a repository carrying a project file
changes the run the same way the binary does (coverage line, jobs, level,
project-over-global precedence).

**Result:** the `action-project-config` CI job runs the real action against a
fixture that sets `[prove] coverage = false` and `[prove] level = 1`, then
asserts `--level 1` in the teed proof log and the absence of `coverage:`.

**Files:** `.github/workflows/ci.yml` (or a dedicated workflow),
`action.yml`, `tests/e2e/cli_flags.py` (or a new action e2e),
`docs/usage/ci-cd-action.md`.

**Verify:** the new job plus `just action-parity-check`.

---

- [x] Item 4 - Contextual help renders in the `--help` frame *(done in v1.68.0)*

**Result:** every topic opens with the version line, `Usage:` fence,
`Options:` heading, body, and footer. `prove --help` selects the prove topic.
`--help` and `help` stay byte-identical. Item 11 added the option spacing.

---

## v1.70.0 - SBOM robustness and debt

- [ ] Item 5 - SBOM false positives on C projects (yams)

**Goal:** `adacovex sbom` on a C project must not list `cargo` or `go` as
dependencies or create spurious edges. Audit whole-word tool scanning versus
declared dependency parsing.

**Files:** `src/parsers/adacovex-parsers-manifest-scan_file.adb`,
`...-read_manifest_deps.adb`, `...-register_root_*_deps.adb`,
`...-classify_scope.adb`, `src/renderers/adacovex-renderers-sbom.adb`,
`docs/usage/sbom.md`, `docs/usage/sbom-resolution.md`.

**Tests:** `src/tests/adacovex_sbom_tests.adb` with a C-project fixture (no
`Cargo.toml`, `go.mod`, or `package.json`); assert no `cargo` / `go`
components and no spurious edges. Pin the sibling set in
`tests/e2e/cli_flags.py` (`check_sbom_siblings`).

**Verify:** `adacovex sbom` over `../yams`, `just test`, `just sbom`.

---

- [ ] Item 6a - Compare the SBOM parser with syft; write down the gaps

**Goal:** Benchmark component / version / licence coverage against
`https://github.com/anchore/syft` on self, yams, and Ada_CRDT. Document the
differences and choose the gaps worth closing under the zero-dependency rule.

**Decision:** syft is not installed or expected for users. Reference its
source with attribution; do not call it at run time.

**Files:** `docs/usage/sbom-resolution.md` (comparison table + findings),
`docs/THIRD_PARTY_NOTICES.md` if source is quoted.

**Verify:** a manual diff on fixtures; `just sbom`.

---

- [ ] Item 8a - Technical debt register

**Goal:** Start a debt register with a "done when" for each item surfaced by
these releases: duplicated diagnostics, manifest parsing, bounded strings,
timezone consistency, help framing, cache parity, colour, annotations. Keep
`SPARK_Mode (Off)` at exactly `Types.Implementation` and `Complexity`; every
new executable statement carries contracts.

**Files:** `docs/contributing/debt.md` (new) plus the toctree entry, or a
section in `docs/contributing/developer-guide.md`.

**Verify:** `just spark-off-check`, `just prove`, `just test-count`,
`just proof-status`.

---

- [ ] Item 15a - Measure the check pipeline properly

**Goal:** Record per-gate and per-recipe wall time (warm and cold) in one run,
with the raw stdout kept. This is the measurement the 60 s budget needs.

**Files:** `docs/contributing/perf/check-pipeline.md`,
`tools/tasks.py` (timing output only, no gate changes).

**Verify:** one full `just check` run with the per-gate table.

---

## v1.71.0 - SBOM depth and pipeline speed

- [ ] Item 6b - Adopt the safe SBOM robustness gaps

**Goal:** Implement the syft comparison gaps that fit the zero-dependency
constraint: lockfile parsing, indirect-dependency handling, scope
classification, and licence resolution.

**Files:** the `adacovex-parsers-manifest-*` units, `docs/usage/sbom-resolution.md`,
`docs/contributing/architecture-dependencies.md`.

**Tests:** regression fixtures for lockfiles, indirect deps, and a missing
licence in `src/tests/adacovex_sbom_tests.adb`.

**Verify:** `just sbom`, `just test`, `just book`.

---

- [ ] Item 8b - Bounded-string and manifest debt

**Goal:** Remove the classes of defect the patched-artefact and manifest items
exposed: fixed-width copies that can overflow, artefact-name arrays without a
shared bound, and scanner heuristics that confuse a tool mention with a
dependency.

**Files:** `src/core/adacovex-prove.adb` (bounded artefact copies),
`src/parsers/adacovex-parsers-manifest-*.adb`, `src/core/adacovex-types.ads`
(`Max_*` constants and their documented contract).

**Verify:** `just test`, `just prove`, `just complexity-check`.

---

- [ ] Item 15b - Build once and prove once

**Goal:** One build and one gnatprove run feed every later gate. No gate
recompiles, re-bundles, or re-proves what an earlier gate produced.

**Files:** `tools/tasks.py` (`CHECK_GATES`), `tools/build.py`,
`tools/run.py`, `tools/prove.py` if one is introduced.

**Verify:** `just check` gate table shows the duplicate work gone;
`docs/contributing/perf/check-pipeline.md` updated.

---

## v1.72.0 - Performance close-out and polish

- [ ] Item 15c - Close the 344 s -> 60 s warm-tree gap

**Goal:** `just check` finishes under a minute on the dev machine with a warm
cache and a warm gnatprove session. No gate is weakened and no check is
dropped. Group the native tests, the CLI e2e checks, and the diagnostics
fixtures into one invocation each; run independent gates in parallel with the
standard library, a CPU cap, and the unchanged PASS/FAIL/SKIP summary.

**Files:** `tools/tasks.py`, `tools/tests.py`,
`docs/contributing/perf/check-pipeline.md`, `docs/contributing/perf/prove-timing.md`.

**Verify:** a recorded warm run with the complete metric set for the open
phase's representative version.

---

- [ ] Item 8c - Debt paydown close-out

**Goal:** Every open register entry is closed or explicitly accepted with a
reason. No new debt from v1.69.0-v1.72.0 remains unrecorded.

**Verify:** the register plus `just check`.

---

- [ ] Item 9 close-out - API docstring completeness

**Goal:** `just doc` produces no empty description, `@param`, or `@return`.
`just docs-coverage-check` passes.

**Verify:** `just doc`, `just docs-coverage-check`.

---

- [ ] Release polish - docs, STE, and parity drift

**Goal:** Re-read the user docs against the codebase surface: every
`Known_Flags` entry in the CLI reference, every dashboard route in the
dashboard page, every action input in the CI/CD inputs table, every new
Technical Name in the STE100 list. Fix drift in place; no follow-ups.

**Verify:** the full `just check` chain.

---

## Per-release checklist (apply to every version)

1. Implement the version's items (code + tests).
2. Update `docs/`, Ada docstrings, and `docs/changelogs/adacovex-<version>.md`.
3. Regenerate `src/adacovex_version_info.ads` (`just build`), `sbom.json`
   (`just sbom`), and `src/adacovex-docs_template.ads` (`just book`).
4. Run `just check`, then `just test`, `just prove`, `just test-count`,
   `just proof-status`.
5. Update AGENTS.md if the source layout, CLI flags, SBOM behaviour, or
   dashboard features drifted.
6. Suggest a Conventional Commit message (British English, <=72 characters,
   scope from `docs/contributing/commits.md`); do not commit unless asked.
7. State which version the change belongs to and whether it needs a MAJOR
   version (none of these items break the CLI contract, so no MAJOR).

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
