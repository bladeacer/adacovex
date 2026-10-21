# adacovex 1.63.0

Date: _2026-10-19_

Version bumped 1.62.0 -> 1.63.0.

## Changes

### C1: Windows test parity

Fixed the four false failures the `windows-latest` runner reported in the
native test suite; the implementation was platform-correct and the tests
hard-coded POSIX assumptions. Three man-path checks joined their fixture
entries with a literal `:`, but the readers split on
`GNAT.OS_Lib.Path_Separator`, which is `;` on Windows, so each fixture read
as one giant entry and every match failed; the fixtures now join with the
host separator, so one test body exercises both platforms. The fourth check
asserted the spawned-command shell is `"sh"` unconditionally; it now derives
the expectation from the host's `Directory_Separator`, so a Windows host
expects `"cmd"`.

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

Paired against the v1.62.0 release binary, built from the v1.62.0 tag and run
round by round with the v1.63.0 release binary on one box, the same tree costs
13 428 warm `newfstatat` calls under the old binary and 7 924 under the new
one (-41 percent), and the pipeline reads 50.5 ms against 55.8 ms warm and
84.7 ms against 98.2 ms cold. The v1.62.0 tree shows the same shape: 7 195
against 11 129 stat calls, pipeline warm 49.1 ms against 56.7 ms, and prove
warm 62.2 ms against 66.9 ms.

### C5: Prove-timing phases collated, with 1.63.0 representative for the open phase

[Prove timing and the optimisation review](../contributing/perf/prove-timing.md)
now closes the 1.61.0-1.62.0 phase with 1.62.0 as its representative, opens
the `1.63.0-` phase with 1.63.0 as its representative, and keeps the three
most recent closed phases beside the open one. The phase closes because both
the implementation and the measurement methodology moved: the directory memo
was packed again, the five pre-build steps became one concurrent bundle, and
`just bench` gained a per-step build-phase breakdown.

The 1.63.0 complete set is the column: pipeline warm 48.1 ms +/- 5.4 ms and
cold 76.8 ms +/- 3.8 ms, prove warm 62.9 ms +/- 5.9 ms, prove cold
79.4 s +/- 2.7 s, and prove cold clone 80.8 s +/- 2.7 s, all at load
1.87-2.52, on 1054 VCs across 75 analysed units with 0 unproved, with 7 924
warm `newfstatat` and a stripped binary of 6 552 528 bytes.

The prove-cold row cannot separate the two versions, and that is the finding.
Six paired rounds over two sessions read 89.4 s for the v1.62.0 binary
against 83.8 s for the v1.63.0 binary on the 1.63.0 tree, and 85.9 s against
89.2 s on the v1.62.0 tree, so the sign of the difference flips between the
two trees. The same configuration moved by 14 s between the two sessions
(88.2 s against 79.4 s for the same binary and tree), which is larger than
any difference between the versions, so the row stays solver-bound and
load-dominated as in every earlier phase.

The absolute figures sit above the ones earlier sessions recorded, and the
paired run shows that the drift is in the box, not in the code. The v1.62.0
release binary on the v1.62.0 tree reads 56.7 ms in this session against the
41.7 ms the 1.61.0 record took for it. The paired rows are the evidence that
the release did not regress: on one box, one tree, and one session, the
1.63.0 binary reads faster and cuts the warm stat count by 41 percent. The
page says so, and every figure now carries the load it was taken under.

The per-release analysis files at the repository root are removed with this
release. Their figures, with their loads, live in the reading notes of the
prove-timing page, which is the page the phase table points at.
[Performance](../contributing/perf/index.md) names the same phase list.

## Fixes

### H1: The bundled-manual spec check no longer depends on build history

Sphinx merges an incremental search index with the one already on disk and
prunes by emptying a removed word's document set without dropping the key,
so a developer tree's `searchindex.js` carries phantom entries that a clean
build never emits -- and `python3 tools/gen-docs.py --check` on a cold
machine failed the committed spec for exactly those phantoms. The generator
now canonicalises the index on the way into the bundle: empty entries are
dropped and the object re-serialised with sorted keys, so an incremental
tree and the clean build a fresh clone runs agree byte for byte, and
client-side search is unaffected because it looks words up by key.

The same pass stamps the bundle fingerprint of the inputs it was built from
(the docs sources, the nav injector, and the generator itself) into the spec
header as `Source_Fingerprint`, so a tree with no usable Sphinx build -- a
fresh clone, or after the build directory was removed -- keeps the committed
spec instead of rebuilding the site to reproduce the same bytes. `generate`
takes that path; `--check` always builds, so the gate still fails on a stale
or hand-edited spec. Nine new checks in the tools suite pin the
canonicalisation and the fingerprint.

## Test Suite

2024 tests across 29 categories, up from 2017. The seven new native
checks are the `Dir cache` category's: the fitted long name that used
to fail the read whole (four checks, one of which proves the directory
is still memoised), and the 100-entry directory that the old cap
rejected (three checks, including the memo hit). The man-path checks
of C1 keep their count; only their fixtures changed.

`just test` runs the native suite and `just cli-e2e` runs 87
end-to-end checks, unchanged from 1.62.0. `just tools-check` runs the
195-test tools suite: the 186 that 1.62.0 restored, plus the nine
search-index and fingerprint checks H1 adds.

## Proof Results

**Platinum**, 0 unproved, 0 justified, **1054 of 1054 VCs across 75
analysed units** under gnatprove 16.1.0 at `--level=4`. The count is
unchanged from 1.62.0: none of this release's changes alter the proof
surface. C1's man-path and shell tests live in the default-off native
test runner, C2 pins a runner label in the release workflow with no
compiled code, C3 reorganises the pre-build steps without touching Ada
sources, C4 packs the directory memo -- a performance structure behind
the scanning and SBOM walks that contributes no verification conditions --,
C5 collates timing records into documentation only, and H1 changes the
Python bundler and its tools-suite checks, which carry no Ada surface; no
subprogram gained or lost an assertion, a contract, or a runtime check. No
new `pragma SPARK_Mode (Off)` was added: the only two packages that carry
one remain `Types.Implementation` and `Complexity`.

The proof ran on this tree and re-reported Platinum at the same count, so
the figure is a fresh result rather than an inherited 1.62.0 value.

## Traceability

No new HLR record enters this release, and no requirement changes. The
directory memo is an in-process performance structure behind the
scanning and SBOM walks, so it carries their requirements (`HLR-SCAN`,
`HLR-SBOM`) and adds none. The pre-build bundle and the per-step bench
change the files that gate the tree (`HLR-ARCH`), not the assessed
behaviour.

The Windows test alignment and the macOS runner pin change the tests and
the workflow that gate the tree, and the bundled-manual search-index fix
changes a build artefact's determinism; none of the three assesses
anything, so none carries a requirement. The timing pages record
measurements, not requirements.

The packages changed by this release, and the tags on record that cover
them: the directory memo behind the scanning and SBOM walks
(`HLR-SCAN`, `HLR-SBOM`), and the task gates (`HLR-ARCH`).
