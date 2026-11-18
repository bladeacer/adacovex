# The `just check` pipeline

`just check` is the single verification entry point. It runs every gate CI
runs, keeps going past a failure, and prints a PASS/FAIL/SKIP summary. This
page records how the pipeline is orchestrated and where its wall time goes.

## What the runner already shares

The gate order lives in `CHECK_GATES` in `tools/tasks.py`. Six rules keep
repeated work out of the pipeline:

- **Build once.** `task_build` records a successful build in the process, so
  the build, native-test, prove, complexity, CLI end-to-end, and SBOM gates
  reuse one `alr build`. A no-op build is cheap, but a real one is not.
- **Format once.** `task_fmt` stores a digest of every source and the dev
  manifest in `obj/adacovex-fmt.stamp`. A warm tree matches the stamp and
  skips gnatformat, so the formatter never bumps a source mtime and the build
  stays a no-op.
- **Bundle the manual once.** `tools/build.py` regenerates the bundled offline
  manual among its pre-build steps, so the offline-manual gate reuses that
  product and never runs `tools/gen-docs.py` a second time. The committed-spec
  gate still runs `gen-docs.py --check` against a fresh Sphinx build, because
  that gate verifies the committed spec rather than producing it.
- **Render the API docs once.** `task_doc` stores a digest of every Ada
  source, the converter, the project file, and the dev manifest. A warm tree
  reads `obj/adacovex-doc.stamp` in 0.07 s instead of running gnatdoc.
- **Prove once.** `task_prove` records a successful proof run, so no later
  gate re-runs gnatprove. The SBOM gate runs after the proof gate and reads
  the single run's `obj/gnatprove/` artefacts.
- **Cache what is safe.** The result cache, the generated specs, and the docs
  bundle are content-keyed. The docs bundle records the fingerprint of its
  inputs, so an unchanged tree reads 76 ms instead of running Sphinx.

A failed build is never memoised: the next gate that needs the binary builds
again, so one broken compile cannot hide behind a stale product.

The build gate runs before every gate that needs the binary. The compile is
one row of the timing table instead of the first gate that happened to need
it, so a row like complexity measures the walk and nothing else.

## Parallel phases

The gates run in three short serial phases around one parallel phase:

1. **Head (serial).** `fmt` and `build` run alone. They rewrite sources and
   build artefacts, so every later gate must see their product.
2. **Middle (serial).** The bundled-manual gates, the SPARK proof, the API
   docs, the SBOM, and the tools unit tests run alone. The first four write
   products that a later gate reads (`docs/api-docs/`, `sbom.json`, the
   badges), and the tools suite compares `git status` around every `--check`,
   so it must not see another gate's build-state write.
3. **Parallel.** Every independent gate runs at once: the native tests, the
   CLI end-to-end checks, the prove-diagnostics fixtures, and the static
   gates. The runner uses one worker per core, capped
   at 8. Each gate's child output is captured and printed in the declared
   order, so the log and the summary stay deterministic. The cap is 8 workers:
   the parity and tools gates are mostly I/O, and a wider fan-out made the
   CPU-bound shards slower through contention.
4. **Tail (serial).** The count-sync gates run last, after the tests and the
   proof have refreshed their inputs.

A gate whose product another gate checks is never in the parallel phase. The
phases are listed as `CHECK_SERIAL_HEAD`, `CHECK_SERIAL_MID`, and
`CHECK_SERIAL_TAIL` in `tools/tasks.py`, and `tools/tests.py` fails when a
gate is missing from the partition or appears in two phases.

Two heavy parallel gates shard internally. The CLI end-to-end suite runs four
`--shard INDEX/COUNT` processes, and the prove-diagnostics suite runs one
process per fixture case plus one for the output modes. Both keep their exit
codes, print their results in order, and report a combined check count.

## Timing the gates

Every `just check` run prints a gate-timing table after the summary, slowest
first. The table sums each gate's own wall time, and a parallel phase overlaps
those rows, so the sum is larger than the run's wall time. The run's wall time
is the number to compare against the 60 s budget.

## The reference run

The reference measurement is a v1.74.0 development run. One full `just check`
on the development machine on 2026-11-18, with a warm result cache, a warm
gnatprove session, and warm formatting and API-docs stamps, passed all 34
gates in **37 s** of wall time. The raw stdout is
`obj/check-v1.74.0-warm.log`.

| Gate | Seconds |
|------|---------|
| prove diagnostics end-to-end | 19.31 |
| CLI end-to-end | 14.72 |
| native tests | 10.09 |
| tools unit tests | 5.90 |
| user documentation | 2.37 |
| SPARK proof + badges | 2.22 |
| ASCII | 1.94 |
| markdown links | 1.62 |
| SBOM | 1.28 |
| bundled offline manual spec | 1.06 |
| the other 24 gates | 10.47 |
| **sum of gate times** | **70.98** |
| **wall time** | **37** |

The warm stamps changed the shape. `fmt` stays near 0.5 s, the API docs gate
is 0.04 s, and the build is a no-op, because the formatter no longer touches
an unchanged source. The prove-diagnostics gate is the longest parallel row,
and it runs its nine fixture cases concurrently. The v1.74.0 script split
moves no gate into a different phase and changes no measured product, so the
before/after shape stays the same.

## The measurement that drove item 15b

Two full `just check` runs on the development machine (12 logical CPUs, built
tree, warm result cache, warm gnatprove session, generated specs and docs
bundle content-current) on 2026-11-14. The first ran directly after a version
bump, so its proof cache was cold, and it took 620.58 s with one gate failing
on the bump's own ordering. The second, fully warm run passed all 31 gates in
**452.99 s**. The raw stdout of both runs is kept as
`obj/check-v1.70.0-r1.log` and `obj/check-v1.70.0-r2.log`. These figures are
history, not the current shape.

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

Three findings shaped the work. The complexity walk was the largest gate at
131.15 s, and it now takes 1.07 s after the directory-snapshot memo. The prove
diagnostics fixtures and the tools unit tests were pure Python and ran their
cases in one invocation; the fixture cases now run in parallel. The SPARK
proof is a warm cache hit at 4.45 s, while a cold pass in the same session paid
155.33 s for it -- the difference the result cache exists to make.

## The budget

The 60-second budget is a **warm-tree** target: a warm result cache, a warm
gnatprove session, a built tree, and current formatting and API-docs stamps.
A cold proof alone
ran 155 s in the measured session above, so a cold tree cannot meet the budget
by construction. The plan records that shape as the outlier rather than hiding
it, and the timing table makes the difference visible on every run.
