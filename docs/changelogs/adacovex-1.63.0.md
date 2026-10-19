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
so `just tools-check` runs 186 tests again.

## Test Suite

2017 tests across 29 categories, up from 1864. Forty earlier checks in
this release cover the structural readers, the package-root rule, and the
root npm and Go declarations. Fifteen more pin adacovex as a
dependency in both directions, and the new `Install method` category
holds 23 checks for the classifier, the scope rule, and the filesystem
walk behind them. The `Server routing` category grows to 180 checks: the
two new routes and their near misses, the `Route_Path` round trip over
every route kind, the protected counter store, and the `/api/info`
payload.

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
186-test tools suite (restored in H2, plus the eight requirements-sync
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

The status report adds no requirement: it reports state and never assesses it.
The hermetic suite changes no requirement: it changes the tests that gate
the tree. The requirements single-sourcing and the tools-suite restore
change no requirement either: they change the files that gate the tree.

The packages changed by this release, and the tags on record that cover
them: the manifest parsers and the dependency graph (`HLR-MANIFEST`), the
SBOM they feed (`HLR-SBOM`), the dashboard server routes and its API
(`HLR-SERVER`), the tldr installer (`HLR-TLDR`), the differential-mode VCS
abstraction (`HLR-DIFF`), and the task gates (`HLR-ARCH`).