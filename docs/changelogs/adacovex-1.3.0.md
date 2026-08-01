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
  and the Flow/Initialization separation (7 new checks; suite now 167 tests).
- The DAL-level minimum SPARK requirements documented in `AGENTS.md` and
  `README.md` were corrected to match `docs/HLR.md` and the implemented
  `Min_SPARK_For` table (DAL-A: Gold, DAL-B: Silver, DAL-C: Bronze, DAL-D/E:
  none).
- `make badges` in `Ada_CRDT` now builds adacovex first if the binary is
  missing and passes an explicit `--target=.`.

## Proof Results

Self-assessment: **Platinum** (28/28 VCs proved, AoRTE-free).
Ada_CRDT (strict): **Platinum**.
