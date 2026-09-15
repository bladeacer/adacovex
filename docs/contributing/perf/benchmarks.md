# Benchmarking adacovex

This page documents how to benchmark the pipeline and the `prove`
subcommand, the benchmark machine, and the raw sample output.  The
benchmark categories and the expected numbers are on
[Performance](index.md).

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

## Sample output (hyperfine, x86-64, 12-core machine)

1.47.0 is the first release compiled with `-O2 -gnatn` (1.46.0 and earlier
used GNAT's default `-O0`).  The 1.46.0 figures are kept for comparison;
they were measured in the same session so the load conditions match.  The
1.50.0 column was measured on a later session, so read it for shape, not
for a millisecond-level A/B against 1.47.0:

| Scenario | 1.46.0 (`-O0`) | 1.47.0 (`-O2`) | 1.50.0 |
|----------|-----------------|----------------|--------|
| Pipeline cold, self tree | -- | 73.9 +/- 5.8 ms | 73.2 +/- 5.3 ms |
| Pipeline warm, self tree | -- | 43.4 +/- 2.8 ms | 46.3 +/- 4.0 ms |
| Pipeline cold, Ada_CRDT | 39.3 +/- 4.3 ms | 33.4 +/- 3.5 ms (-15%) | 42.7 +/- 13.1 ms |
| Pipeline warm, Ada_CRDT | 38.4 +/- 4.7 ms | 40.8 +/- 4.7 ms (noise) | 31.6 +/- 2.9 ms |
| Prove cold, session wiped | -- | 80.9 +/- 5.3 s | 87.6 +/- 0.6 s |
| Prove warm | -- | 52.8 +/- 4.5 ms | 55.4 +/- 4.3 ms |
| Stripped binary | 6.49 MiB | 5.39 MiB (-17%) | 5.7 MiB |

The 1.50.0 shapes are deliberately flat: the phase's work removes failed
work (a rewrite of the generated manual, a recompile and relink, and a
re-proved tree), not steady work.  The headline 1.50.0 number is therefore
not in this table: `make prove` on an unchanged tree measures ~1.0 s (five
runs), because `alr build` is now a true no-op instead of recompiling the
28k-line generated manual on every run.

The prove-cold figure is solver-bound and machine-load sensitive: repeat
single-shot runs of the identical 1.47.0 tree measured between 67 s and
109 s as background load varied (a matched-load A/B settled at 69.9 s vs
67.3 s).  The 1.50.0 tree behaves the same way (single shots of 61 s and
67 s against a three-run sample of 87.6 s).  Treat ~40-110 s as the
observed range; the compiler switches do not move it.

The numbers shift with the machine and the codebase.  What matters is the
shape: the warm paths sit in the tens of milliseconds, and the cold paths
are bounded by work that genuinely must happen (hashing the changed
sources, parsing the proof, building the SBOM) -- a from-scratch solver
run happens once per gnatprove session, not once per run.

## Running a single shot

For single-shot timings, plain `time` over the same commands (`--no-cache`
for cold, `--cache-dir=<populated dir>` for warm, with or without
`prove`) works the same way.  When comparing two versions, always reset
the cache between runs so the result cache cannot hide the real cost.

`make perf-bench` profiles CPU and syscalls directly with `perf` and
`strace` over `bin/adacovex`, printing cache-miss rates and syscall counts
so a regression in I/O or data layout is visible before a release.

A second datapoint rides along with every `make bench`: when the Ada_CRDT
dogfood tree (`../Ada_CRDT`) is present, the two pipeline scenarios repeat
against it.  It is a smaller target (~80 specs, its own vendored layout and
manifest set), so a regression tied to one project's structure cannot hide
behind the self-assessment numbers.  1.46.0 measured ~39 ms cold / ~31 ms
warm there (the `-O0` baseline); 1.47.0 measures ~33 ms / ~41 ms and 1.50.0
~43 ms / ~32 ms (the 1.50.0 cold sample is noisy, one 80 ms first run).
The prove scenarios are not repeated (the solver floor is covered by the
self run).

## Binary size

The debug-symbol-carrying build is ~14.3 MiB at `-O2` on the 1.50.0 tree
(it was ~11.6 MiB at the `-O0` default; optimisation unrolls and inlines,
which costs binary size in the symbol-carrying build).  Stripping (`strip
bin/adacovex`) yields ~5.7 MiB (~60% smaller, comparable with 1.47.0's
~5.4 MiB and ~17% smaller than 1.46.0's stripped ~6.5 MiB) without
affecting behaviour.  GNAT keeps symbols by default for debugging;
release artifacts are stripped.  `make bench` reports both, so a size
regression is visible in the same command as the timings.

### Bundled offline manual

The offline manual is the largest single payload in the binary, so it was
measured on the 1.50.0 tree through the generator's own pipeline.  The
bundled site holds 206 assets (about 6.66 MB of source); gzip compresses it
to about 1.47 MB, and the base64 Ada source carries about 1.96 MB, about
33% of the 5.68 MiB stripped binary.  No two assets share their content, so
the payload is already dense.

The figures are rounded, because this page is itself a bundled asset: an
edit here shifts the payload by well under one percent.  The shares below
are the stable part of the measurement, and each is rounded to 0.1%.

| Group | Assets | gzip size | Share |
|-------|--------|-----------|-------|
| Changelogs (history) | 52 | 450 kB | 30.6% |
| API reference (generated) | 75 | 427 kB | 29.0% |
| Contributing pages | 24 | 202 kB | 13.7% |
| Usage pages | 18 | 161 kB | 10.9% |
| Search index | 1 | 95 kB | 6.5% |
| Root, theme, compliance, proof, badges | 36 | 138 kB | 9.4% |

The generator compresses each asset on its own, because the server sends one
asset per URL with its own `Content-Encoding: gzip` header.  The LZ4
comparison used the same basis: `lz4 -9` gives about 1.93 MB, about 31% more
than gzip, and the Ada runtime has no LZ4 decompressor.  A single shared
stream would compress better (about 0.97 MB for the whole site), but one
stream cannot be cut into independently decodable per-URL bodies.

Three shrink options were measured and rejected.

- **base85 instead of base64**: about 0.12 MB saved (about 6% of the
  payload, about 2% of the stripped binary).  This needs a new hand-written
  decoder and a new generator encoding for a two-percent gain.
- **A stronger compressor (brotli or zstd class, about 15% smaller)**: about
  0.29 MB saved, but the compression runs at build time and the Pure
  Python tools must stay stdlib-only (brotli is not in the standard
  library).  A browser can inflate brotli, but the build dependency breaks
  the zero-dependency tooling rule.
- **Dropping the changelog history (30.6%) or the generated API reference
  (29.0%)**: the only large reductions available, but Sphinx's search index
  covers every page, so a removed page leaves a clickable search result that
  leads nowhere offline.  Stale cross-links would also need rewriting to an
  absolute site URL.

The bundle therefore stays as it is: gzip-max compression, base64 in the Ada
source, and a fully working offline manual with search.  Re-measure here
before adding a page family to the tree.

## Probe cache

*(Origin story.)* The SBOM builds a *dev-scope* dependency edge for every
tool that the target's build references, installed on `$PATH` (for
example `gcc`, `alr`, `git`, `make`).  It probes each with `<tool> <flag>`
to capture its version, and each probe spawns a subprocess (tens of
milliseconds per tool, ~150 ms end to end on an 11-tool toolchain).  The
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
per-request costs.  The server-side share is small: the JSON endpoints
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
consuming server resources.  Tail latency stays sub-millisecond; the ~4 s
max above the worker count is a load-generator deadline artifact (one
straggler request per connection at the cutoff), not server behaviour.
`perf stat` under load shows no cache-miss or IPC anomaly; `strace -c`
splits the request cost evenly between `recvfrom` and `sendto` at ~16 us
each, with `futex` (worker parking) leading wall clock only because the
load is light for four workers.  The dashboard page (~245 KB rendered per
request) and the manual index are throughput-bound on response assembly
and socket copies; both hold flat latency under load.  Capacity is far
above single-operator needs; `--serve-workers=N` raises the pool.
