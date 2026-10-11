# Adacovex platform and numeric-type plan

**Current work queue:** see "Work to be done before the v1.61.0 release"
below -- that section is the live plan. The rest of this file records the
completed v1.59.0/v1.60.0 platform effort and its verification notes.

## Status

Implemented in the working tree. The Windows portability fixes, the
`Long_Long_Integer` time-stamp contract, the path abstraction, the task-runner
migration, and the supporting docs and tests are in place. The remaining step
is to run the tree's sync and gate commands on a machine with the GNAT
toolchain and Python 3, because this host has no `bash` and cannot run them
(see "Verification" below).

## What changed

- **`Adacovex.Paths`** (`src/core/adacovex-paths.ads`/`.adb`) is the single
  place for a platform path decision: `Is_Separator` (both `/` and `\`),
  `Is_Absolute` (POSIX root, Windows drive letter, UNC root), `Join`,
  `Strip_Trailing_Separators`, `Home_Directory` (HOME, then USERPROFILE, then
  the temp directory), and `Expand_User` (`~` and `~/rest`, also `~\rest`).
- **`adacovex-config.adb`** resolves a target with `Paths.Is_Absolute` instead
  of a leading-`/` test, and `Expand_User_Path` delegates to
  `Paths.Expand_User`.
- **`adacovex-dir_cache.adb`** uses `Paths.Is_Absolute` in `Abs_Key`, so a
  Windows absolute path is no longer re-joined with the working directory.
- **`adacovex-cache.adb`** derives the cache, stamp, probe, and meta roots
  from `Paths.Home_Directory`, strips either separator in `Set_Cache_Dir`,
  and carries the result of every `OS_Lib.To_C` call as an explicit
  `Long_Long_Integer`.
- **`adacovex_main.adb`** normalises a path with both separators, keeps a
  drive or UNC root, and emits a canonical `/` form.
- **`parse_gpr.adb`** binds the `.gpr`-stripped name to a constant, so a
  `with "x.gpr"` clause no longer raises `Constraint_Error`.
- **`tools/build.py`** reserves a larger Windows main-thread stack
  (`-Wl,--stack,33554432`) and falls back to a copy when a symlink is refused.
- **`tools/tasks.py`** and **`justfile`** are the new task runner; the
  `Makefile` is a thin shim that delegates to the same Python tasks.
- **`Adacovex_Paths_Tests`** (25 checks) pins the separator, absolute, join,
  strip, and home rules.

## Verification

Run these on a machine with `gprbuild`, `gnatprove`, and Python 3 (the
generated files and the metrics are refreshed by them and are not hand-written
artifacts):

```
just test
just test-count
just description
just agents-tree
just book
just doc
just prove
just check
```

`just release` and its version bump stay a separate release action, as before.

## Notes

- The tree has no vendored components; a vendored-code regression is only
  measurable on a fixture with the same shape.
- `just check` resolves `gnatprove` for you, so no manual prover installation
  is required.

## Work to be done before the v1.61.0 release

Plan only -- no code has been written for these items yet. Recorded
2026-10-11. The host this plan was written on **is** the EndeavourOS
machine (EndeavourOS, x86_64, 12 logical cores), so the perf-timing work
below happens here rather than being deferred again.

### 0. CI run 38098692760 (job 114350452288): PASSED

The linked job is the `CI summary` job of run 38098692760 ("docs: record
that gnatformat has no Windows binary", commit `767c4c9` on `main`).
GitHub reports conclusion `success` for the job and `success` for the
whole run; all 10 jobs passed (action/CLI/docs parity, version
consistency, complexity, build + native tests, documentation coverage,
SPARK_Mode Off, self-assessment with all standards, docstring coverage
gate, action run-tests consumer workspace, CI summary). Nothing in that
run needs a fix. (Answer to record: **pass**, not fail.)

### 1. Sync the test-count drift (three gates fail today)

- The tree now carries **1821** passing tests (the SBOM/manifest category
  grew from 304 to 308; the paths category grew with the new checks),
  while 131 files still name 1818. `python3 tools/tests.py` fails in
  `SyncToolCheckModeTests.test_check_mode_writes_nothing`
  (`update-test-count.py --check` reports 1821 against a stale tree), and
  the `test counts in sync` gate fails for the same reason.
- Run `just test-count`, commit its tree-wide output, and verify the
  hand-maintained spots the sync tool does not own: `require-tests` in
  `.github/workflows/ci.yml` and `action.yml`, the counts in
  `AGENTS.md`, and the category table in `CONTRIBUTING.md`.
- `cli-e2e` passes on this machine against the current binary (75/75).
  Its earlier `exit 1` in the reported summary is expected to be the
  stale binary/`require-tests` residue; re-run `just build` then
  `just cli-e2e` after the count sync and investigate only if it still
  fails. On the Windows host, the four known Windows-only `tools-check`
  failures (the `bin/adacovex` shell stub cannot run through
  `CreateProcess`, the bundle symlink needs a privilege Windows
  withholds) stay documented as Windows-only unless a cross-platform fix
  falls out of item 2.

### 2. Fix the `.venv` `sys.prefix` RuntimeWarning cross-platform

- `just check` depends on `docs-venv`, which runs
  `uv pip install --python .venv -r requirements.txt` with the **relative**
  `.venv/bin` (Windows: `.venv/Scripts`) prepended to `PATH` by the
  justfile. A Python 3.13 interpreter started from a relative venv path
  reports `sys.prefix` as the relative `.venv`, so `<frozen site>`
  prints `RuntimeWarning: Unexpected value in sys.prefix, expected
  <absolute>/.venv, got .venv` right after `Audited 3 packages in 22ms`.
- Fix in the justfile (and in any tool that prepends the venv bin to
  `PATH`: `tools/gen-docs.py`, `tools/tasks.py`, `tools/check-book-links.py`
  resolve the same `.venv` shape) by building an **absolute** venv-bin
  path -- `justfile_directory()` joined with the platform venv-bin
  directory (`venv-bin` already switches on `os()` for `bin` vs
  `Scripts`). One fix covers Linux, macOS, and Windows.
- Verify: `just check` on this machine prints no `RuntimeWarning`
  anywhere in the gate output, and the same on the Windows host.

### 3. Clear the three gnatprove `info` messages in `adacovex-config.adb`

- `info: no contextual analysis of "Suggest_Flags" (unconstrained return
  type)` (562:04), `info: analyzing call to "Normalized" in context`
  (567:45), `info: analyzing call to "Edit_Distance" in context`
  (601:18). All three come from gnatprove inlining `Suggest_Flags` at
  its single call site (2035) and being unable to analyse the call
  contextually because the function returns an unconstrained `String`.
- Preferred fix: give `Suggest_Flags` a constrained return type (the
  body already builds a bounded `Buf`/`Len` pair, so return a bounded
  record and let the caller slice), which lets gnatprove analyse the
  call in context and drops all three messages. Alternative: keep the
  unconstrained return and restructure so the calls are not inlined in
  context. Keep the Platinum discipline: 0 unproved, 0 justified, no
  new `SPARK_Mode (Off)`, and no new user assertions that are not
  proved. Re-run `just prove` and update the proof ledger if the VC
  count moves.

### 4. Improve CI caching (proof, self assessment, and the other workflows)

Current state, read from the workflows:

- `alire-project/setup-alire@latest` with `cache: true` caches the
  **toolchain** only, and only where the workflow calls setup-alire
  directly (complexity gate, docstring coverage gate, pr-check, the
  release macOS/Windows matrix).
- The composite action has `cache` and `result-cache` inputs (the
  result cache is restored/saved with `actions/cache/restore@v5` and
  `actions/cache/save@v5`), but **no `ci.yml` job passes
  `result-cache: true`**, so every run re-proves and re-assesses cold.
- The gnatprove session store (`obj/gnatprove/`) is never cached in any
  workflow, so a self-assessment run pays the full solver cost every
  time even when the proof-relevant sources are unchanged.
- The docs encode cache (`obj/adacovex-docs-encode/`) and the uv/pip
  wheel cache for `requirements.txt` are likewise cold every run.

Plan:

1. Pass `cache: true` and `result-cache: true` to `uses: ./` in the
   `self-assessment`, `adacovex-tests`, and the run-tests consumer job
   (the result-cache entries are content-addressed SHA-256 hashes, so a
   stale restore is safe by construction -- the action's own comments
   already document this).
2. Add an `actions/cache` step for the gnatprove session store
   (`obj/gnatprove/`) in the self-assessment job, keyed on a hash of the
   proof-relevant sources (reuse the proof-input hash rule: exclude the
   generated bundle specs `adacovex-docs_template.ads` and
   `adacovex-dashboard_template.ads`, which have no proof surface).
3. Add the uv/pip cache for `requirements.txt` (the docs venv) and the
   Sphinx encode cache (`obj/adacovex-docs-encode/`, keyed on the docs
   sources) to the jobs that build the manual.
4. Apply the same pattern to `pr-check.yml` and `release.yml`
   (macOS/Windows `platform-build` matrix).
5. Measure before/after wall times for the self-assessment and build
   jobs, record them in `docs/usage/ci-cd.md` (and the perf pages if
   they are notable), and state in the docs that a restored cache can
   never mask a regression (content-addressed keys only).
- Guard against a false pass: no gate may trust a cached summary whose
  Total row reports unproved VCs -- the prove result cache already
  drops such a blob; the session-store cache must not bypass that rule.

### 5. Run the perf timing checks on this EndeavourOS machine

Supersedes the "Deferred to the EndeavourOS machine" section below --
this host is that machine, and **1.61.0 joins the fold-in**:

1. Check out this tree and run `just prove` and `just bench` on the
   release profile (gnatprove 16.1.0, the same logical-core and job
   settings the page records), with `/proc/loadavg` recorded beside each
   figure.
2. Re-measure the warm `newfstatat` count with strace for the current
   tree.
3. Fold 1.59.0, 1.60.0, and 1.61.0 into the open phase: rename the phase
   range `1.57.0-1.58.0` to `1.57.0-1.61.0`, keep 1.58.0 as the
   representative unless the new figures justify a different one (state
   the reason in the reading notes), and add the fold-in bullet. Retire
   the oldest of the three closed phases the page keeps, moving any
   figure-explaining note into "Across every phase" first.
4. Update the AGENTS.md phase-list sentence ("so far 1.45.0-1.47.0,
   1.48.0-1.54.0, 1.55.0-1.56.0, 1.57.0-1.58.0") to the new open-phase
   range.
5. Run `just check` on this machine with sphinx installed, so the
   committed offline-manual spec is regenerated if `docs/` drifted.

### 6. Version bump to v1.61.0 and the changelog

1. `just bump-version VERSION=1.61.0` (both manifests plus the generated
   `src/adacovex_version_info.ads`), then build so `bin/adacovex
   --version` and the committed `sbom.json` agree (the
   `version-consistency` gate spans all of them).
2. Write `docs/changelogs/adacovex-1.61.0.md` in the canonical format
   (`### C#:` / `### H#:` under `## Changes` / `## Fixes`, plus
   `## Test Suite`, `## Proof Results`, `## Traceability`), covering
   everything since 1.60.0:
   - cross-platform hardening (`Adacovex.Paths`, the
     `Long_Long_Integer` time-stamp contract, separator-aware path
     normalisation, the `parse_gpr` `Constraint_Error` fix);
   - the justfile/Makefile task-runner migration to `tools/tasks.py`
     and the `just check` preflight redesign;
   - the Windows build fixes (larger main-thread stack, symlink
     fallback) and the `.gitattributes` LF policy;
   - the test-count sync, the `.venv` RuntimeWarning fix, and the
     gnatprove `info` cleanups (items 1-3);
   - the CI caching improvements (item 4);
   - the prove-timing phase fold-in measured on this machine (item 5).
3. Update `alire/long-description.txt` if the proof surface changed, and
   re-run `just description`.

### Order of work and exit criteria

Order: 1 -> 2 -> 3 -> 4 -> 5 -> 6, then `just release` as the separate
release action. Count sync comes first because several gates read the
counts; the bump comes last because the version-consistency gate spans
the manifests, the generated spec, the binary, and `sbom.json`.

v1.61.0 ships when:

- `just check` reports 28/28 gates PASS on this machine (today: 25 pass,
  3 fail -- tools unit tests, CLI e2e, test counts in sync -- plus the
  RuntimeWarning noise);
- `just prove` is Platinum with 0 unproved and 0 justified, and
  `adacovex-config.adb` emits no `info` messages;
- `docs/contributing/perf/prove-timing.md` carries the `1.57.0-1.61.0`
  phase with figures measured on this machine;
- the CI self-assessment is green with the new caches and measurably
  faster than run 38098692760's 3m 16s;
- version 1.61.0 is consistent across every source and the changelog is
  filed.

## Deferred to the EndeavourOS machine (v1.59.0 and v1.60.0 proof timing)

**Superseded by "Work to be done before the v1.61.0 release" above: the
current host is the EndeavourOS machine, and 1.61.0 joins the fold-in.**
The section is kept for its measurement rules.

The `docs/contributing/perf/prove-timing.md` phase table still names
`1.57.0-1.58.0` as the open phase. 1.59.0 and 1.60.0 change no measurement
methodology, so they fold into that phase, but the fold-in and any re-measured
`make prove` / `make bench` figures must be taken on the EndeavourOS machine,
where the figures are comparable with the Linux columns. This Windows host
cannot produce a comparable wall, so the table is left as-is for now.

When the EndeavourOS machine is available:

1. Check out this tree and run `just prove` and `just bench` on the release
   profile (gnatprove 16.1.0, the same logical-core and job settings the page
   records), with `/proc/loadavg` recorded beside each figure.
2. Re-measure the warm `newfstatat` count with strace for the current tree.
3. Fold 1.59.0 and 1.60.0 into the open phase: rename the phase range to
   `1.57.0-1.60.0`, keep 1.58.0 as the representative unless the new figures
   justify a different representative, and add the fold-in bullet to the
   reading notes. State the reason in the reading notes if the representative
   changes.
4. Update the AGENTS.md phase-list sentence ("so far 1.45.0-1.47.0,
   1.48.0-1.54.0, 1.55.0-1.56.0, 1.57.0-1.58.0") to the new open-phase range.
5. Run `just check` on that machine to re-verify the whole gate with sphinx
   installed, so the committed offline-manual spec is regenerated.

### Windows host: what `just check` cannot do here

`just check` is verified on Linux, and the Windows host cannot run every gate:

- `fmt` fails because `gnatformat_bin` has no Windows binary in the Alire
  index (`missing:unavailable`). The EndeavourOS machine resolves it.
- `ascii-check` fails on this checkout because `core.autocrlf=true` rewrote
  the tree to CRLF and the gate rejects a carriage return. A repository
  `.gitattributes` (`* text=auto eol=lf`) now prevents that on a fresh
  checkout; this working tree needs a re-checkout or `git add --renormalize`
  to become LF.
- `tools-check` has four Windows-only failures: a shell-script `bin/adacovex`
  stub cannot run through `CreateProcess`, and a bundle symlink needs a
  privilege Windows withholds. Both pass on Linux.

The gates that need the Linux toolchain and pass there are fmt, ascii-check,
and the two noted tools-check cases. Everything else was run individually on
this host and passes once the docs venv is present.
