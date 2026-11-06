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
generator. A cold proof alone runs 61-88 s, so a cold tree cannot meet the
budget by construction; the plan records that shape as the outlier rather than
hiding it. The timing table makes the difference visible on every run.

## The measured warm-tree run

One full `just check` on the development machine (12 logical CPUs, warm
result cache, warm gnatprove session, built tree, API docs generator
installed) took **344 s** on 2026-11-06. The 60 s target is not met. The gate
timings from that run, slowest first, are:

| Gate | Seconds |
|------|---------|
| SPARK proof + badges | 99.77 |
| complexity | 97.65 |
| tools unit tests | 40.72 |
| prove diagnostics end-to-end | 40.22 |
| proof metrics in sync | 21.13 |
| fmt | 13.95 |
| CLI end-to-end | 11.42 |
| test counts in sync | 7.99 |
| API docs | 4.19 |
| native tests | 3.44 |
| the other 21 gates | 2.90 |
| **total (sequential)** | **344.34** |

The proof run and the complexity walk account for 197 s. Both scan the tree
once, so they are the first place to look before the budget can move.
