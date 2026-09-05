# Performance

adacovex is a zero-dependency CLI. Its hot path is the assessment pipeline
(scan -> patch -> doc metrics -> proof parse -> test parse -> DAL assess ->
render, plus the SBOM). This page documents how to benchmark it. It also
documents the expected numbers on a typical machine and the optimisations
that keep those numbers low.

## Benchmarking

### Benchmark machine

Every figure in this document was measured on the adacovex development
machine. Only the specs that plausibly affect a CLI benchmark are listed;
the GPU(s) are omitted on purpose (adacovex is CPU/I/O-bound; no code path
touches a GPU):

| Component | Spec |
|-----------|------|
| OS | EndeavourOS x86_64, Linux 7.2.2-arch1-1 |
| CPU | 12th Gen Intel Core i7-1255U (4P+8E, 12 threads) @ 4.70 GHz max |
| L1 cache | 8x32 KiB data + 8x64 KiB instruction (P-cores); 2x48 KiB data + 2x32 KiB instruction (E-cores) |
| L2 cache | 2x2.0 MiB + 2x1.25 MiB |
| L3 cache | 12 MiB shared |
| Memory | 16 GiB DDR4 (15.33 GiB visible) |
| Storage | SK hynix BC711 512 GiB NVMe SSD |
| Toolchain | gnatprove 16.1.0 (via Alire), hyperfine 1.20, perf 7.2, strace 7.0 |

The i7-1255U is a hybrid laptop part: 10 of the 12 threads are E-cores,
and gnatprove's solver jobs fan out across all of them. Single-threaded
pipeline figures (warm/cold) are dominated by P-core behaviour; the
prove-cold solver floor depends on the E-core fleet. Lower-thread
machines pay more per solver run; the warm paths (tens of ms) stay warm
anywhere.

`make bench` benchmarks the assessment pipeline, the `prove` subcommand,
and reports binary size:

- It builds the project, then times `./bin/adacovex` and
  `./bin/adacovex prove` against the repo itself.
- **Four scenarios** are measured, and each has a precise meaning (see the
  category reference below). The pipeline scenarios time the assessment
  path; the prove scenarios time the `prove` subcommand -- the true test of
  proof performance, measured at the adacovex-binary level, not just the
  gnatprove level.
- `make bench` uses [hyperfine](https://github.com/sharkdp/hyperfine) when
  installed. It falls back to the bash `time` builtin otherwise. No tooling is
  required.
- It samples generously so the reported mean is stable. Hyperfine runs **10
  pipeline-cold + 15 pipeline-warm + 3 prove-cold + 15 prove-warm**
  repetitions (2 warmup runs; none for prove-cold, where every repetition
  is expensive by construction). Each cold repetition deletes the cache dir
  first; the prove-cold repetitions also delete the gnatprove session store
  (`obj/gnatprove/`). The `time` fallback runs **5 + 5** per scenario.
- It reports the raw and stripped binary sizes (the stripped size is measured
  on a `/tmp` copy; the build output is never modified).

### Benchmark category reference

adacovex has two *caches* and one *build step*, and every benchmark
category is defined by which of them are populated:

- the **result cache** (`~/.adacovex/cache/<version>/`, or `--cache-dir`):
  adacovex's own content-addressed store of scan, graph, and prove
  results;
- the **gnatprove session store** (`<target>/obj/gnatprove/`): gnatprove's
  internal per-unit session, which re-analyses only changed units;
- the **build** (`alr build`, run by every `make` recipe that proves): a
  no-op takes ~0.3 s when the tree is built; `make clean` forces a full
  recompile.

| Category | Command | Result cache | gnatprove session | What it measures |
|----------|---------|--------------|-------------------|------------------|
| Pipeline cold | `adacovex --cache-dir=<fresh>` | empty | n/a (not spawned) | Scan, parse, DAL, SBOM, render with no cached results |
| Pipeline warm | `adacovex --cache-dir=<populated>` | hit | n/a | Cache-hit path: startup, walks, blob deserialisation |
| Prove cold | `adacovex prove --no-cache --cache-dir=<fresh>` | empty | **wiped** | Truly cold proving: full solver run + everything in pipeline cold. The shape a first CI invocation on a bare runner sees |
| Prove warm | `adacovex prove --cache-dir=<populated>` | hit | n/a | The short-circuit: one content-hash of the inputs, then serve the stored proof. The number a developer hits on an unchanged tree |

Two further shapes exist and are worth recognising (they are *not*
benchmarked because they are one-time-per-session states, not steady
states):

- *adacovex-side cold*: `prove --no-cache` with the result cache wiped but
  `obj/gnatprove/` populated. gnatprove's session absorbs the solver cost;
  the run re-does only the adacovex-side work (~1.3 s here). This is what
  a `--cache-dir` change on a built machine costs.
- *partial session*: `obj/gnatprove/` holds only some units (for example
  after a targeted `gnatprove -u` run). A prove miss then re-analyses the
  missing units and lands anywhere between the two cold shapes -- the
  0.02 s / 5.47 s alternation reported on this machine came from exactly
  this state. A full `make prove` always ends with a complete session, so
  back-to-back `make prove` runs are stable at the prove-warm shape.

### Sample output (hyperfine, x86-64, 12-core machine, 1.46.0)

```
=== Pipeline cold (fresh result cache) ===
  Time (mean +/- sigma):  87.6 ms +/- 4.6 ms    [User: 61.6 ms, System: 15.4 ms]
  Range (min ... max):    81.7 ms ... 97.4 ms   10 runs

=== Pipeline warm (populated caches) ===
  Time (mean +/- sigma):  40.7 ms +/- 3.8 ms    [User: 16.7 ms, System: 13.5 ms]
  Range (min ... max):    36.1 ms ... 47.5 ms   15 runs

=== Prove cold (--no-cache, result cache + gnatprove session wiped) ===
  Time (mean +/- sigma):  37.349 s +/- 1.479 s   [User: 195.612 s, System: 11.331 s]
  Range (min ... max):    35.642 s ... 38.232 s   3 runs

=== Prove warm (populated prove cache) ===
  Time (mean +/- sigma):  45.9 ms +/- 3.1 ms    [User: 19.8 ms, System: 15.8 ms]
  Range (min ... max):    40.5 ms ... 51.9 ms   15 runs

== Binary size ==
bin/adacovex            11.6 MiB (12171168 bytes)
after strip             6.5 MiB (6789496 bytes)
savings                 44.2%
```

The numbers shift with the machine and the codebase. What matters is the
shape: the warm paths (pipeline and prove) sit in the tens of
milliseconds, and the cold paths are bounded by work that genuinely must
happen (hashing the changed sources, parsing the proof, building the SBOM)
-- a from-scratch solver run happens once per gnatprove session, not once
per run.

For single-shot timings, plain `time` works the same way:

```bash
time ./bin/adacovex --no-cache          # pipeline cold, no result cache
time ./bin/adacovex --cache-dir=/tmp/c  # pipeline warm
time ./bin/covex prove                  # prove warm (short-circuit)
time ./bin/covex prove --no-cache       # prove cold (session intact)
```

When you compare two versions, always reset the cache between runs. Use
`--cache-dir=<fresh dir>` or delete the cache dir. The result cache must not
hide the real cost.

`make perf-bench` profiles CPU and syscalls directly with `perf` and
`strace` over `bin/adacovex`. It prints the cache-miss rates and the syscall
counts so a regression in I/O or data layout is visible before a release.
For a prove-path profile, point it at the same command `make bench` times:
`strace -c -f ./bin/covex prove --no-cache --cache-dir=/tmp/aperf` shows the
per-syscall breakdown of the adacovex-side cold run.

A second datapoint rides along with every `make bench`: when the Ada_CRDT
dogfood tree (`../Ada_CRDT`) is present, the two pipeline scenarios repeat
against it. It is a smaller target (~80 specs, its own vendored layout and
manifest set), so a regression tied to one project's structure cannot hide
behind the self-assessment numbers. On 1.46.0 that tree measured ~39 ms
cold / ~31 ms warm -- the same I/O-bound shape at roughly half the self
tree's size. The prove scenarios are not repeated there; the solver floor
is already covered by the self run.

## What the numbers mean

Figures below are from `make bench`/`perf-bench` on this machine (hyperfine,
cold + warm per scenario, warmups as listed above). They shift with the
machine and the codebase. What matters is the shape:

- **Pipeline cold ~88 ms**: dominated by source scanning (Ada file
  enumeration and SHA-256 of every scanned file), the SBOM tree walk and
  word scan, and the renderers. Nothing here can be skipped: the result
  cache is empty, so every file must be read and hashed at least once. The
  system-tool version probes and the ecosystem-metadata registry lookups
  are *not* part of cold anymore (both live per-machine, outside the result
  cache, and are cached across cache wipes).
- **Pipeline warm ~41 ms**: the on-disk result cache (content-addressed per
  file, oldest-first eviction) skips re-parsing unchanged sources. The
  stamp fast-path skips the per-file SHA-256 entirely (a file unchanged in
  size is not re-hashed). The tools-set cache skips the whole SBOM
  dev-dependency word scan and the tool probes for an unchanged project.
  The remaining time is process startup (dynamic loader hwcaps probing,
  elaboration), the directory walks, and the blob deserialization.
- **Prove cold ~37.3 s**: a from-scratch solver run over 876 VCs plus the
  whole pipeline. This is dominated by gnatprove itself (note the ~196 s
  of user CPU across the proof jobs) and is paid once per gnatprove
  session, not per run.
- **Prove warm ~46 ms**: the prove result cache serves the stored proof
  after one content-hash of the input tree, and restores the cached
  `gnatprove.out` so the assessment parses it. This is the number a
  developer hits on an unchanged tree, and the one the perf targets below
  refer to.  Back-to-back `make prove` runs sit here (measured: 20
  consecutive runs, max 2.9 s wall for `make prove` including the ~2.5 s
  `alr build`; the adacovex run itself is ~0.04 s).
- System time is the tell. Pipeline cold runs show ~16 ms of system time
  (file I/O); pipeline warm runs show ~10 ms.

The detailed `make prove` timing table -- the seven-tree comparison,
per-version notes, and the 1.46.0 SIMD and optimisation-candidate review
-- is on [Prove timing and the optimisation review](perf-prove-timing.md).
The reverse-chronological record of the optimisations behind these numbers
is on [Performance optimisation history](perf-optimisation-history.md).

## Probe cache

*(Origin story.)* The SBOM builds a *dev-scope* dependency edge for every tool that the
target's build references. The tool must be installed on `$PATH` (for example `gcc`, `alr`, `git`, `make`). The SBOM probes each tool with `<tool> <flag>` to capture its version. Each probe spawns a subprocess.

The subprocess costs tens of milliseconds per referenced tool (`System: 42 ms -> 9 ms`, ~150 ms end to end on an 11-tool toolchain). Originally the probed versions were cached under `<cache-root>/probes/<tool>` with a 7-day TTL. That location meant a wiped result cache re-probed every tool on the next run -- which is why 1.28.0 moved the store and folded the probe results into the tools-set cache blob (see above).

## Binary size

The debug-symbol-carrying build is ~11.6 MiB. Stripping (`strip bin/adacovex`) yields ~6.5 MiB (~44% smaller) without affecting behaviour. GNAT's default build keeps symbols for debugging (`gdb` works). Release artifacts are stripped. `make bench` always reports both.

Regressions in code size are visible in the same command that reports timings. If the symbols ever come out, the binary size is the same and the page should say so.

## CI

CI runs the self-assessment with result caching disabled where determinism matters (`--no-cache`-equivalent fresh dirs). The `make` gates are timed loosely. Timings are informational only. The `bench` target is not part of `make check`.

It makes the gate machine-dependent. A slow CI runner must not fail a build. The target is run by hand before releases.

## When the numbers regress

Run `make perf-bench` first. It reports the CPU break-down (the wall-clock
`perf` output) and the strace syscall counts. The single-reader/single-writer
cache walks are the usual suspects: a new tree walk that re-enumerates a
directory which a cache already covers, or a new per-file hash that the
stamp fast path does not cover. The numbers in this page are from the
self-assessment; the Ada_CRDT target is smaller and exercises the same
pipeline, so `make run-ada-crdt` is a handy second datapoint.
