# The `just check` pipeline

`just check` is the single verification entry point. It runs every gate CI
runs, keeps going past a failure, and prints a PASS/FAIL/SKIP summary. This
page records how the pipeline is orchestrated and where its wall time goes.

## What the runner already shares

The gate order lives in `CHECK_GATES` in `tools/tasks.py`. Three rules keep
repeated work out of the pipeline:

- **Build once.** `task_build` records a successful build in the process, so
  the build, native-test, prove, complexity, and SBOM gates reuse one
  `alr build`. A no-op build is cheap, but a real one is not.
- **Group the cases.** The native suite, the CLI end-to-end checks, and the
  prove-diagnostics fixtures each run as one invocation. There is no process
  per case or per file.
- **Cache what is safe.** The result cache, the generated specs, and the docs
  bundle are content-keyed. The docs bundle records the fingerprint of its
  inputs, so an unchanged tree reads 76 ms instead of running Sphinx.

## Timing the gates

Every `just check` run now prints a gate-timing table after the summary,
slowest first, plus the sequential total. The table is the measurement to
compare across changes; no separate benchmark run is needed.

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

## The measured warm-tree run

Two full `just check` runs on the development machine (12 logical CPUs, built
tree, warm result cache, warm gnatprove session, generated specs and docs
bundle content-current) on 2026-11-14. The first ran directly after a version
bump, so its proof cache was cold, and it took 620.58 s with one gate failing
on the bump's own ordering. The second, fully warm run passed all 31 gates in
**452.99 s**. The raw stdout of both runs is kept as
`obj/check-v1.70.0-r1.log` and `obj/check-v1.70.0-r2.log`.

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
work.
