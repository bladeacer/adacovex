# Performance

adacovex is a zero-dependency CLI whose hot path is the assessment pipeline
(scan -> patch -> doc metrics -> proof parse -> test parse -> DAL assess ->
render).  This page documents how to benchmark it, the expected numbers on a
typical machine, and the optimisations that keep those numbers low.

## Benchmarking

`make bench` benchmarks the assessment pipeline and reports binary size:

- builds the project, then times `./bin/adacovex` against the repo itself;
- **cold** runs (fresh result cache + probe cache) and **warm** runs
  (populated caches) are measured separately;
- uses [hyperfine](https://github.com/sharkdp/hyperfine) when installed and
  falls back to the bash `time` builtin otherwise -- no tooling required;
- samples generously so the reported mean is stable: hyperfine runs **10
  cold + 15 warm** repetitions (2 warmup runs), each cold repetition
  deleting the cache dir first so it measures a truly empty result +
  probe cache; the `time` fallback runs **5 cold + 5 warm**;
- reports the raw and stripped binary sizes (the stripped size is measured on
  a `/tmp` copy; the build output is never modified).

Example output (hyperfine, x86-64, 8-core CI-class machine):

```
=== Cold (fresh result cache + probe cache) ===
  Time (mean + sigma):     476.7 ms + 13.6 ms    [User: 423.6 ms, System: 40.5 ms]
  Range (min ... max):     463.7 ms ... 504.8 ms    10 runs
=== Warm (populated caches) ===
  Time (mean + sigma):     312.2 ms +  4.6 ms    [User: 293.1 ms, System:  8.0 ms]
  Range (min ... max):     305.3 ms ... 324.0 ms    15 runs

== Binary size ==
bin/adacovex          7.1 MiB (7486040 bytes)
after strip           3.1 MiB (3234200 bytes)
savings               56.8%
```

For single-shot timings, plain `time` works the same way:

```bash
time ./bin/adacovex --no-cache          # cold, no result cache
time ./bin/adacovex --cache-dir=/tmp/c  # warm
```

When comparing two versions, always reset the cache between runs
(`--cache-dir=<fresh dir>` or delete the cache dir) so the result cache does
not hide the real cost.

## What the numbers mean

Figures below are from `make bench` on this machine (hyperfine, 10 cold + 15
warm runs, 2 warmup). They will shift with the machine and the codebase;
what matters is the shape:

- **Cold ~480 ms** on self-assessment: dominated by source scanning (Ada file
  enumeration), SBOM system-tool probing (spawns a subprocess per referenced
  tool), and renderers.
- **Warm ~310 ms**: the on-disk result cache (content-hashed per file,
  oldest-first eviction) skips re-parsing unchanged sources; the probe cache
  skips the subprocess spawns.
- System time is the tell: cold runs show ~40 ms of system time (process
  spawns), warm ~8 ms.

## Optimisation history

### Probe cache

The SBOM builds a *dev-scope* dependency edge for every tool the target's
build references that is installed on `$PATH` (e.g. `gcc`, `alr`, `git`,
`make`), probing each with `<tool> <flag>` to capture its version.  Each
probe spawns a subprocess, which cost tens of milliseconds per referenced
tool (`System: 42.8 ms -> 9.1 ms`, ~150 ms end to end on an 11-tool
toolchain).

The probe cache stores each tool's one-time probed version in
`<cache-root>/probes/<tool>` with a 7-day TTL.  Unchanged toolchains stop
paying the spawn cost on every run; the TTL means toolchain upgrades are
reflected in the SBOM within a week even if the machine never re-probes.
`--no-cache` disables the probe cache as well.

## Binary size

The debug-symbol-carrying build is ~7 MiB; stripping
(`strip bin/adacovex`) yields ~3.1 MiB (~57% smaller) without affecting
behavior.  GNAT's default build keeps symbols for debugging (`gdb`
works); release artifacts are stripped.  `make bench` always reports both
so regressions in code size are visible in the same command that reports
timings.

## CI

CI runs the self-assessment with result caching disabled where determinism
matters (`--no-cache`-equivalent fresh dirs) and `make` gates are timed
loosely; timings are informational only.  The `bench` target is not part of
`make check` (it would make the gate machine-dependent -- a slow CI runner
should not fail a build) but is run by hand before releases.