# Measured figures

This section is the record of measured adacovex figures. Each page states the version, the host profile, the command, and the raw result. The method lives on [Benchmarking adacovex](../contributing/perf/benchmarks.md), and the reverse-chronological record of the work is on [Performance optimisation history](../contributing/perf/optimisation-history.md).

`just perf-report` writes the tables on these pages. It measures the shapes in `tools/bench.py`, keeps the raw report in `obj/perf-report/latest.json`, and rewrites only the marked region of each page. Do not edit a number by hand; run the task instead.

## At a glance

<!-- perf-report:begin -->
Measured on adacovex `1.75.0` on 2026-11-24.

| Metric family | Current value | Detail |
|---------------|---------------|--------|
| Pipeline warm | 2.74 s | [Timings](timings.md) |
| Pipeline cold | 2.64 s | [Timings](timings.md) |
| Prove warm | 2.83 s | [Timings](timings.md) |
| Build warm (`alr build`, no-op) | 853.1 ms | [Timings](timings.md) |
| Binary size | 16.7 MiB (17507072 bytes) | [Binary size](binary-size.md) |
| Bundled manual spec | 2.6 MiB (2736903 bytes) | [Docs bundle](bundle.md) |
| Cache hits (warm run) | 49 | [Cache](cache.md) |
| Native tests | 2494 passed | [Tests](tests.md) |

## Host profile

| Item | Value |
|------|-------|
| CPU | `12th Gen Intel(R) Core(TM) i7-1255U` |
| Cores | `12` |
| Kernel | `7.3.5-arch1-1` |
| Platform | `Linux x86_64` |
| Filesystem | `ext4` |
| Compiler | `GNATMAKE 16.2.1 20260810` |
| gnatprove | `unknown` |
| Build profile | `covex=DEVELOPMENT` |
| hyperfine | `hyperfine 2.0.0` |
| strace | `strace -- version 7.3` |
| Load average (1 min) | `4.49` |
<!-- perf-report:end -->

## What the numbers mean

A figure without its host profile is not comparable with another figure, so the profile sits beside every table. The load average is the reading before the first scenario, and the later scenarios inherit the load the earlier ones leave behind.

A slow first run on a fresh clone is expected: there is no result cache, no gnatprove session, and no `gnatprove.out`. A slow run on a warm tree is a defect, and the per-gate table from `just check` names the gate.

## The metric families

- [Pipeline, prove, build, and docs timings](timings.md) -- the mean and deviation of each measured shape.
- [Binary size](binary-size.md) -- the raw and stripped size of `bin/adacovex`.
- [Syscall profile](syscalls.md) -- the `strace -c` counts of one warm pipeline run.
- [Result-cache hit rate](cache.md) -- the hits, misses, and evictions of a warm run.
- [Docs bundle size and cost](bundle.md) -- the embedded manual's size and its two build shapes.
- [Native test counts](tests.md) -- the suite the report was measured beside.
