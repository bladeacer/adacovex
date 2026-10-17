# adacovex 1.61.0

Date: _2026-10-11_

Version bumped 1.60.0 -> 1.61.0.

## Changes

### C1: CI caches the toolchain, the result cache, and the gnatprove session store

The composite action already exposed `cache` and `result-cache`, but no `ci.yml`
job passed them, so every run re-proved and re-assessed cold. The
self-assessment, the build-and-test job, the consumer run-tests job, the PR
coverage-delta job, and the release job now enable both. The result cache's
entries are keyed by SHA-256 content hashes, so a restored entry is either an
exact hit for the inputs or absent.

The self-assessment and release jobs additionally cache the gnatprove session
store (`obj/gnatprove`), keyed on a hash of the proof-relevant sources. That
key excludes the two generated bundle specs, which are data-only string
constants with no proof surface, so a docs or dashboard edit no longer
invalidates a cached session. The exclusion matches the one the prove result
cache already uses, so the two caches agree on what counts as proof input.

A restored cache cannot mask a regression. The prove result cache refuses to
serve a stored summary whose Total row reports unproved VCs, so a degraded run
falls through to a real gnatprove run rather than replaying it. The caching
rules and that guard are written up in the CI/CD workflows page.

### C2: The prove-timing phase table folds 1.59.0 through 1.61.0 into one phase

The open phase is now 1.57.0-1.61.0, still with 1.58.0 as its representative.
1.59.0, 1.60.0, and 1.61.0 change no measurement methodology: the cross-platform
and task-runner work of the earlier two is invisible to the prover, and this
release's proof edit moves the check count without moving the wall.

The 1.61.0 figures are recorded on the release profile beside their load,
because every one of them is higher than the 1.58.0 column and the shared box
explains most of the gap: pipeline warm 43.2 ms, pipeline cold 69.5-87.8 ms,
prove warm 53.3 ms, and prove cold 60-72 s at 1022 VCs. A figure taken at load
1.0 does not displace one taken at 0.59 on a row this page already documents as
load-sensitive, so the numbers are noted rather than promoted. The oldest of the
three closed phases, 1.45.0-1.47.0, is retired, and the reason the warm syscall
floor sits where it does stays in the across-every-phase notes.

### C3: The git fixtures in the test suites carry their own identity

The tools test suite and the end-to-end harness both create throwaway git
repositories. Each now writes a test user into the repository-local config in
addition to the `GIT_AUTHOR`/`GIT_COMMITTER` variables and the blanked global
and system config, so a commit can never be attributed to the developer's own
git user even on a git that ignores the environment variables. The tools suite
also uses the portable null-device spelling instead of a hardcoded `/dev/null`,
which failed on a Windows host.

No test in either harness runs `git push`. The release-tag tests assert the
order of the delete and the push against a fake `sh`, so the real push is never
executed, and the throwaway repositories carry no remote at all.

## Fixes

### H1: The docs virtualenv no longer prints a sys.prefix RuntimeWarning

A recipe put the relative `.venv/bin` on `PATH`, so a Python 3.13 interpreter
started from it reported `sys.prefix` as the relative `.venv` and `<frozen
site>` printed `RuntimeWarning: Unexpected value in sys.prefix` on every gate
that built the manual. The justfile now builds an absolute venv-bin path from
the justfile directory, which covers Linux, macOS, and Windows with one change.

### H2: `adacovex-config` no longer emits gnatprove info messages

The prove subcommand surfaced three `info:` lines from the flag-suggestion
path: gnatprove could not analyse `Suggest_Flags` in context because it
returned an unconstrained `String`, so it reported the failure and then
inlined the two helpers. The function now returns a bounded record the caller
slices, which removes the unconstrained return. The three helpers carry an
explicit `Global => null` contract so gnatprove analyses each one separately
instead of only inlined, which clears the remaining two messages.

The contracts are load-bearing rather than decorative. The only call site
lives in the non-SPARK testing code, so without a contract the body is demoted
to contextual-only analysis and its verification conditions disappear from the
proof surface entirely. The `Edit_Distance` contract carries a `'First`
precondition, which is the price of the standalone analysis: the body indexes
up to offset 64, so it needs the caller to rule out a `'First` that would
overflow that offset, and both call sites pass slices starting at index 1.

### H3: The test-count drift that failed three gates is synced tree-wide

The tree carried 1821 passing tests while many files still named 1818, so the
tools unit tests, the CLI end-to-end run, and the test-count gate all failed.
The count is now 1821 everywhere the sync tool owns, and the hand-maintained
spots -- the `require-tests` inputs in the workflows, the counts in the README
and the developer guide, and the category table in the contributing guide --
match.

## Test Suite

2017 tests across 29 categories, unchanged from 1.60.0. This release changes no
test surface: the proof edit in `adacovex-config.adb` keeps the same CLI
behaviour, so the existing parser and config tests still cover it, and the git
fixture work changes only how the throwaway repositories are set up.

`just test` runs the native suite, `just cli-e2e` runs the end-to-end suite at
75 checks including the git-backed differential modes, and `just tools-check`
runs the 174-test tools suite that drives the git fixtures.

## Proof Results

**Platinum**, 0 unproved, 0 justified, **1022 of 1022 VCs across 70 analysed
units** under gnatprove 16.1.0 at `--level=4`. The count is down from 1047 in
1.60.0, and the change is a real reduction in the proof surface rather than a
shift of it.

Twenty-one of the removed checks were artefacts of the unconstrained `String`
return that `Suggest_Flags` no longer has: slicing the bounded result needs no
range check. The `Global => null` contract on `Suggest_Flags` adds one data
dependencies VC, for a net reduction of 25. Every one of the 97 checks that
remain in the function is still proved, so no logic lost its verification. The
proof ran on this tree and re-reported Platinum at the new count.

## Traceability

No new HLR record enters this release, and no tag is added or removed. The
proof-surface edit extends `HLR-PROVE`, on record for the gnatprove runner and
the proof discipline of the tree, because it changes how three helpers are
analysed and moves the campaign's VC count. The git fixture and CI cache work
change no requirement: they change the tests that gate the tree and the CI that
runs them.

The packages changed by this release, and the tags already on record that cover
them: the CLI configuration parser (`HLR-CLI`) and the gnatprove runner
(`HLR-PROVE`). C1 and C3 change no requirement.
