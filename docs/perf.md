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
- reports the raw and stripped binary sizes (the stripped size is measured on
  a `/tmp` copy; the build output is never modified).

Example output (hyperfine, x86-64, 8-core CI-class machine):

```
=== Cold (fresh result cache + probe cache) ===
  Time (mean + sigma):     488.7 ms + 15.0 ms    [User: 432.6 ms, System: 41.0 ms]
=== Warm (populated caches) ===
  Time (mean + sigma):     311.4 ms +  1.6 ms    [User: 292.3 ms, System:  7.7 ms]

== Binary size ==
bin/adacovex          7.1 MiB (7486736 bytes)
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

- **Cold ~490 ms** on self-assessment: dominated by source scanning (Ada file
  enumeration), SBOM system-tool probing (spawns a subprocess per referenced
  tool), and renderers.
- **Warm ~310 ms**: the on-disk result cache (content-hashed per file,
  oldest-first eviction) skips re-parsing unchanged sources; the probe cache
  skips the subprocess spawns.
- System time is the tell: cold runs show ~41 ms of system time (process
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