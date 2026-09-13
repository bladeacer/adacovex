# Performance

adacovex is a zero-dependency CLI. Its hot path is the assessment pipeline
(scan -> patch -> doc metrics -> proof parse -> test parse -> DAL assess ->
render, plus the SBOM). This page documents how to benchmark it, the
expected numbers on a typical machine, and the optimisations that keep
those numbers low.

## Benchmarking

### Benchmark machine

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
and gnatprove's solver jobs fan out across all of them. Single-threaded
pipeline figures are dominated by P-core behaviour; the prove-cold solver
floor depends on the E-core fleet. Lower-thread machines pay more per
solver run; the warm paths stay warm anywhere.

`make bench` benchmarks the assessment pipeline, the `prove` subcommand,
and reports binary size:

- It builds the project, then times `./bin/adacovex` and
  `./bin/adacovex prove` against the repo itself.
- **Four scenarios** are measured, each with a precise meaning (see the
  category reference below). The prove scenarios time the `prove`
  subcommand -- the true test of proof performance, measured at the
  adacovex-binary level, not just the gnatprove level.
- `make bench` uses [hyperfine](https://github.com/sharkdp/hyperfine) when
  installed; otherwise it falls back to the bash `time` builtin. It samples
  generously so the reported mean is stable: **10 pipeline-cold +
  15 pipeline-warm + 3 prove-cold + 15 prove-warm** repetitions (2 warmups;
  none for prove-cold). Each cold repetition deletes the cache dir first;
  the prove-cold repetitions also delete the gnatprove session store
  (`obj/gnatprove/`). The `time` fallback runs **5 + 5** per scenario.
- It reports the raw and stripped binary sizes (the stripped size is measured
  on a `/tmp` copy; the build output is never modified).

### Benchmark category reference

adacovex has two *caches* and one *build step*; every benchmark category is
defined by which of them are populated:

- the **result cache** (`~/.adacovex/cache/<version>/`, or `--cache-dir`):
  adacovex's own content-addressed store of scan, graph, and prove results;
- the **gnatprove session store** (`<target>/obj/gnatprove/`):
  gnatprove's internal per-unit session, which re-analyses only changed
  units;
- the **build** (`alr build`, run by every `make` recipe that proves): a
  no-op takes ~0.3 s when built; `make clean` forces a full recompile.

| Category | Command | Result cache | gnatprove session | What it measures |
|----------|---------|--------------|-------------------|------------------|
| Pipeline cold | `adacovex --cache-dir=<fresh>` | empty | n/a (not spawned) | Scan, parse, DAL, SBOM, render with no cached results |
| Pipeline warm | `adacovex --cache-dir=<populated>` | hit | n/a | Cache-hit path: startup, walks, blob deserialisation |
| Prove cold | `adacovex prove --no-cache --cache-dir=<fresh>` | empty | **wiped** | Truly cold proving: full solver run + everything in pipeline cold (a first CI invocation on a bare runner) |
| Prove warm | `adacovex prove --cache-dir=<populated>` | hit | n/a | The short-circuit: one content-hash of the inputs, then serve the stored proof (a developer on an unchanged tree) |

Two further shapes exist and are worth recognising (one-time-per-session
states, not steady states, so they are not benchmarked):

- *adacovex-side cold*: `prove --no-cache` with the result cache wiped but
  `obj/gnatprove/` populated. gnatprove's session absorbs the solver cost;
  the run re-does only the adacovex-side work (~1.3 s here) -- what a
  `--cache-dir` change on a built machine costs.
- *partial session*: `obj/gnatprove/` holds only some units (after a
targeted `gnatprove -u` run). A prove miss then re-analyses the missing
units and lands between the two cold shapes. A full `make prove` always
ends with a complete session, so back-to-back runs sit at prove-warm.

### Sample output (hyperfine, x86-64, 12-core machine, 1.47.0)

1.47.0 is the first release compiled with `-O2 -gnatn` (1.46.0 and earlier
used GNAT's default `-O0`). The 1.46.0 figures are kept for comparison;
they were measured in the same session so the load conditions match:

| Scenario | 1.46.0 (`-O0`) | 1.47.0 (`-O2`) |
|----------|----------------|----------------|
| Pipeline cold, self tree | -- | 73.9 +/- 5.8 ms |
| Pipeline warm, self tree | -- | 43.4 +/- 2.8 ms |
| Pipeline cold, Ada_CRDT | 39.3 +/- 4.3 ms | 33.4 +/- 3.5 ms (-15%) |
| Pipeline warm, Ada_CRDT | 38.4 +/- 4.7 ms | 40.8 +/- 4.7 ms (noise) |
| Prove cold, session wiped | -- | 80.9 +/- 5.3 s |
| Prove warm | -- | 52.8 +/- 4.5 ms |
| Stripped binary | 6.49 MiB | 5.39 MiB (-17%) |

The prove-cold figure is solver-bound and machine-load sensitive: repeat
single-shot runs of the identical 1.47.0 tree measured between 67 s and
109 s as background load varied (a matched-load A/B settled at 69.9 s vs
67.3 s; the ~196 s of user CPU stays constant). Treat ~40-110 s as the
observed range; the compiler switches do not move it.

The numbers shift with the machine and the codebase. What matters is the
shape: the warm paths sit in the tens of milliseconds, and the cold paths
are bounded by work that genuinely must happen (hashing the changed
sources, parsing the proof, building the SBOM) -- a from-scratch solver
run happens once per gnatprove session, not once per run.

For single-shot timings, plain `time` over the same commands (`--no-cache`
for cold, `--cache-dir=<populated dir>` for warm, with or without
`prove`) works the same way. When comparing two versions, always reset
the cache between runs so the result cache cannot hide the real cost.

`make perf-bench` profiles CPU and syscalls directly with `perf` and
`strace` over `bin/adacovex`, printing cache-miss rates and syscall counts
so a regression in I/O or data layout is visible before a release.

A second datapoint rides along with every `make bench`: when the Ada_CRDT
dogfood tree (`../Ada_CRDT`) is present, the two pipeline scenarios repeat
against it. It is a smaller target (~80 specs, its own vendored layout and
manifest set), so a regression tied to one project's structure cannot hide
behind the self-assessment numbers. 1.46.0 measured ~39 ms cold / ~31 ms
warm there (the `-O0` baseline); 1.47.0 measures ~33 ms / ~41 ms. The
prove scenarios are not repeated (the solver floor is covered by the self
run).

## What the numbers mean

Figures below are from `make bench`/`perf-bench` on this machine (hyperfine,
cold + warm per scenario, warmups as listed above). They shift with the
machine and the codebase; what matters is the shape:

- **Pipeline cold ~74 ms**: dominated by source scanning (Ada file
  enumeration and SHA-256 of every scanned file), the SBOM tree walk and
  word scan, and the renderers. Nothing here can be skipped: the result
  cache is empty, so every file must be read and hashed at least once
  (tool-version probes and ecosystem-metadata lookups live per-machine,
  outside the result cache, and survive cache wipes).
- **Pipeline warm ~43 ms**: the on-disk result cache skips re-parsing
  unchanged sources; the stamp fast-path skips the per-file SHA-256
  entirely (a file unchanged in size is not re-hashed); the tools-set
  cache skips the SBOM dev-dependency word scan and the tool probes. The
  remaining time is process startup, directory walks, and blob
  deserialization.
- **Prove cold ~40-110 s** (load-dependent on this desktop): a
  from-scratch solver run over 876 VCs plus the whole pipeline, dominated
  by gnatprove itself (the ~196 s of user CPU across the proof jobs is
  the stable part) and paid once per gnatprove session, not per run.
- **Prove warm ~53 ms**: the prove result cache serves the stored proof
  after one content-hash of the input tree, and restores the cached
  `gnatprove.out` so the assessment parses it -- the number a developer
  hits on an unchanged tree. Back-to-back `make prove` runs sit here (the
  adacovex run is ~0.05 s; the rest of the wall is `alr build`).
- System time is the tell: ~22 ms on pipeline cold (file I/O), ~14 ms on
  pipeline warm.

The detailed `make prove` timing table is on [Prove timing and the
optimisation review](perf-prove-timing.md); the reverse-chronological
record of the optimisations behind these numbers, including the 1.47.0
buffered request reader on the serve path, is on [Performance
optimisation history](perf-optimisation-history.md).

## Probe cache

*(Origin story.)* The SBOM builds a *dev-scope* dependency edge for every
tool that the target's build references, installed on `$PATH` (for
example `gcc`, `alr`, `git`, `make`). It probes each with `<tool> <flag>`
to capture its version, and each probe spawns a subprocess (tens of
milliseconds per tool, ~150 ms end to end on an 11-tool toolchain). The
probed versions were first cached under `<cache-root>/probes/<tool>` with
a 7-day TTL, so a wiped result cache re-probed every tool on the next
run -- 1.28.0 moved the store into the tools-set cache blob.

## The serve dashboard API

The `--serve` endpoints were benchmarked with hyperfine over curl on the
same machine (local loopback, 4-worker server, one curl process per
request):

| Endpoint | Mean | Notes |
|----------|------|-------|
| `GET /api/metrics` | ~6-7 ms | JSON, ~0.5 KB response |
| `GET /` | ~10-13 ms | HTML, ~245 KB response |
| `GET /docs/` | ~5 ms | gzip manual page, ~6 KB response |

The numbers are dominated by curl's own process startup and connection
cycle (its strace shows ~390 syscalls per invocation, nearly all dynamic
loader `mmap`/`openat` work), so keep-alive client libraries see far lower
per-request costs. The server-side share is small: the JSON endpoints
serialise in-process data (microseconds of CPU), and the dashboard page is
rebuilt per request from the immutable assessment state.  1.47.0 removed
the largest server-side syscall cost: the request reader used to pull one
byte per `Receive_Socket` call, ~300 receive syscalls per request; it now
fills a 4 KiB per-connection buffer per receive and hands out complete
CRLF lines from it.

### Concurrent load (keep-alive clients, 20 s runs)

`tools/load_test.py` (pure-stdlib asyncio) streams sequential keep-alive
GETs from N parallel client connections, so the 4-worker pool is the
capacity being measured:

| Scenario | Throughput | Latency p50 / p99 |
|----------|-----------|-------------------|
| `/api/metrics`, 1 client | ~45k req/s | 0.02 / 0.07 ms |
| `/api/metrics`, 4 clients | ~94k req/s | 0.04 / 0.14 ms |
| `/api/metrics`, 16 clients | ~84k req/s | 0.04 / 0.15 ms |
| `/badge/spark.svg`, 8 clients | ~97k req/s | 0.03 / 0.13 ms |
| `/`, 4 clients | ~530 req/s | 6.3 / 13.6 ms |
| `/docs/`, 4 clients | ~97 req/s | 41 / 43 ms |

JSON and badge endpoints scale near-linearly to the worker count (4
requests in flight = 4 workers saturated) and hold ~84-97k req/s with 16
clients, because extra clients queue in the accept backlog instead of
consuming server resources. Tail latency stays sub-millisecond; the ~4 s
max above the worker count is a load-generator deadline artifact (one
straggler request per connection at the cutoff), not server behaviour.
`perf stat` under load shows no cache-miss or IPC anomaly; `strace -c`
splits the request cost evenly between `recvfrom` and `sendto` at ~16 us
each, with `futex` (worker parking) leading wall clock only because the
load is light for four workers. The dashboard page (~245 KB rendered per
request) and the manual index are throughput-bound on response assembly
and socket copies; both hold flat latency under load. Capacity is far
above single-operator needs; `--serve-workers=N` raises the pool.

## Binary size

The debug-symbol-carrying build is ~14.0 MiB at `-O2` (it was ~11.6 MiB at
the `-O0` default; optimisation unrolls and inlines, which costs binary
size in the symbol-carrying build). Stripping (`strip bin/adacovex`) yields
~5.4 MiB (~62% smaller, ~17% smaller than 1.46.0's stripped ~6.5 MiB)
without affecting behaviour. GNAT keeps symbols by default for debugging;
release artifacts are stripped. `make bench` reports both, so a size
regression is visible in the same command as the timings.

## CI

CI runs the self-assessment with result caching disabled where determinism matters
(`--no-cache`-equivalent fresh dirs). The `make` gates are timed loosely: timings
are informational only, because a gate that fails on a slow runner helps nobody.
The `bench` target is not part of `make check`; it is run by hand before releases.

## When the numbers regress

Run `make perf-bench` first: it reports the CPU break-down and the strace
syscall counts. The usual suspects are a new tree walk that re-enumerates
a directory a cache already covers, or a new per-file hash that the stamp
fast path does not cover. `make run-ada-crdt` is a handy second datapoint
on a smaller tree.
