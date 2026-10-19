# adacovex 1.63.0

Date: _2026-10-19_

Version bumped 1.62.0 -> 1.63.0.

## Changes

### C1: Windows test parity

Fixed false failures in the native test suite on Windows hosts by aligning
man path and shell tests with the host separator. The `Manpath_Contains` and
`Manpath_User_Entry` functions now correctly handle POSIX-style `:` separators
in test fixtures, and the shell command test derives its expected value from
the host's `Directory_Separator` rather than hardcoding `"sh"`.

### C2: macOS runner pin

Pinned the macOS runner label from `macos-latest` to `macos-15` in the
release workflow to avoid linker failures caused by the macOS 26 runner
image's newer CommandLineTools SDK whose `.tbd` stub format contains
`arm64e.x1-*` architecture entries that GNAT 16.1.0 cannot parse. Earlier
releases passed when `macos-latest` resolved to an older image.

### C3: The pre-build steps run concurrently and the cold phases are recorded

The five steps `just build` runs before the compile -- the version spec, the
CSS 4px gate, the dashboard template, the bundled offline manual, and the tldr
page -- are independent: each reads a different input and writes a different
output. `tools/build.py` now starts all five at once and collects every exit
code before the compile, so the build pays their maximum instead of their sum.
The paired ten-run sample reads 609 ms against 732 ms for the serial recipe on
a no-op build (-16.8 percent), and the five steps cost 463 ms in series against
295 ms as the bundle at load 2.7-2.8 (168 ms, 36 percent, of overlap).

`just bench` gained a build-phase breakdown. It times each step on its own and
then the parallel bundle, reads the step list from `tools/build.py` so the bench
cannot measure a phase the build does not run, and prints the overlap as a
figure. The cold-build and cold-prove phases are recorded with their verdicts
in [Pipeline and prove timings](../contributing/perf/benchmarks-timings.md): the
compile is gprbuild's own parallel work, the workspace sync fetches nothing on a
synced tree, the docs phase is a fingerprint hit, and the solver dominates the
cold prove row.

### C4: The directory memo packs its slots and memoises the busy directories

The warm pipeline spent 14 597 `newfstatat` calls, and 86 of the 191 memo
lookups were real enumerations. Two causes: the memo key was a 256-byte path
image per slot, and the 64-entry cap rejected the two densest scanned
directories in the self tree (`src/parsers`, 78 entries, and `docs/api-docs`,
84), so every walker re-enumerated them. The entry list also carried a 32-byte
name field behind a 64-byte name bound, where a 33-64 character name failed the
whole directory read with `OK = False` -- correct, because the caller fell back
to direct enumeration, but silent.

The memo now stores a packed 66-byte entry (a 64-byte name, a one-byte length,
a one-byte kind), keeps the slot metadata in its first cache lines with the
entry array after it, caps a key at 128 bytes, and memoises directories up to
128 entries. A lookup walks the same linear-probe path the insert uses, so a
hash collision no longer hides a live snapshot. Paired against the pre-change
binary on the same tree at the same load, warm `newfstatat` falls to 8 142, the
memo reports 131 hits and 60 misses, pipeline warm reads 46.8 ms against
51.8 ms (-9.7 percent), and the peak resident set grows 1.7 MiB for the wider
slots.

### C5: Prove-timing phases collated, with 1.61.0 opening the current phase

[Prove timing and the optimisation review](../contributing/perf/prove-timing.md)
now closes the 1.57.0-1.60.0 phase with 1.58.0 as its representative, opens
`1.61.0-` with the 1.61.0 complete metric set, and retires the
1.48.0-1.54.0 phase into the "Across every phase" notes after moving the
doc-bundling methodology and the warm syscall floor there. The 1.62.0 and
1.63.0 figures are recorded beside the open column with their loads, never
picked row by row into it. [Performance](../contributing/perf/index.md) names
the same phase list.

## Fixes

### H1: An installed package's own subpackages and source trees are no longer components

The vendored walk descended two levels and componentised every
directory it reached, so one installed package reported its bundled
`v4`, `locales`, `src`, `lib`, and `dist` directories as five separate
dependencies of the project that uses it.

A level-2 directory now becomes a component only when it carries its
own ecosystem manifest and its parent carries none. Such a parent is a
container -- an npm scope, a composer vendor name, or a Go import-path
host -- and the packages below it are real dependencies. Anything else
at that depth belongs to the package above it and stays out of the
graph.

### H2: The tools test suite runs again

Commit `7a5a283` replaced `tools/tests.py` with a 141-line tldr scratch
script, so `just tools-check` exited 0 while running none of the suite's 178
tests -- the gate looked green and checked nothing. The file is restored to
the full multi-class suite, and the eight requirements-sync checks join it,
so `just tools-check` runs its whole suite again (195 tests as this release
ships).

## Test Suite

2024 tests across 29 categories, up from 2017. Forty earlier checks in
this release cover the structural readers, the package-root rule, and the
root npm and Go declarations. Fifteen more pin adacovex as a
dependency in both directions, and the new `Install method` category
holds 23 checks for the classifier, the scope rule, and the filesystem
walk behind them. The `Server routing` category grows to 180 checks: the
two new routes and their near misses, the `Route_Path` round trip over
every route kind, the protected counter store, and the `/api/info`
payload.

The `Dir cache` category grows to 29 checks: the fitted long name that
used to fail the read whole (four checks, one of which proves the
directory is still memoised), and the 100-entry directory that the old
cap rejected (three checks, including the memo hit).

The new `tldr installer` category holds 48 checks: client classification,
the `--show-paths` parse with its annotation, the per-client path rules, the
`uname` mapping for Linux, macOS, the BSDs, Android, SunOS, and the Windows
shells, and the install and read-back round trip in a temporary tree. The
`Man page renderer` category grows to 30 checks: the man path split and the
home-owned entry rule, the default root, and the indexer contract. The
`VCS support` category grows to 37 checks: both shell families pin their
quoting, their change-directory prefix, and their discard device, so the
Windows command shape is asserted on a POSIX host and the POSIX shape on a
Windows host. `just test` runs the native suite, and `just cli-e2e` runs 87
end-to-end checks, including two new component-set shapes (a pnpm workspace
and a Go module), three checks against the live `/health` and `/api/info`
endpoints, and seven that install the page into a fake tealdeer client and a
fake base client and compare it byte for byte. `just tools-check` runs the
195-test tools suite (restored in H2, plus the eight requirements-sync
checks).

## Proof Results

**Platinum**, 0 unproved, 0 justified, **1054 of 1054 VCs across 75
analysed units** under gnatprove 16.1.0 at `--level=4`. The count grows
by six checks and three units over the shipped 1048: the new
`Adacovex.Install` classifier is proved, from its machine token over the
prefix rules and the scope rule to the index arithmetic behind them, C6's
two route branches and its `Route_Path` mapping add two checks to the
proved `Route` surface, and C9's three host-platform shell helpers
(`Is_Windows` plus the command, flag, and discard-device answers) each
carry their `GNAT.OS_Lib.Directory_Separator` input in a Global aspect,
which SPARK RM 6.1.4(15) requires of a deferred constant. No existing
unit lost a check.

The new parser bodies sit in the manifest package's default-off body, C6's
counter store and `/api/info` renderer in the server package's default-off
surface, and C7's installer in the same file-system surface. None of them
contributes verification conditions.

## Traceability

One new HLR record enters this release: `HLR-TLDR` (client-agnostic tldr
page installation), traced by `LLR-TLDR-01` for the client detection and
`LLR-TLDR-02` for the install and the read-back comparison. The
dependency-graph parsing work extends `HLR-MANIFEST` and `HLR-SBOM`, both
on record for the graph and its output. The new
`Adacovex.Install` package carries `HLR-MANIFEST`: it decides how a
project's reference to adacovex is classified. C9 extends `HLR-DIFF`, whose
requirement is the comparison itself.

The pre-build bundle changes no requirement: it changes the files that gate
the tree. The directory memo is an in-process performance structure behind the
scanning and SBOM walks, so it carries their requirements (`HLR-SCAN`,
`HLR-SBOM`) and adds none. The timing pages record measurements, not
requirements.

The status report adds no requirement: it reports state and never assesses it.
The hermetic suite changes no requirement: it changes the tests that gate
the tree. The requirements single-sourcing and the tools-suite restore
change no requirement either: they change the files that gate the tree.

The packages changed by this release, and the tags on record that cover
them: the manifest parsers and the dependency graph (`HLR-MANIFEST`), the
SBOM they feed (`HLR-SBOM`), the dashboard server routes and its API
(`HLR-SERVER`), the tldr installer (`HLR-TLDR`), the differential-mode VCS
abstraction (`HLR-DIFF`), and the task gates (`HLR-ARCH`).