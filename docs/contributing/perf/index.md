# Performance

adacovex is a zero-dependency CLI. Its hot path is the assessment pipeline
(scan -> patch -> doc metrics -> proof parse -> test parse -> DAL assess ->
render, plus the SBOM). This page defines the benchmark categories and the
expected numbers on a typical machine.

The user-facing results summary is on [Performance and benchmarks](../../usage/performance.md).
The benchmark how-to is on [Benchmarking](benchmarks.md), with the
[pipeline and prove timings](benchmarks-timings.md), the [binary size and
the bundled manual](benchmarks-binary-size.md), and the [server
throughput and latency](benchmarks-server.md) measured beside it. The
per-release `just prove` timings, grouped into phases, are on [Prove timing
and the optimisation review](prove-timing.md); the reverse-chronological
record of the work behind the numbers is on [Performance optimisation
history](optimisation-history.md).
The `just check` orchestration, its timing table, and the parallel-phase
layout are on [The `just check` pipeline](check-pipeline.md).

## Benchmark category reference

adacovex has two *caches* and one *build step*; every benchmark category is
defined by which of them are populated:

- the **result cache** (`<cache>/<version>/`, or `--cache-dir`):
  adacovex's own content-addressed store of scan, graph, and prove results;
- the **gnatprove session store** (`<target>/obj/gnatprove/`):
  gnatprove's internal per-unit session, which re-analyses only changed
  units;
- the **build** (`alr build`, run by every `make` recipe that proves): a
  no-op takes ~0.3 s when built; `just clean` forces a full recompile.

| Category | Command | Result cache | gnatprove session | What it measures |
|----------|---------|--------------|-------------------|------------------|
| Pipeline cold | `adacovex --cache-dir=<fresh>` | empty | n/a (not spawned) | Scan, parse, DAL, SBOM, render with no cached results |
| Pipeline warm | `adacovex --cache-dir=<populated>` | hit | n/a | Cache-hit path: startup, walks, blob deserialisation |
| Prove cold | `adacovex prove --no-cache --cache-dir=<fresh>` | empty | **wiped** | Truly cold proving: full solver run + everything in pipeline cold (a first CI invocation on a bare runner) |
| Prove cold clone | `adacovex prove --cache-dir=<fresh> --target=<fresh copy>` | empty | absent (fresh tree) | A first run on a freshly cloned checkout: no cache, no session, and no `gnatprove.out` yet -- the proof, the summary parse, and the pipeline all from zero |
| Prove warm | `adacovex prove --cache-dir=<populated>` | hit | n/a | The short-circuit: one content-hash of the inputs, then serve the stored proof (a developer on an unchanged tree) |
| Cold build | `tools/build.py --release` in a copy without `obj/`, `bin/`, `docs/_build/` | n/a | absent | The first build a fresh checkout pays: generators, workspace sync, full compile and link |
| Docs regen, cold tree | `python3 tools/gen-docs.py` without `docs/_build/` | n/a | n/a | The bundled-manual phase on a fresh clone: the committed spec already records the sources, so Sphinx does not run |
| Docs regen, full Sphinx | `python3 tools/gen-docs.py --fresh` | n/a | n/a | A clean Sphinx build plus the full re-encode -- what a real docs change pays |

Two further shapes exist and are worth recognising (one-time-per-session
states, not steady states, so they are not benchmarked):
- *adacovex-side cold*: `prove --no-cache` with the result cache wiped but
  `obj/gnatprove/` populated. gnatprove's session absorbs the solver cost;
  the run re-does only the adacovex-side work (~1.3 s here) -- what a
  `--cache-dir` change on a built machine costs.
- *partial session*: `obj/gnatprove/` holds only some units (after a
  targeted `gnatprove -u` run). A prove miss then re-analyses the missing
  units and lands between the two cold shapes. A full `just prove` always
  ends with a complete session, so back-to-back runs sit at prove-warm.

## What the numbers mean

The current values live in [Measured figures](../../stats/index.md), with the
version, host profile, command, and raw result beside each one.
`just perf-report` writes them at every version bump, so this page explains
the shapes and the trend rather than restating a measurement. The values
shift with the machine and the codebase; what matters is the shape:

- **Pipeline cold** is dominated by source scanning (Ada file enumeration
  and SHA-256 of every scanned file), the SBOM tree walk and word scan, and
  the renderers. Nothing here can be skipped: the result cache is empty, so
  every file must be read and hashed at least once (tool-version probes and
  ecosystem-metadata lookups live per-machine, outside the result cache,
  and survive cache wipes).
- **Pipeline warm** is the on-disk result cache skipping the re-parse of
  unchanged sources, plus the stamp fast path skipping the per-file
  SHA-256 (a file unchanged in size is not re-hashed) and the tools-set
  cache skipping the SBOM dev-dependency word scan and the tool probes.
  The remaining time is process startup, directory walks, and blob
  deserialization. The directory memo is what keeps the warm `newfstatat`
  count down, and [Syscall profile](../../stats/syscalls.md) records it.
- **Cold build** is a release-profile build on a fresh checkout: a
  concurrent bundle of generators, the workspace sync inside a no-op `alr
  build`, then the compile and link over every unit with both mains. The
  pre-build steps run in parallel, so the bundle costs the slowest step
  plus startup rather than the sum; [Timings](../../stats/timings.md)
  reports both shapes.
- **Prove cold** is a from-scratch solver run plus the whole pipeline,
  dominated by gnatprove itself and paid once per gnatprove session, not
  per run. The row is solver-bound, and a paired run against an older
  release binary cannot separate two versions when the sign of the
  difference flips between the trees.
- **Prove warm** is the prove result cache serving the stored proof after
  one content-hash of the input tree and restoring the cached
  `gnatprove.out`, so the assessment parses it -- the number a developer
  hits on an unchanged tree.
- **Prove cold clone** is bounded by the same solver run as prove cold plus
  one tree copy; the only structural difference is that the clone starts
  without even a `gnatprove.out`, so the run cannot short-circuit anything.
  Read it as the first-invocation cost a new machine or CI runner pays.
- System time is the tell between I/O-bound and CPU-bound work, and the
  syscall profile shows which call dominates.

## How the timing table is kept

`docs/contributing/perf/prove-timing.md` keeps one column per **phase**: a
range of versions whose implementation methodology is largely similar. Each
phase carries one representative version that supplies the phase's complete
metric set. A new version folds into the open phase while the methodology
holds; a methodology shift closes the phase and opens a new one.

The 1.48.0-1.54.0 phase is retired to the notes, and the 1.55.0-1.56.0,
1.57.0-1.60.0, and 1.61.0-1.62.0 phases are closed, represented by 1.55.0,
1.58.0, and 1.62.0. The **open phase is 1.63.0-**, represented by 1.63.0
(the v1.72.0 tooling and documentation work, the v1.73.0 test-layout
work, and the v1.74.0 script-modularity work fold in without a prove
methodology shift):
that version packed the directory memo again, moved the five pre-build steps
into one concurrent bundle, and gave `just bench` a per-step build-phase
breakdown, so the implementation and the measurement methodology both moved.
The 1.55.0 detail is on [The 1.55.0 timing
re-baseline](prove-rebaseline.md); the whole table is on [Prove timing and the
optimisation review](prove-timing.md).

## CI

CI runs the self-assessment with result caching disabled where determinism matters
(`--no-cache`-equivalent fresh dirs). The `make` gates are timed loosely: timings
are informational only, because a gate that fails on a slow runner helps nobody.
The `bench` target is not part of `just check`; it is run by hand before releases.

## When the numbers regress

Run `just perf-bench` first: it reports the CPU break-down and the strace
syscall counts. The usual suspects are a new tree walk that re-enumerates
a directory a cache already covers, or a new per-file hash that the stamp
fast path does not cover. `just run-ada-crdt` is a handy second datapoint
on a smaller tree.
