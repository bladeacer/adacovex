# Benchmarking adacovex

This page documents how to benchmark the pipeline and the `prove`
subcommand, the benchmark machine, and the raw sample output.  The
benchmark categories and the expected numbers are on
[Performance](index.md).

The measurements are split by what they measure.  The pipeline and `prove`
timings are on [Pipeline and prove timings](benchmarks-timings.md), the
binary size and the bundled manual are on [Binary size and the bundled
manual](benchmarks-binary-size.md), and the served dashboard is on
[Server throughput and latency](benchmarks-server.md).

## Benchmark machine

Every figure in this document was measured on the adacovex development
machine (a CPU/I/O-bound CLI; the GPU is irrelevant to every code path):

| Component | Spec |
|-----------|------|
| OS | EndeavourOS x86_64, Linux 7.2.2-arch1-1 |
| CPU | 12th Gen Intel Core i7-1255U (4P+8E, 12 threads) @ 4.70 GHz max |
| Cache | 12 MiB L3 shared; 2x2.0 MiB + 2x1.25 MiB L2; 8x32+8x64 KiB L1 (P), 2x48+2x32 KiB L1 (E) |
| Memory | 16 GiB DDR4 (15.33 GiB visible) |
| Storage | SK hynix BC711 512 GiB NVMe SSD |
| Toolchain | gnatprove 16.1.0 (via Alire), hyperfine 1.20, perf 7.2, strace 7.0 |

The i7-1255U is a hybrid laptop part: 10 of the 12 threads are E-cores,
and gnatprove's solver jobs fan out across all of them.  Single-threaded
pipeline figures are dominated by P-core behaviour; the prove-cold solver
floor depends on the E-core fleet.  Lower-thread machines pay more per
solver run; the warm paths stay warm anywhere.

## The `make bench` target

`make bench` benchmarks the assessment pipeline, the `prove` subcommand,
and reports binary size:

- It builds the project, then times `./bin/adacovex` and
  `./bin/adacovex prove` against the repo itself.
- **Four scenarios** are measured, each with a precise meaning (see the
  category reference on [Performance](index.md)).  The prove scenarios time
  the `prove` subcommand -- the true test of proof performance, measured at
  the adacovex-binary level, not just the gnatprove level.
- `make bench` uses [hyperfine](https://github.com/sharkdp/hyperfine) when
  installed; otherwise it falls back to the bash `time` builtin.  It samples
  generously so the reported mean is stable: **10 pipeline-cold +
  15 pipeline-warm + 3 prove-cold + 15 prove-warm** repetitions (2 warmups;
  none for prove-cold).  Each cold repetition deletes the cache dir first;
  the prove-cold repetitions also delete the gnatprove session store
  (`obj/gnatprove/`).  The `time` fallback runs **5 + 5** per scenario.
- It reports the raw and stripped binary sizes (the stripped size is measured
  on a `/tmp` copy; the build output is never modified).

## Running a single shot

For single-shot timings, plain `time` over the same commands (`--no-cache`
for cold, `--cache-dir=<populated dir>` for warm, with or without
`prove`) works the same way.  When comparing two versions, always reset
the cache between runs so the result cache cannot hide the real cost.

`make perf-bench` profiles CPU and syscalls directly with `perf` and
`strace` over `bin/adacovex`, printing cache-miss rates and syscall counts
so a regression in I/O or data layout is visible before a release.

## Probe cache

*(Origin story.)* The SBOM builds a *dev-scope* dependency edge for every
tool that the target's build references, installed on `$PATH` (for
example `gcc`, `alr`, `git`, `make`).  It probes each with `<tool> <flag>`
to capture its version, and each probe spawns a subprocess (tens of
milliseconds per tool, ~150 ms end to end on an 11-tool toolchain).  The
probed versions were first cached under `<cache-root>/probes/<tool>` with
a 7-day TTL, so a wiped result cache re-probed every tool on the next
run -- 1.28.0 moved the store into the tools-set cache blob.

Re-measure here before adding a page family to the tree.
