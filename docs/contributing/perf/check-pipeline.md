# The `just check` pipeline

`just check` is the single verification entry point. It runs every gate CI
runs, keeps going past a failure, and prints a PASS/FAIL/SKIP summary. This
page records how the pipeline is orchestrated and where its wall time goes.

## What the runner already shares

The gate order lives in `CHECK_GATES` in `tools/tasks.py`. Five rules keep
repeated work out of the pipeline:

- **Build once.** `task_build` records a successful build in the process, so
  the build, native-test, prove, complexity, CLI end-to-end, and SBOM gates
  reuse one `alr build`. A no-op build is cheap, but a real one is not.
- **Bundle the manual once.** `tools/build.py` regenerates the bundled offline
  manual among its pre-build steps, so the offline-manual gate reuses that
  product and never runs `tools/gen-docs.py` a second time. The committed-spec
  gate still runs `gen-docs.py --check` against a fresh Sphinx build, because
  that gate verifies the committed spec rather than producing it.
- **Prove once.** `task_prove` records a successful proof run, so no later
  gate re-runs gnatprove. The SBOM gate runs after the proof gate and reads
  the single run's `obj/gnatprove/` artefacts.
- **Group the cases.** The native suite, the CLI end-to-end checks, and the
  prove-diagnostics fixtures each run as one invocation. There is no process
  per case or per file.
- **Cache what is safe.** The result cache, the generated specs, and the docs
  bundle are content-keyed. The docs bundle records the fingerprint of its
  inputs, so an unchanged tree reads 76 ms instead of running Sphinx.

A failed build is never memoised: the next gate that needs the binary builds
again, so one broken compile cannot hide behind a stale product.

The build gate runs before every gate that needs the binary. The compile is
one row of the timing table instead of the first gate that happened to need
it, so a row like complexity measures the walk and nothing else.

## Timing the gates

Every `just check` run now prints a gate-timing table after the summary,
slowest first, plus the sequential total. The table is the measurement to
compare across changes; no separate benchmark run is needed.

## The current gate order

The build is paid once, before every gate that needs the binary, and the
offline-manual gate reuses the bundle the build already made. Before v1.71.0
the build was charged to the first gate that needed it (complexity) and the
manual was bundled twice, so an older table splits the same work across
different rows and is not row-by-row comparable with a current run (compare
the total and the moved rows instead).

## The reference run

The most recent full measurement is the v1.71.0 run. One full `just check` on
the development machine on 2026-11-16, with a warm result cache and a warm
gnatprove session, passed all 31 gates with `fmt` first. `fmt` rewrote source
files, so the build row carries a real recompile rather than a no-op one; the
raw stdout is `obj/check-v1.71.0.log`. No v1.72.0 run replaces it yet: item
15c records the next warm-tree measurement against the 60 s budget.

| Gate | Seconds |
|------|---------|
| tools unit tests | 80.27 |
| build | 69.65 |
| prove diagnostics end-to-end | 44.55 |
| fmt | 23.84 |
| CLI end-to-end | 17.74 |
| test counts in sync | 15.34 |
| proof metrics in sync | 9.72 |
| native tests | 6.01 |
| API docs | 3.81 |
| SPARK proof + badges | 1.93 |
| the other 21 gates | 8.44 |
| **total (sequential)** | **281.30** |

The two rows the release targeted moved as intended. The compile is now the
build row instead of being charged to complexity, and complexity measures its
own walk at 0.16 s. The offline-manual gate reads 0.00 s and prints
`Offline manual: already bundled by the build`, because it reuses the build's
product. The remaining cost sits outside this item: the tools unit tests, the
prove diagnostics fixtures, and the fmt pass are item 15c's work.

## Why the gates stay sequential

Parallel execution was explored and rejected. The gates share generated
outputs (`sbom.json`, `src/adacovex_version_info.ads`, the docs template, the
badges), so two concurrent writers race and the summary stops being
deterministic. The gates also print directly to stdout, and thread-level
capture would interleave the output of unrelated gates. The wall time is
dominated by build and proof, which are already single invocations, so
parallelising the cheap static gates would save little and cost correctness.

## The budget

The 60-second budget is a **warm-tree** target: a warm result cache, a warm
gnatprove session, a built tree, and a toolchain without the optional API-docs
generator. A cold proof alone ran 155 s in the measured session below, so a
cold tree cannot meet the budget by construction. The plan records that shape
as the outlier rather than hiding it, and the timing table makes the
difference visible on every run.

## The measurement that drove item 15b

Two full `just check` runs on the development machine (12 logical CPUs, built
tree, warm result cache, warm gnatprove session, generated specs and docs
bundle content-current) on 2026-11-14. The first ran directly after a version
bump, so its proof cache was cold, and it took 620.58 s with one gate failing
on the bump's own ordering. The second, fully warm run passed all 31 gates in
**452.99 s**. The raw stdout of both runs is kept as
`obj/check-v1.70.0-r1.log` and `obj/check-v1.70.0-r2.log`. These figures are
history, not the current shape: the v1.71.0 run above removed the repeated
build and manual bundle from the table.

Gate timings of the warm run, slowest first:

| Gate | Seconds |
|------|---------|
| complexity | 131.15 |
| prove diagnostics end-to-end | 72.55 |
| tools unit tests | 69.27 |
| test counts in sync | 47.28 |
| proof metrics in sync | 40.49 |
| CLI end-to-end | 30.40 |
| fmt | 26.13 |
| native tests | 10.03 |
| API docs | 8.61 |
| SPARK proof + badges | 5.63 |
| the other 21 gates | 11.45 |
| **total (sequential)** | **452.99** |

Three findings shape the next steps. The complexity walk is now the largest
gate at 131.15 s, and it has no cache: it re-reads every file on every run.
The prove diagnostics fixtures (72.55 s) and the tools unit tests (69.27 s)
are pure Python and run their cases in one invocation already. The SPARK
proof is a warm cache hit at 5.63 s, while the cold pass in the same session
paid 155.33 s for it -- the difference the result cache exists to make.

The total is not the comparable number across runs, because it follows the
machine's load; the per-gate split is. The 344 s figure from 2026-11-06 is
retired: that run predates the 31-gate table and the v1.70.0 SBOM and docs
work. The 452.99 s warm run is likewise superseded by the v1.71.0 table, and
the 60 s budget stays open until item 15c records a run that meets it.
