# Implementation session backlog (2026-11-11)

This file is the handover for the session that closed v1.68.0 and started
v1.69.0. Read it together with `plan.md`: the plan holds the durable release
scope, and this file holds what is finished, what is not, and how to resume.

## What this session set out to do

- Extend the plan to v1.72.0 with the new diagnostics, output, and
  performance work.
- Finish the remaining v1.68.0 work: prove output parity, help formatting,
  colour, CI annotations, and the old-plan close-out.
- Update the changelog and bump the version.
- Fix the disagreement between `make prove` in `../Ada_CRDT` and
  `just run-ada-crdt`.
- Delete `old-plan.md` once its contents were confirmed in `plan.md`.

All of that landed. The tree is at v1.69.0 and `just check` passes 31/31
gates. The plan now runs to v1.75.0; the v1.68.0 and v1.69.0 item text was
removed once their changelogs existed, so `plan.md` is the durable scope and
the changelogs are the record of what shipped.

## Completed in this session

### 1. Coverage line prints once per prove run

A prove-mode run printed the coverage summary twice: once at the end of
`Run_Prove` (fresh run and cache hit) and again in the plain pipeline that
follows it. The pipeline now skips the line in prove mode and keeps it for a
plain `adacovex` assessment over cached artefacts.

Files: `src/adacovex_main.adb`.

### 2. A warm prove cache hit replays the diagnostics it serves

`make prove` (a fresh run) showed the gnatprove warnings, the diagnostics
block, and the `filtered:` / `duplicates:` footers. `just run-ada-crdt` (a
warm hit) showed none of them. The quiet replay is now written to a temp
file, printed, and cached as plain text under `provereplay:<input hash>`.
A warm hit prints the cached text before the coverage line, so both shapes
agree. Verified on Ada_CRDT: six warnings in the fresh run and six in the
warm run.

Residual difference: `just run-ada-crdt` passes `--level 4`; a plain
`make prove` in Ada_CRDT does not. The printed `options:` line and the cache
key therefore differ. This is caller intent, not a tool inconsistency.

Files: `src/core/adacovex-prove.adb`, `src/core/adacovex-prove_output.ads/.adb`.

### 3. Concise prove output is coloured by severity

Errors red, warnings yellow, notices and `-->` locations dim, `Success:`
green, and the coverage / cache / proof / filtered / duplicates lines bold.
The printer reuses `Adacovex.Ansi`, so CI, `NO_COLOR`, and `TERM=dumb` still
produce plain text. Cached replay text is stored without escape codes.

Files: `src/core/adacovex-prove_output.ads/.adb`.

### 4. Unproved findings print GitHub Actions annotations

When `GITHUB_ACTIONS` is set, each distinct finding prints
`::error file=<path>,line=<line>,col=<column>,title=SPARK proof failed::<kind>`.
`Annotation_Line` splits `file:line:column`, omits `col` when absent, and
returns `""` for a malformed location. Unit tests cover the full location, a
location without a column, a malformed location, and a Windows drive-letter
colon.

Files: `src/core/adacovex-prove_output.ads/.adb`,
`src/core/adacovex-prove.ads`, `src/tests/adacovex_prove_runner_tests.adb`.

### 5. Help options are separated by blank lines

`adacovex --help` now puts a blank line before each new option (continuation
lines stay attached), and the `prove` topic lists each flag on its own line
with a short description. `--help` and `help` remain byte-identical.

Files: `src/core/adacovex-config.adb`.

### 6. Diagnostics and output moved into `Adacovex.Prove_Output`

The new code pushed `adacovex-prove.adb` over the cyclomatic limit (596 to
656 against a 600 cap). Rather than weaken the gate, the finding model,
`Collect_Failures`, `Diagnostics_Text`, the annotation shape, the replay
printer, and the replay cache moved into a dedicated unit. The prove spec
re-exports the types and subprograms with subtypes and renames, so callers
and tests are unchanged. `adacovex-prove.adb` is back inside the budget.

Files: `src/core/adacovex-prove_output.ads/.adb`,
`src/core/adacovex-prove.ads/.adb`, `tools/agents-tree.map`, `AGENTS.md`.

### 7. Version, changelog, and plan

- Version bumped 1.68.0 -> 1.69.0 across the manifests, the generated spec,
  the release manifest, and the index entry.
- `docs/changelogs/adacovex-1.69.0.md` records C1-C6, H1 (the duplicate
  coverage line), the test suite, the proof results, and the traceability
  entries.
- `plan.md` now covers v1.68.0-v1.72.0 with the new diagnostics, SBOM,
  debt, and pipeline items.
- `old-plan.md` is deleted. Its open items are carried in `plan.md`.

### 8. Verification

- `just check`: **31/31 gates pass** (warm run, 108 s).
- `just test`: **2175/2175** passing (29 categories).
- `just prove-e2e`: **132 checks** pass.
- `just prove`: 1057 VCs, 1057 proved, 0 unproved, 0 justified, **76 units**,
  Gold. The new output unit adds one unit with no VCs.
- `just run-ada-crdt`: 972 checks, exit 0, cold and warm output agree.
- `just version-consistency-check`: every source agrees on v1.69.0.

## Not done - continue here

Everything below is still open. The plan item numbers match `plan.md`.

### v1.69.0 (closed)

Every v1.69.0 item is closed; the changelog is the record, so this file
starts at v1.70.0.

### v1.70.0

- [ ] **Item 5 - SBOM false positives on C projects (yams).** No `cargo` or
  `go` components or edges for a plain C tree. Add a C fixture to
  `adacovex_sbom_tests.adb` and pin the sibling shape.
- [ ] **Item 6a - syft comparison.** Document component / version / licence
  coverage against syft on self, yams, and Ada_CRDT. Syft stays reference
  material, never a runtime dependency.
- [ ] **Item 8a - technical debt register.** Add `docs/contributing/debt.md`
  (plus its toctree entry) with a "done when" per item.
- [ ] **Item 15a - measure the check pipeline.** Record per-gate and
  per-recipe wall time, warm and cold, with the raw output kept. The 60 s
  budget needs this baseline.
- [ ] Item 9 remainder: docstrings for packages changed by these items.

### v1.71.0

- [ ] **Item 6b - adopt safe SBOM robustness gaps** (lockfiles, indirect
  deps, scope classification, licence resolution).
- [ ] **Item 8b - bounded-string and manifest debt.**
- [ ] **Item 15b - build once and prove once.** No gate recompiles,
  re-bundles, or re-proves what an earlier gate produced.

### v1.72.0

- [ ] **Item 15c - close the 344 s -> 60 s warm-tree gap.** Group the test
  invocations, run independent gates in parallel with a CPU cap, and keep
  the PASS/FAIL/SKIP summary unchanged.
- [ ] **Item 8c - debt paydown close-out.**
- [ ] **Item 9 close-out - API docstring completeness.**

### v1.73.0

- [ ] **Item 20 - one test root and fixture projects.** Move `tests/e2e` to
  `src/tests/e2e`, split it by category, move the inline CI Ada fixtures to
  `src/tests/projects/<name>` with their own manifests, and add the
  test-layout gate.
- [ ] **Item 16 - platform-agnostic suite.** Audit POSIX assumptions, extend
  `Test_Support` with temp-dir and command helpers, add the three-OS CI
  matrix, and add the portability gate. A platform dependency is an explicit
  skip, never a silent pass.

### v1.74.0

- [ ] **Item 18 - cache by resolved location.** Canonicalise the target and
  GPR, key the proof cache on the resolved root, add the 7-day TTL,
  `--cache-expiry`, and `--cache-clear`. Bump the cache schema.
- [ ] **Item 17a - contract-error matrix.** Add broken/fixed fixture pairs
  for the unsupported classes and a doc table that states supported /
  fallback / gap, checked by the diagnostics-coverage gate.

### v1.75.0

- [ ] **Item 17b - Ada_CRDT dogfood.** Fix grouping, location, and solver
  gaps the dogfood exposes, add synthetic fixtures for its findings, and
  document the result against the item 17a matrix.
- [ ] **Item 19 - contextual help audit.** Every topic gets the prove frame:
  usage, aligned options, one example, exit codes, and `See also`.
- [ ] **Final docs, STE, and parity drift pass.**

## Gotchas for the next session

1. **Do not put new I/O helpers in `adacovex-prove.adb`.** It sits just
   under the 600 cyclomatic cap. Add them to `Adacovex.Prove_Output` or a
   sibling unit. Run `just complexity-check` after any change there.
2. **The replay cache is keyed by the proof input hash.** `--force` adds
   `-f` to the options, so a forced run has a different key and does not
   warm a normal run. Delete the `prove-*` / `provereplay-*` entries under
   `<cache>/1.69.0/*/pr/` to force a fresh store.
3. **`tests/e2e/prove_diagnostics.py` sets `NO_COLOR=1`.** The text
   assertions need plain output. Keep that when adding new checks. Item 20
   moves it to `src/tests/e2e/prove/`.
4. **`just test-count` rewrites the description in every historical release
   manifest** (2155 -> 2175 in this session). That is the established
   pipeline behaviour; commit the generated manifests as-is.
5. **`Adacovex.Prove_Output` counts as a proof unit** (76 instead of 75,
   same proof surface). `just proof-status` keeps the ledger and the timing page
   in sync.
6. **`just check` runs `fmt` first.** Re-run the full chain after a source
   edit; a green `complexity-check` alone does not cover the parity gates.

## Resume checklist

1. Read `plan.md` and this file.
2. Run `just build`, `just test`, and `just check` to confirm the tree is
   still green.
3. v1.69.0 is closed. Start v1.70.0 with item 5 (SBOM false positives on C
   projects), then 6a, 8a, and 15a.
4. When a release closes, delete its item text from `plan.md` (the changelog
   is the record) and update the version table. Do not carry closed detail
   forward.
5. Move the completed entries in this file and `plan.md` together; keep the
   changelog for the release that ships them.
