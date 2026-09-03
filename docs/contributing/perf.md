# Performance

adacovex is a zero-dependency CLI. Its hot path is the assessment pipeline
(scan -> patch -> doc metrics -> proof parse -> test parse -> DAL assess ->
render, plus the SBOM). This page documents how to benchmark it. It also
documents the expected numbers on a typical machine and the optimisations
that keep those numbers low.

## Benchmarking

`make bench` benchmarks the assessment pipeline, the `prove` subcommand,
and reports binary size:

- It builds the project, then times `./bin/adacovex` and
  `./bin/adacovex prove` against the repo itself.
- **cold** runs (fresh result cache + probe cache) and **warm** runs
  (populated caches) are measured separately for both the pipeline and the
  prove subcommand. The prove cold scenario is `prove --no-cache` against a
  fresh cache dir; the prove warm scenario is `prove` with the cache
  populated. The four scenarios together are the true performance test:
  the pipeline numbers cover the assessment path, and the prove numbers
  cover the adacovex-side proving path (input-hash walk, proof parse,
  SBOM) at the binary level -- not just the gnatprove level.
- `make bench` uses [hyperfine](https://github.com/sharkdp/hyperfine) when
  installed. It falls back to the bash `time` builtin otherwise. No tooling is
  required.
- It samples generously so the reported mean is stable. Hyperfine runs **10
  pipeline-cold + 15 pipeline-warm + 10 prove-cold + 15 prove-warm**
  repetitions (2 warmup runs; 1 for the prove-cold scenario). Each cold
  repetition deletes the cache dir first. This measures a truly empty result
  and probe cache. The `time` fallback runs **5 + 5** per scenario.
- It reports the raw and stripped binary sizes (the stripped size is measured
  on a `/tmp` copy; the build output is never modified).

Example output (hyperfine, x86-64, 12-core machine, 1.42.0):

```
=== Pipeline cold (fresh result cache) ===
  Time (mean +/- sigma):  93.0 ms +/- 3.7 ms    [User: 62.9 ms, System: 19.6 ms]
  Range (min ... max):    87.7 ms ... 99.7 ms   10 runs

=== Pipeline warm (populated caches) ===
  Time (mean +/- sigma):  43.1 ms +/- 3.4 ms    [User: 18.1 ms, System: 14.3 ms]
  Range (min ... max):    37.7 ms ... 48.5 ms   15 runs

=== Prove cold (--no-cache, fresh result cache) ===
  Time (mean +/- sigma):  1.346 s +/- 0.041 s   [User: 1.569 s, System: 0.192 s]
  Range (min ... max):    1.298 s ... 1.424 s   10 runs

=== Prove warm (populated prove cache) ===
  Time (mean +/- sigma):  50.7 ms +/- 6.0 ms    [User: 22.6 ms, System: 17.5 ms]
  Range (min ... max):    42.0 ms ... 62.5 ms   15 runs

== Binary size ==
bin/adacovex            11.1 MiB (11689888 bytes)
after strip             6.1 MiB (6372600 bytes)
savings                 45.5%
```

The prove-cold number is stable only because the gnatprove session store
(`obj/gnatprove/`, gnatprove's own cache) survives the wipe: it measures the
adacovex-side cold cost. A run where the session store is *also* wiped -- a
first CI run on a bare runner, or `rm -rf obj/gnatprove` locally -- pays a
from-scratch solver run and lands in the tens of seconds; it is a one-time
cost per session, not a per-run property, so `make bench` does not sample it.
See the `make prove` section below for both shapes.

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

## What the numbers mean

Figures below are from `make bench`/`perf-bench` on this machine (hyperfine,
cold + warm per scenario, warmups as listed above). They shift with the
machine and the codebase. What matters is the shape:

- **Pipeline cold ~0.1 s**: dominated by source scanning (Ada file
  enumeration and SHA-256 of every scanned file), the SBOM tree walk and
  word scan, and the renderers. Nothing here can be skipped: the result
  cache is empty, so every file must be read and hashed at least once. The
  system-tool version probes and the ecosystem-metadata registry lookups
  are *not* part of cold anymore (both live per-machine, outside the result
  cache, and are cached across cache wipes).
- **Pipeline warm ~43 ms**: the on-disk result cache (content-addressed per
  file, oldest-first eviction) skips re-parsing unchanged sources. The
  stamp fast-path skips the per-file SHA-256 entirely (a file unchanged in
  size is not re-hashed). The tools-set cache skips the whole SBOM
  dev-dependency word scan and the tool probes for an unchanged project.
  The remaining time is process startup (dynamic loader hwcaps probing,
  elaboration), the directory walks, and the blob deserialization.
- **Prove cold (--no-cache) ~1.3 s**: the prove-input hash walk (every
  `.ads`/`.adb` under the target, one stat per entry), the proof-parse of
  `gnatprove.out`, the full pipeline re-run (the prove path runs the
  assessment too), and the SBOM. The gnatprove session store absorbs the
  solver cost, so this is the adacovex-side cold cost; the strace profile
  shows ~30k `newfstatat` and ~6k `openat` calls for the whole run.
- **Prove warm ~51 ms**: the prove result cache serves the stored proof
  after one content-hash of the input tree. This is the number a developer
  hits on an unchanged tree, and the one the perf targets below refer to.
- System time is the tell. Pipeline cold runs show ~20 ms of system time
  (file I/O); pipeline warm runs show ~14 ms.

## `make prove` timing (the true proof-performance test)

The true test of proof performance is the `prove` subcommand --
`./bin/covex prove` -- measured at the adacovex-binary level, not just at
the gnatprove level. Two cold shapes exist, and both are documented so a
number is never read as the wrong thing:

- `./bin/covex prove` (result cache populated) is the warm short-circuit.
- `./bin/covex prove --no-cache` (fresh result cache) is the adacovex-side
  cold run; the gnatprove session store stays populated.
- `./bin/covex prove --no-cache` with `obj/gnatprove/` *also* wiped is the
  fully cold run a first CI invocation sees: a from-scratch solver run.

`make bench` samples the first two shapes with hyperfine; the third is a
one-time-per-session cost reported here for reference.

Measured across the last three trees (gnatprove 16.1.0, 12 logical cores,
10 proof jobs; the 1.42.0 column is the hyperfine output above):

| Scenario | 1.40.0 | 1.41.0 | 1.42.0 |
|----------|--------|--------|--------|
| Prove warm (result-cache short-circuit) | 1.6 s | 2.5 s | 51 ms |
| Prove cold `--no-cache`, session intact | ~40 s* | ~43 s* | 1.3 s |
| Prove fully cold (session also wiped) | 39.0 s / 725 VCs | 42.8 s / 791 VCs | 42.2 s / 876 VCs |

\* The 1.40.0/1.41.0 rows mixed the shapes: the reported "cold" numbers
were dominated by from-scratch gnatprove runs, because the metadata and
probe stores lived under the result cache and every wipe re-probed the
toolchain. The 1.42.0 row separates them.

Reading the table:

- The warm short-circuit dropped from seconds to ~51 ms: the 1.41.0 stamp
  map plus the 1.42.0 walk-skip sets (the 1.40.0/1.41.0 "idle" runs of
  1.6-2.5 s were dominated by the per-run `.gpr` walk enumerating `.venv`).
- The adacovex-side cold run is ~1.3 s: the input-hash walk, the proof
  parse, the pipeline re-run, and the SBOM. The 1.41.0 profile put 66% of
  cold CPU inside spawned `node`/`python` interpreters (ecosystem-metadata
  registry lookups under the result cache); moving the store to
  `~/.adacovex/meta/` is what removed the ~4 s of re-probes from this row.
- The fully cold row is gnatprove's own cost and tracks the VC count:
  42.2 s at 876 VCs on a wiped `obj/gnatprove/` (the +85 VCs over 1.41.0
  are the proved multi-pair IR slice, see [ir.md](ir.md)). It is paid once
  per session, not per run; gnatprove's session store re-analyses only the
  changed unit and its dependents afterwards (roughly 6-9 s wall for a
  body-only edit on this machine).

CPU use stays bounded on developer machines: the default job count is
`cores - 2` (all cores inside CI), so gnatprove never starves the desktop.

## Optimisation history

Kept in reverse-chronological order.  Every entry names the measurement that
drove it so the next round of work can see whether the previous assumption
still holds.

### Cache I/O block copies + walk-skip set completion (1.42.0)

The strace profile showed the warm assessment run making ~218k `newfstatat`
calls in 1.41.0. Three walks were the culprits, and all three missed the
`.venv`/`node_modules`/installer-tree skip set that the SBOM walk already
had: the per-run `.gpr` collection walk (which runs *before* the cached-graph
lookup, so it was paid warm and cold), the vendored-component discovery
walk, and the prove-input hash walk. Completing their skip sets dropped the
warm syscall count to ~15k (14.8x) and the warm wall time from ~104 ms to
~43 ms. The same skip sets cut the prove-side cold walk: a
`prove --no-cache` run now costs ~1.3 s (from ~4.5 s before the skip-set
fix, both with the gnatprove session intact), and its strace profile shows
~30k `newfstatat` / ~6k `openat` calls where the 1.41.0 walk enumerated the
`.venv` installer/doc trees on every prove run.

Two cache-layer changes cut the remaining I/O cost:

- `Store`/`Load` copied every cached blob byte-by-byte through
  `Ada.Streams.Stream_Element` conversion loops. Both now build one
  `Stream_Element_Array` and issue a single `Write`/`Read` (the allocator
  copies once, the kernel transfers once).
- The `Exists` + `Size` double stat in `Load` collapsed into the single
  stat that `Open` already needs, and the per-file hash fast path keeps a
  size-stamped digest map so an unchanged file is never opened twice in
  one run.

Ecosystem-metadata resolution (the `npm view`/`pip index`/`cargo search`
registry spawns that fill licence/website fields on a fully cold run) now
lives in `~/.adacovex/meta/`, beside the probe store: wiping the result
cache no longer re-spawns 13 interpreter boots (~4 s). The perf profile of
1.41.0 showed 66% of cold CPU inside `node` and 17% inside `python` --
adacovex's own code was ~3%; the rest was subprocess interpreters.

### Result-cache stamp map + CPU detection fixes (1.41.0)

The warm-path stamp fast path never fired: the lookup compared the stored
full fixed-size name buffer (2048 chars) against the real path, so the
lengths never matched and every file was re-read and re-hashed on every
run. The map is now open-addressed on a 32-bit FNV-1a hash of the path
(probes one or two slots instead of scanning the map), with the compact
scalar arrays (hash, size, length) probed first and the name buffer touched
only when all three scalars match. `Stamp_Hits` / `Stamp_Misses` counters
make a silent fast-path regression visible in tests and diagnostics, and a
new Result-cache test category (21 tests) pins the behaviour.

The CPU-count probe now memoises its result for the process: `make prove`
and `adacovex status` called `Detect_Core_Count` repeatedly, re-reading
`/proc/cpuinfo` every time. Python virtual environments (`.venv`) were also
excluded from the SBOM and source walks, so a virtualenv of thousands of
files is never enumerated -- the `requirements*.txt` file is the source of
truth for the Python dependency graph.

### Stamp fast-path hashing (1.28.0)

The warm-path profile showed GNAT. SHA256 at ~48% of CPU: every `.ads` file was fully re-read and re-hashed on every run just to compute its cache key, even though the content was unchanged. `Hash_File` now keeps an in-memory map of path -> (size, digest). A file whose size still matches the recorded size serves the recorded digest without opening or reading the file. The fast path is used only within one process (the map is not persisted), so a content change is always caught (the size differs or the map is empty).

The same fast path serves the SBOM tree-walk hashing, which re-hashes files the source scan already touched in the same run (the two hash passes collapse into one real read + one size check). Warm user time dropped roughly a third.

### Stable probe store + probe results in the tools blob (1.28.0)

The cold profile was dominated by the system-tool version probes: each
spawns a subprocess, and node/hg/mandb boot an interpreter (hg alone cost
~330 ms on this machine; the full probe set ~150 ms end to end). The
probes were kept under the *result* cache (`<cache-dir>/probes/`), so
wiping the cache (or pointing `--cache-dir` elsewhere) re-probed every
tool.

Two changes removed that cost:

- Probes now live in `~/.adacovex/probes/` -- a stable, machine-level
  store external to the result cache. Wiping the result cache (or using a
  fresh `--cache-dir`) no longer re-probes; only the 7-day TTL ever
  re-probes a known toolchain. Cold on a warm-probe machine dropped from
  ~658 ms to ~86 ms (7.7 x).
- The tools-set cache blob now also stores each referenced tool's probe
  result (`tool=version` pairs), and a cache hit rebuilds the SBOM tool
  edges from those pairs without PATH lookups, probe file reads, or
  subprocess spawns. Warm dropped from ~39.8 ms to ~34.6 ms. The blob
  format is names-`|`-version-pairs; `Cache_Schema` was bumped to s6 so
  old names-only blobs are never served as if complete. Cold and warm
  SBOM output stays byte-identical.

### File-stamp fast-path and eviction batching (1.27.0)

`Put_Cached` ran eviction after every store; eviction walks the whole cache
tree. It now runs every 32 stores (bounded overshoot under the soft cap).
The SBOM dev-dependency word scan was rewritten from a per-tool substring
match (60 tools x line length) to a single-pass word extraction (per-word x
distinct tool lengths), and tool-output directories (`gnatprove/`,
`__pycache__`, `node_modules`, `.headroom`, `.lccst`) were excluded from
both tree walks so the proof-run output is not enumerated. Those changes
alone took the warm run from ~1.02 s to ~63 ms (16x) and cold from ~1.4 s
to ~545 ms, and reduced the warm-run syscall count from ~15k to ~12k.

### Probe cache

*(Origin story.)* The SBOM builds a *dev-scope* dependency edge for every tool that the
target's build references. The tool must be installed on `$PATH` (for example `gcc`, `alr`, `git`, `make`). The SBOM probes each tool with `<tool> <flag>` to capture its version. Each probe spawns a subprocess.

The subprocess costs tens of milliseconds per referenced tool (`System: 42 ms -> 9 ms`, ~150 ms end to end on an 11-tool toolchain). Originally the probed versions were cached under `<cache-root>/probes/<tool>` with a 7-day TTL. That location meant a wiped result cache re-probed every tool on the next run -- which is why 1.28.0 moved the store and folded the probe results into the tools-set cache blob (see above).

## Binary size

The debug-symbol-carrying build is ~11.1 MiB. Stripping (`strip bin/adacovex`) yields ~6.1 MiB (~45% smaller) without affecting behaviour. GNAT's default build keeps symbols for debugging (`gdb` works). Release artifacts are stripped. `make bench` always reports both.

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
