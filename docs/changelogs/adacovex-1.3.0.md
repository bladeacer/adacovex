# adacovex 1.3.0

Date: _2026-08-01_

Version bumped 1.1.0 -> 1.3.0 (1.2.0 was never released).

## Changes

### C1: Default target changed to the current working directory

Running `adacovex` without `--target` now audits the current working
directory instead of `../Ada_CRDT`. The default target is resolved to an
absolute path via `Ada.Directories.Current_Directory`.

**Impact:** `make run-self` no longer needs `--target=.`; any directory can
be audited by simply running adacovex from it. `--target=PATH` still works
for any other project.

### C2: `--help` now exits cleanly

`--help` prints the usage text and exits with status `0` without scanning or
assessment. Previously `--help` was parsed but adacovex continued running the
full pipeline and exited according to the DAL result. A dedicated
`Help_Requested` field was added to `CLI_Config` and handled in
`adacovex_main`.

### C3: Generated binder files removed from the repo

The generated `b__adacovex_main.*` and `b__test_runner.*` files were removed
from version control (build artifacts only).

### C4: Differential assessment (`--compare-base=REF`)

New `--compare-base=REF` flag assesses a git base revision in a temporary
worktree (`/tmp/adacovex-diff-<pid>`) and prints a side-by-side table against
the current working tree: packages, subprograms, docstring %, HLR traced,
orphan tags, SPARK level, VCs proved, tests, DAL status. Exit code is `0` only
when there is no regression and the current DAL is Achieved.

Implemented in the new non-SPARK `Adacovex.Diff` package (it spawns `git`
via `GNAT.OS_Lib`), wired into `adacovex_main` as `Run_Diff`, with
`Compare_Base`/`Compare_Base_Len` added to `CLI_Config`. Rows for proof/test
artifacts that the base revision does not commit report `N/A`.

### C5: Hardened dev-manifest swap in the Makefile

`_dev_cmd` (used by `prove`, `doc`, `fmt`) now snapshots `alire.toml`,
`alire.lock`, `alire.lock.prev`, and `alire/settings.toml` into a temp dir,
swaps in `alire-dev.toml`, and restores the snapshots on exit via
`trap ... EXIT INT TERM`. Interrupted or failed dev commands can no longer
leave the manifest or lock files polluted with development dependencies
(whether or not the lock files are committed). `dev-setup` and `prod-setup`
were replaced with guidance stubs.

### C6: GitHub composite action and CI

New `.github/actions/adacovex/action.yml` (install Alire + GNAT toolchain,
cache, build, run the full assessment, publish `dal-status`/`spark-level`/
`test-count` outputs, a Markdown step summary, and SVG badge artifacts) and
`.github/workflows/ci.yml` (self-assessment job + build/test job).

## Fixes

### H1: GNATprove `Initialization` row clobbered Flow Dependencies data

Modern `gnatprove.out` emits separate `Flow Dependencies` and `Initialization`
summary rows. The parser wrote both into `Flow_Checks` / `Flow_Proved`, so a
non-empty Initialization row overwrote the real flow-analysis numbers.

**Impact:** For projects with non-empty init checks, the Bronze level check
(`Flow_Proved >= Flow_Checks`) used init data instead of flow data, and the
"Flow Dependencies" rows in the HTML dashboard and Markdown report showed the
wrong values.

**Fix:** Added `Init_Checks` / `Init_Proved` to `Proof_Summary`, parse the
Initialization row into them, and surface an Initialization row in the HTML
dashboard and Markdown verification report.

### H2: `Proved_VCs` computed incorrectly for modern GNATprove layout

The modern summary layout is `Total | Flow | Provers | Justified | Unproved`
(no explicit "Proved" column). The old code read column 3 as `Proved_VCs`,
which is the "solved-by-provers" count in the modern layout.

**Fix:** `Proved_VCs` is now computed as `Total - Justified - Unproved`,
which is equivalent to flow-solved + provers-solved and correct for both the
old and modern layouts.

### H3: Empty proof data returned Gold instead of Stone

`Determine_SPARK_Level` fell through to Gold for a summary with no data
(`0 >= 0`). A summary is now detected as empty (all counters zero) and
returns Stone, so a project with no GNATprove output cannot pass DAL
assessment on a false Gold.

## Notes

- GNATprove parser tests extended to cover the modern layout, empty summaries,
  and the Flow/Initialization separation (7 new checks; suite now 168 tests).
- The DAL-level minimum SPARK requirements documented in `AGENTS.md` and
  `README.md` were corrected to match `docs/HLR.md` and the implemented
  `Min_SPARK_For` table (DAL-A: Gold, DAL-B: Silver, DAL-C: Bronze, DAL-D/E:
  none).
- `make badges` in `Ada_CRDT` now builds adacovex first if the binary is
  missing and passes an explicit `--target=.`.
- The tracked `alire/alire.lock` and `alire/settings.toml` are now the clean
  release versions (previously they contained development dependencies from an
  accidental dev-manifest build).
- Self-assessment metrics updated to the new layout: 20 packages, 38
  subprograms, 100% docstrings, Platinum (28/28 VCs), 168 tests, DAL-C
  Achieved.

## Proof Results

Self-assessment: **Platinum** (28/28 VCs proved, AoRTE-free).
Ada_CRDT (strict): **Platinum** (273 VCs proved).

## Traceability

New `-- HLR-DIFF` tag on `Adacovex.Diff` is defined in `docs/compliance/HLR.md`
and traced by the differential-assessment feature.
