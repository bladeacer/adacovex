# adacovex 1.73.0

Date: _2026-11-18_

Version bumped 1.72.0 -> 1.73.0.

## Changes

### C1: One test root and real fixture projects

Every test now lives under `src/tests`. The Python end-to-end suites moved to
`src/tests/e2e/` and split by category: `cli/`, `prove/`, `dashboard/`,
`action/`, and the shared `lib/` helpers. `tests/` no longer exists.

A fixture is a real project under `src/tests/projects/`. The consumer action,
the action project-config case, and every contract-error class carry their own
`alire.toml`, GNAT project file, `src/` tree, and README. A contract-error
class also carries `case.toml`, which states the check the diagnostics block
must name.

The two action jobs in `ci.yml` copy the committed fixture tree instead of
writing one inline. `just test-layout-check` fails when a test sits outside the
root, a fixture is incomplete, or a workflow writes a project with a heredoc.

### C2: A test checks the host and skips with a reason

`Adacovex.Test_Support` gained `Temp_Dir`, `Remove_Tree`, `Join`, `To_Native`,
`Run_Command`, `Executable_On_Path`, `Host_OS`, `Skip`, `Skip_On`, and
`Skip_Without`. `Temp_Dir` creates a unique directory under the host temp
directory, and `Run_Command` spawns an argument vector instead of a shell
string. A skip is recorded apart from a pass and a failure, and `Skip_On` and
`Skip_Without` return True so the test body returns before it runs.

The runner table gained a `Skips` column and the totals gained a `Skipped:`
count, so a skip is visible in every run summary. A new `Test support`
category exercises the helpers and the Windows drive-letter and UNC path
shapes on any host.

`just portability-check` flags a POSIX path, a shell invocation, a `chmod`, a
`uname`, or another host-specific shape in a test source. The few deliberate
platform assertions are a documented allow-list.

### C3: The native suite runs on three hosts

The `platform-tests` CI job runs the native suite on Ubuntu, macOS, and
Windows. A pull request runs the fast subset, and a push to main adds the CLI
and prove-diagnostics suites. The Playwright dashboard suite stays on Linux,
because it needs Chromium.

The dashboard helpers no longer name a personal directory. The screenshot
scripts read `SHOT_DIR` or a relative docs path, and the server helper finds
the repository root by its GPR marker, so the suite runs from any checkout.

## Fixes

### H1: A skipped tldr check is no longer a pass

The CLI suite reported the Windows tldr stub as `PASS` with a note that the
check was skipped. It now calls `Skip`, so the run summary counts it as a skip
and never as a pass.

## Test Suite

Native suite: 2413/2413 passing across 30 categories. The new `Test support`
category adds 19 checks for the temp directory, the argument-vector command,
the path helpers, the skip accounting, and the Windows path shapes.

`just cli-e2e` keeps its 165 checks (one skips without a prover), and
`just prove-e2e` keeps its 132 checks over the committed fixture projects. The
tools suite covers the new layout and portability gates.

## Proof Results

The Ada change is test-only: it adds the test support helpers and their
self-tests. No product unit changed, no `SPARK_Mode (Off)` pragma was added,
and the two exempt packages are unchanged.

The tree proves at the default budget (gnatprove 16.1.0: 1058 VCs, 0 unproved,
0 justified). Self-assessment: Gold, 100% docstrings, DAL-C Achieved, ASIL B
and Class A Achieved under `--standard=all`.

## Traceability

HLR-ARCH: The task targets gained `just test-layout-check` and `just
portability-check`, both wired into `just check` and CI, and the fixture
projects are copied by CI instead of being written inline.

No product HLR changed. The release touches only the test tree, the developer
gates, and their documentation.
