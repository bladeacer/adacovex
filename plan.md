# adacovex release plan: v1.68.0 - v1.70.0

Current version: `1.67.0`. These items ship across **three minor bumps**:
`v1.68.0`, `v1.69.0`, `v1.70.0`.

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
| v1.68.0 | done | Output defaults & time | 1 (coverage default), 2 (UTC timestamps + opt-in + tests), bulk of 9 (front-load docstrings) |
| v1.69.0 | planned | Diagnostics & help UX | 3 (proof-diagnostic dedup + ada-crdt findings), 4 (contextual help + e2e), remainder of 9 |
| v1.70.0 | planned | SBOM robustness + debt | 5 (sbom false positives), 6 (syft comparison), 7 (sibling-binary length check), 8 (tech debt), final 9 touch-ups |

Every change also updates, in the same change: `docs/`, Ada docstrings feeding
`docs/api-docs`, `docs/changelogs/adacovex-<version>.md`, AGENTS.md source tree
(if source layout changed), and the `just check` gates
(`docs-check`, `action-parity-check`, `docs-coverage-check`,
`surface-parity-check`, `version-consistency-check`, `doc-links`, `link-check`,
`book-links-check`, `python3 tools/gen-docs.py --check`, then `just book`).
After `just test` and `just prove`, run `just test-count` and `just
proof-status`.

---

- [x] Item 1 - Make showing coverage the default when running `adacovex prove` / plain `adacovex` (done in v1.68.0)

**Goal:** A successful `prove` run prints the proof-coverage summary line
(statement / subprogram / VC coverage) by default; `--no-coverage` hides it
for one run, `[prove] coverage = false` in `adacovex.toml` hides it for every
run. Plain `adacovex` (no subcommand) assessing the target should show the
same coverage line when a prove-style assessment ran.

**Current state:** `Prove_Show_Coverage : Boolean := True` exists in
`src/core/adacovex-config.ads:226` and `Prove_Coverage_Explicit` tracks whether
the user passed an explicit flag, but the wiring for plain `adacovex` and the
config-file precedence need verifying. The summary already prints at
`adacovex-prove.adb:2658` / `:2937` behind `Opts.Show_Coverage`.

**Files to touch:**
- `src/core/adacovex-config.ads/.adb` - confirm default + explicit flag +
  config-file (`[prove] coverage = false`) precedence; expose a
  `Coverage` flag on the root options if plain `adacovex` needs it.
- `src/core/adacovex-prove.adb` - `Report_Coverage` call sites and the
  "filtered: N informational notice(s) hidden" line.
- `docs/usage/cli-reference.md`, `docs/usage/cli-reference-flags.md` - document
  `--coverage` / `--no-coverage` and the config key.
- `docs/changelogs/adacovex-1.68.0.md`.

**Tests to add:**
- `src/tests/adacovex_prove_tests.adb`: coverage line present by default,
  absent with `--no-coverage`, present again with `--coverage`.
- `tests/e2e/cli_flags.py`: `--no-coverage` removes the summary line and
  leaves the proof result alone; `--coverage` forces it on.

**Verification:** `just prove`, `just test`, `just cli-e2e`.

---

- [x] Item 2 - Store timestamps as UTC+0 by default; opt-in for local timezone (done in v1.68.0)

**Goal:** Timestamps default to `UTC+00:00`. The operator's wall-clock /
current timezone is only used when the user explicitly opts in (e.g. an
explicit `--tz`/`--timezone` value or a new local-time opt-in flag). Today
plain `adacovex` renders the local zone while flagged runs render `UTC+0`,
which is inconsistent.

**Current state:** `Adacovex.Timezones.Default` in
`src/core/adacovex-timezones.adb:474` honours `TZ` / the OS local zone by
default. `Now_Text` renders the resolved zone.

**Files to touch:**
- `src/core/adacovex-timezones.ads/.adb` - add a `Timezone_Mode` (UTC-default
  vs local-opt-in) and a flag; `Default` returns UTC+0 unless opted in.
- `src/core/adacovex-config.ads/.adb` - wire the new flag into `Known_Flags`
  and the CLI parser.
- `src/core/adacovex-prove.adb` / renderers - consume the resolved mode when
  emitting timestamps.
- `docs/usage/cli-reference-options.md` - document the timezone flag.
- `docs/changelogs/adacovex-1.68.0.md`.

**Tests to add:**
- `src/tests/adacovex_tz_ansi_tests.adb` (or a new timezone test category):
  default `Now_Text` renders `UTC+00:00`; explicit local opt-in renders the
  local zone; `--tz=UTC+8` renders `UTC+08:00`.
- `tests/e2e/cli_flags.py`: plain run timestamp is `UTC+00:00`; flagged run
  is `UTC+00:00` unless a local opt-in/tz is passed.

**Decision:** reuse `--tz=local` for the local-timezone opt-in (default is
UTC+00:00). Emphasize good documentation for timezone-setting features and
group them under one docs page.

**Verification:** `just test`, `just tz-ansi` if a category exists, `just cli-e2e`.

---

- [ ] Item 3 - `just run-ada-crdt`: fix Ada_CRDT findings + proof-diagnostic dedup (planned for v1.69.0)

**Goal:** The sibling-binary run over `../Ada_CRDT` surfaces (a) real issues
in Ada_CRDT source to fix there, and (b) adacovex proof-diagnostic noise to
remove here - chiefly repeated warnings/errors (e.g. the same
`"Ctx" is set by "Final" but not used after the call` warning printed once per
inlined call site, and `statement has no effect` repeated for `crdt-security-lms.adb:155`).

**Current state:** `prove_diagnostics.py` generates broken/fixed SPARK fixtures
and checks the diagnostics block (prover identity, source location, check kind,
fix hint). The replay shows one finding per unique diagnostic; the gnatprove
stream itself may repeat. adacovex's filtered footer ("3 informational notice(s)
hidden") hides benign info but the warnings still repeat.

**Files to touch:**
- `src/core/adacovex-prove.adb` - replay/dedup of gnatprove diagnostics so a
  unique (file, line, check-kind, message) finding prints once.
- `tests/e2e/prove_diagnostics.py` - add a dedup check (repeated warning
  appears once in the diagnostics block).
- `../Ada_CRDT` - fix the real findings (`Ctx` unused after `Final`,
  statement-no-effect, unreachable `return False`) - that repo is out of
  scope for this tree's code changes but its findings inform item 8 (tech
  debt).
- `docs/changelogs/adacovex-1.69.0.md`.

**Tests to add:**
- `tests/e2e/prove_diagnostics.py`: a fixture whose gnatprove stream repeats
  the same warning N times; assert adacovex's diagnostics block reports it
  once with the right location/hint.
- Confirm `just run-ada-crdt` no longer shows duplicated warnings.

**Verification:** `just run-ada-crdt`, `just prove-e2e`.

---

- [ ] Item 4 - Contextual/flag-specific help looks like main `--help` (planned for v1.69.0)

**Goal:** `adacovex prove help`, `adacovex help serve`, `adacovex --serve help`,
etc. should render with the same structure, framing, and density as the main
`--help` usage block (version line, `Usage:` fence, `Options:` list, footer)
so the program feels like a cohesive unix tool. Today the topic sections are
free-form `Print_Section` blocks without the usage header.

**Current state:** `Print_Usage` at `adacovex-config.adb:2974`; topic help at
`Print_Topic_Help` (`:3415`) with hand-written sections for `serve` and a few
others; `Normalize_Topic` at `:3392`.

**Files to touch:**
- `src/core/adacovex-config.ads/.adb` - refactor help rendering so every
  topic section is framed like `--help` (version + `Usage:` fence +
  `Options:`-style flag list + footer); cover `prove`, `serve`, `standard`,
  `sbom`, `status`, `man`, `tldr`, `init`, `complexity`, `spark-coverage`,
  `completion`, `coverage`, `tz`.
- `tests/e2e/cli_flags.py` - e2e test: `adacovex prove help` output matches the
  `--help` frame (version line, `Usage:` fence containing `adacovex prove`,
  `Options:` with prove flags `-j`/`-l`/`--args`/`--suppress-warnings`, footer).
- `docs/changelogs/adacovex-1.69.0.md`.

**Tests to add:**
- `tests/e2e/cli_flags.py`: help-for-prove frame test; help-for-serve frame
  test; `--serve help` equivalence with `help serve`.

**Decision:** `adacovex --help` and `adacovex help` (no topic) must remain
byte-identical. So `adacovex prove help` and `adacovex prove --help` must
match the main `--help` frame. Other flags' specific help stdout output must
ensure structural similarity with the main `--help` (unix/CLI style): version
line, `Usage:` fence, `Options:` list, footer.

**Verification:** `just cli-e2e`, `just surface-parity-check`.

---

- [ ] Item 5 - SBOM false positives on C projects (yams): robust dep detection (planned for v1.70.0)

**Goal:** `adacovex sbom` on a C project like `../yams` must not emit false
positives (e.g. `cargo` listed as a dependency, `go` appearing, "cargo depends
on go"). The smell is fragile regex-based dependency detection in the manifest
parser.

**Current state:** `src/parsers/adacovex-parsers-manifest-*.adb` detect build
files and scan for curated tool names as whole words (`note_if_tool`,
`note_referenced_tools`, `note_tool` at `adacovex-manifest-note_*.adb`).
Cargo/go detection likely comes from scanning `Cargo.toml`/`go.mod` or from
heuristic name matching that conflates tool mentions with dependencies.

**Files to touch:**
- `src/parsers/adacovex-parsers-manifest-scan_file.adb` - audit the regex/whole-word
  scanning for tool names vs. dependency declarations.
- `src/parsers/adacovex-parsers-manifest-read_manifest_deps.adb`,
  `register_root_*_deps.adb` (cargo/npm/go/python) - ensure a tool mention in
  a build file does not register as a dependency edge.
- `src/parsers/adacovex-parsers-manifest-classify_scope.adb` - scope
  classification must not create spurious cargo->go edges.
- `src/renderers/adacovex-renderers-sbom.adb/.ads` - output filtering if needed.
- `docs/usage/sbom.md`, `docs/usage/sbom-resolution.md`.
- `docs/changelogs/adacovex-1.70.0.md`.

**Tests to add:**
- `src/tests/adacovex_sbom_tests.adb`: run sbom over a C-project fixture
  (package.json-free, no Cargo.toml/go.mod) and assert no `cargo`/`go`
  components and no spurious edges.
- `tests/e2e/cli_flags.py`: pin the SBOM component set of `../yams`.

**Verification:** `just run-ada-crdt` is not relevant; run `adacovex sbom` over
`../yams`; `just test`, `just sbom`.

---

- [ ] Item 6 - Compare our SBOM parser with syft; adopt robustness improvements (planned for v1.70.0)

**Goal:** Benchmark `adacovex sbom` against `https://github.com/anchore/syft`
on the same target(s) (self, yams, Ada_CRDT). Document component/version/licence
coverage differences and ecosystem handling (cargo, go, npm, pypi, composer,
alire, system scope). Implement the robustness gaps worth adopting (lockfile
parsing, indirect-dep handling, scope classification, licence resolution) that
fit the zero-dependency constraint.

**Files to touch:**
- `src/parsers/adacovex-parsers-manifest-*.adb` - targeted robustness fixes
  arising from the comparison (do not rewrite to call syft; stay zero-dep).
- `docs/usage/sbom-resolution.md` - syft comparison findings + adopted gaps.
- `docs/contributing/architecture-dependencies.md` - if the dependency graph
  model changes.
- `docs/changelogs/adacovex-1.70.0.md`.

**Tests to add:**
- `src/tests/adacovex_sbom_tests.adb`: comparison-derived regression fixtures
  (lockfiles, indirect deps, missing licence).
- A docs-only comparison table (no code) in `docs/usage/sbom-resolution.md`.

**Decision:** `syft` is not installed or expected for users. The adacovex SBOM
parser is our own implementation. We may reference syft's source code and
approaches for robustness ideas, with proper attribution, captured in
`docs/usage/sbom-resolution.md`.

**Verification:** `just sbom`, `just test`, manual syft diff on fixtures.

---

- [ ] Item 7 - Sibling-binary bug: `adacovex-prove.adb:2821 length check failed` (planned for v1.70.0)

**Goal:** Running adacovex as a sibling binary on `../Ada_CRDT` fails with
`Error: adacovex-prove.adb:2821 length check failed` during the patched-proof
artefact copy.

**Root cause (observed):** `adacovex-prove.adb:2820` declares
`Names : constant array (1 .. 2) of String (1 .. 15) :=
("gnatprove.out    ", "gnatprove.sarif");`. `"gnatprove.out    "` is 17
characters but the component type is `String (1 .. 15)`, raising a length
check at copy time for the patched proof tree (`<target>/obj/adacovex-proof/`).

**Files to touch:**
- `src/core/adacovex-prove.adb` - fix the bounded artefact-name array to fit
  the longest name (or use unbounded strings / a larger bound), preserving the
  "never truncate, report overflow" contract.
- `docs/changelogs/adacovex-1.70.0.md` (bug fix).

**Tests to add:**
- `src/tests/adacovex_prove_runner_tests.adb`: artefact-copy path with
  long/names and a patched proof tree; assert no length check and correct copy.
- Reproduce `just run-ada-crdt` prove success (972 checks, no length check).

**Verification:** `just run-ada-crdt`, `just prove`, `just prove-runner-tests`.

---

- [ ] Item 8 - Address technical debt ASAP (planned for v1.70.0)

**Goal:** Reduce the "many hours/days" of technical debt surfaced by these
items and the ada-crdt run: deduplicated diagnostics, robust manifest parsing,
bounded-string safety, timezone consistency, help framing. Track each debt
item as a sub-task with an owner-ish label and a "done when" criterion; do not
let new debt accumulate (SPARK_Mode Off stays limited to
`Types.Implementation` and `Complexity`; every new executable statement carries
contracts; 0 unproved / 0 justified VCs).

**Files to touch:**
- Debt register in `docs/contributing/` (or a `PLAN.md`/`TECHDEBT.md` note) -
  enumerate items 1-7 plus any found during `just run-ada-crdt`.
- Source files per item above.

**Verification:** `just spark-off-check`, `just prove`, `just test-count`,
`just proof-status`.

---

- [ ] Item 9 - API docstrings: add missing descriptions (e.g. `Adacovex_Man_Tests`) (front-loaded across v1.68-v1.70)

**Goal:** Generated API pages such as `Adacovex_Man_Tests` / `procedure Run`
have empty `@param`/`@return`/`description` fields. Add meaningful docstrings
to public subprograms/types across `src/` so `just doc` / `gnatdoc` produces
complete `docs/api-docs/`. Front-load docstring work across v1.68-v1.70
(concentrated early); enforce a full non-empty documentation table unless the
corresponding value in the docstrings themselves (as rendered in generated md
files) is empty.

**Files to touch:**
- All `src/**/*.ads` public specs with sparse docstrings; start with
  `src/tests/adacovex-test_support.ads` (`Run`), `src/core/adacovex-core.ads`,
  `src/renderers/adacovex-renderers-man.ads`, then per-package as each
  version's source changes land.
- `docs/api-docs/` regenerated by `just doc` (do not hand-edit generated md).
- `docs/changelogs/adacovex-*.md` per release.

**Tests to add:**
- `just docs-coverage-check` must pass (every public API surface documented).
- `just doc` regenerates without new empty-description warnings.

**Verification:** `just doc`, `just docs-coverage-check`, `just check`.

---

## Per-release checklist (apply to v1.68.0, v1.69.0, v1.70.0)

For each version, in the same change:

1. Implement the version's items (code + tests).
2. Update `docs/` (user-facing + API cross-links), `docs/changelogs/adacovex-<version>.md`.
3. Regenerate `src/adacovex_version_info.ads` (`just build`), `sbom.json` (`just sbom`),
   `src/adacovex-docs_template.ads` (`just book` if docs changed).
4. Run `just check` (full gate chain), then `just test`, `just prove`,
   `just test-count`, `just proof-status`.
5. Update AGENTS.md if source layout / CLI flags / SBOM behaviour / dashboard
   features drifted.
6. Suggest a Conventional Commit message (`<type>(<scope>): <description>`,
   British English, <=72 chars, scope from `docs/contributing/commits.md`);
   do not commit unless asked.
7. State which version in `plan.md` the change belongs to and whether it needs
   a MAJOR version (none of these items break the CLI contract, so no MAJOR
   is expected).

## Decisions (resolved)

1. Item 2: reuse `--tz=local` for the local-timezone opt-in (default is UTC+00:00). Timezone docs grouped under the options page.
2. Item 4: `adacovex --help` and `adacovex help` remain byte-identical; `prove help` / `prove --help` match the main `--help` frame; other flag help output structurally similar (unix/CLI style).
3. Item 6: `syft` is not installed or expected for users. Reference syft source with attribution in `docs/usage/sbom-resolution.md`.
4. Item 9: docstring work front-loaded across v1.68-v1.70; enforce a full non-empty documentation table unless the docstring value itself is empty.

All questions resolved - implementing starting with v1.68.0.
