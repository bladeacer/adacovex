# CI fix backlog (v1.62.0 release workflow)

Scratch backlog written 2026-10-18. The v1.62.0 tag release (`a28db45`)
failed its `platform-build` matrix in `.github/workflows/release.yml`
(`os: [macos-latest, windows-latest]`). This file records what was found
and what is left, so the fix can resume another day.

## Finding 1: macOS link failure (runner image drift, not a code regression)

- Job: `Cross-platform build + tests (macos-latest)` on image
  `macos-26-arm64` (image version 20261013.0424.1).
- `alr build` compiled every unit, then both links failed
  (`gprbuild` exit 4):
  - `ld: warning: ignoring file /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib/libSystem.tbd, malformed file`
  - `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib/libSystem.tbd:4:20: error: unknown architecture arm64e.x1-macos, arm64e.x1-maccatalyst ]`
  - Then hundreds of `Undefined symbols for architecture arm64`
    (`__Unwind_Backtrace`, `_accept`, `_write`, ...) -- every symbol in
    libSystem, because the CommandLineTools `libSystem.tbd` stub was
    ignored by the linker.
- Toolchain itself was fine: alr 2.1.1, `gnat_native=16.1.0`,
  `gprbuild=26.0.1`, GNAT 16.1.0 verified by the setup action.
- Interpretation: the macOS 26 runner image ships a newer
  CommandLineTools SDK whose `.tbd` stub format (with `arm64e.x1-*`
  architecture entries) the linker path used by GNAT 16.1.0 cannot
  parse. `macos-latest` now resolves to macOS 26, so this is environment
  drift; earlier releases passed when `macos-latest` was an older image.

### Candidate fixes (pick one, verify on a tag or workflow_dispatch run)

1. Pin the matrix label to `macos-15` (or `macos-14`) instead of
   `macos-latest`, so the CLT SDK stays parseable by the pinned GNAT
   16.1.0 toolchain.
2. Add a step that selects a full Xcode toolchain
   (`xcode-select -s /Applications/Xcode_<ver>.app`) so the link uses the
   Xcode SDK rather than the CommandLineTools SDK.
3. Check the Alire/GNAT issue trackers for a known fix (newer
   `gnat_native` or an `alr` toolchain switch) before pinning.

### Docs to touch when the runner label changes

- `docs/usage/platforms.md` and `docs/usage/ci-cd-workflows.md` may name
  the macOS runner; grep for `macos-latest` and update if a pin is
  adopted. The `release.yml` comment points at
  `docs/usage/platforms.md` as the evidence page for this matrix.

## Finding 2: Windows native-suite failures (4 tests, all POSIX-assuming tests)

Run on `windows-latest`: `Passed: 2015  Failed: 4` (categories `Man page
renderer` 3/30 and `CPU and jobs` 1/24). The implementation is
platform-correct; the *tests* hard-code POSIX assumptions.

1. `manpath match finds a later entry`
2. `manpath match ignores a trailing slash`
3. `home-owned manpath entry is selected`

   Cause: the fixtures join entries with a literal `:`
   (`"/usr/share/man:/usr/local/share/man"`), but
   `Manpath_Contains` / `Manpath_User_Entry` split on
   `GNAT.OS_Lib.Path_Separator`, which is `;` on Windows
   (`Is_Entry_Sep` in `src/renderers/adacovex-renderers-man.adb`).
   On Windows the fixture is one giant entry, so every `:`-joined match
   fails (and the two "reports empty" / "rejects a prefix" checks pass
   only by accident). Note `Is_Dir_Sep` already accepts both `/` and
   `\`, so the abstract `/usr/...` entry strings remain usable on
   Windows once the join character is right.

   Fix: build the fixtures with the host separator in
   `src/tests/adacovex_man_tests.adb` (e.g. a local
   `Sep : constant String := GNAT.OS_Lib.Path_Separator;` and join with
   it), keeping one test body that exercises both platforms.

4. `the spawned-command shell is sh`

   Cause: `src/tests/adacovex_cpus_tests.adb` asserts
   `Get_Shell_Command = "sh"` unconditionally, but the implementation
   returns `"cmd"` on Windows. The test package already has platform
   expectation helpers (`Expected_Temp_Dir`, `Expected_In_CI`); add an
   `Expected_Shell` the same way (derive from
   `GNAT.OS_Lib.Directory_Separator = '\'`, mirroring `Is_Windows`).

Note: these fixes cannot be executed on the Linux dev machine; the
verification is `just test` (Linux must stay green) plus reasoning about
the Windows branch, then a CI rerun.

## Deferred / discarded work from the 1.63.0 P1 session

The earlier session implemented the P1 build-phase bench scenarios
(`tools/bench.py`, `tools/tests.py`, `tools/gen-docs.py` caching) but
also staged version-specific perf numbers into docs, which the user
asked to omit and defer. Current worktree state (uncommitted):

- Staged and to KEEP (implementation):
  - `tools/bench.py` (new build-phase scenarios: alire fetch, sphinx
    fresh/incremental, compile, link, cold-tree build)
  - `tools/tests.py` (search-index + cold-tree/fingerprint tests)
  - `tools/gen-docs.py` (stamped incremental Sphinx rebuild)
- Staged and to DISCARD (version-specific docs, re-add when 1.63.0
  lands): `docs/contributing/perf/benchmarks-timings.md`,
  `docs/contributing/perf/benchmarks.md`,
  `docs/contributing/perf/index.md`,
  `docs/contributing/developer-guide.md`
- Staged and to TRIM: `AGENTS.md` -- keep the new bench scenario list,
  remove the version-specific timings (e.g. "36 s on the dev machine").
- Generated: `src/adacovex-docs_template.ads` -- regenerate with
  `just book` after the docs revert.
- `alire/settings.toml` / `src/adacovex_version_info.ads` churn is a
  normal `alr build` side effect; leave as-is.

## Remaining task list (resume here)

1. Apply the Windows test fixes (Finding 2) and run `just test` +
   `just prove`.
2. Apply the macOS runner fix (Finding 1), update any runner-name docs,
   then re-run the release workflow (re-tag or re-run the failed jobs).
3. Revert the staged perf-docs edits listed above; trim the AGENTS.md
   timings; regenerate the docs bundle (`just book`).
4. Add a `plan.md` item under v1.63.0 deferring the prove-timing phase
   collation and the perf-docs update until the rest of 1.63.0 (P2/P3)
   is implemented -- seeded by `perf-analysis-1.62.0.md` and the P1
   bench work.
5. Write the v1.63.0 changelog entry for the kept tooling changes
   (`tools/bench.py` scenarios, `tools/gen-docs.py` caching) in the
   repo changelog format.
6. Run `just check` gates before committing.
