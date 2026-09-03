# Performance

adacovex is a zero-dependency CLI. Its hot path is the assessment pipeline
(scan -> patch -> doc metrics -> proof parse -> test parse -> DAL assess ->
render, plus the SBOM). This page documents how to benchmark it. It also
documents the expected numbers on a typical machine and the optimisations
that keep those numbers low.

## Benchmarking

`make bench` benchmarks the assessment pipeline and reports binary size:

- It builds the project, then times `./bin/adacovex` against the repo itself.
- **cold** runs (fresh result cache + probe cache) and **warm** runs
  (populated caches) are measured separately.
- `make bench` uses [hyperfine](https://github.com/sharkdp/hyperfine) when
  installed. It falls back to the bash `time` builtin otherwise. No tooling is
  required.
- It samples generously so the reported mean is stable. Hyperfine runs **10
  cold + 15 warm** repetitions (2 warmup runs). Each cold repetition deletes
  the cache dir first. This measures a truly empty result and probe cache. The
  `time` fallback runs **5 cold + 5 warm**.
- It reports the raw and stripped binary sizes (the stripped size is measured
  on a `/tmp` copy; the build output is never modified).Example output (hyperfine, x86-64, 8-core CI-class machine, 1.42.0):

```
=== Cold (fresh result cache) ===
  Time (mean +/- sigma):  94.3 ms +/- 4.4 ms   [User: 62.2 ms, System: 21.1 ms]
  Range (min ... max):    88.8 ms ... 104.3 ms  10 runs
=== Warm (populated caches) ===
  Time (mean +/- sigma):  40.3 ms +/- 2.9 ms   [User: 16.2 ms, System: 13.4 ms]
  Range (min ... max):    36.5 ms ... 45.9 ms  15 runs

== Binary size ==
bin/adacovex            11.1 MiB (11677936 bytes)
after strip             6.1 MiB (6360312 bytes)
savings                 45.5%
```

The numbers shift with the machine and the codebase. What matters is the
shape: warm is now in the tens of milliseconds, and the cold path is bounded
by the work that genuinely must happen (hashing the changed sources and
building the SBOM).

For single-shot timings, plain `time` works the same way:

```bash
time ./bin/adacovex --no-cache          # cold, no result cache
time ./bin/adacovex --cache-dir=/tmp/c  # warm
```

When you compare two versions, always reset the cache between runs. Use
`--cache-dir=<fresh dir>` or delete the cache dir. The result cache must not
hide the real cost.

`make perf-bench` profiles CPU and syscalls directly with `perf` and
`strace` over `bin/adacovex`. It prints the cache-miss rates and the syscall
counts so a regression in I/O or data layout is visible before a release.

## What the numbers mean

Figures below are from `make bench`/`perf-bench` on this machine (hyperfine,
cold + warm, 2 warmup). They shift with the machine and the codebase. What
matters is the shape:

- **Cold ~0.1 s**: dominated by source scanning (Ada file enumeration and
  SHA-256 of every scanned file), the SBOM tree walk and word scan, and the
  renderers. Nothing here can be skipped: the result cache is empty, so
  every file must be read and hashed at least once. The system-tool version
  probes and the ecosystem-metadata registry lookups are *not* part of cold
  anymore (both live per-machine, outside the result cache, and are cached
  across cache wipes).
- **Warm ~35 ms**: the on-disk result cache (content-addressed per file,
  oldest-first eviction) skips re-parsing unchanged sources. The stamp
  fast-path skips the per-file SHA-256 entirely (a file unchanged in size is
  not re-hashed). The tools-set cache skips the whole SBOM dev-dependency
  word scan and the tool probes for an unchanged project. The remaining
  time is process startup (dynamic loader hwcaps probing, elaboration), the
  directory walks, and the blob deserialization.
- System time is the tell. Cold runs show ~13 ms of system time (file I/O);
  warm runs show ~9 ms.

## `make prove` timing

`make prove` (gnatprove 16.1.0, 12 logical cores, 10 proof jobs) across the
last three trees:

| Scenario | 1.40.0 | 1.41.0 | 1.42.0 |
|----------|--------|--------|--------|
| Idle (no source change) | 1.6 s | 2.5 s | 2.4 s |
| Full cache miss (cold) | 39.0 s / 725 VCs | 42.8 s / 791 VCs | 4.5 s / 876 VCs |
| Warm result cache (unchanged tree) | -- | ~0.05 s | ~0.05 s |

Idle wall time is the prove result-cache short-circuit: the source tree is
content-hashed once, and unchanged inputs serve the stored proof instead of
spawning gnatprove. A real edit re-proves through gnatprove's own session
store (`obj/gnatprove/`, preserved between runs), which re-analyses only the
changed unit and its dependents -- measured at roughly 6-9 s wall for a
body-only edit on this machine.

The 1.42.0 cold drop (42.8 s -> 4.5 s despite +11% VCs) is not gnatprove
getting faster: it is the prove-input hash walk no longer enumerating
`.venv`/`node_modules`/installer/doc trees, and the ecosystem-metadata
registry lookups moving out of cold (see the 1.42.0 entries below). The
VC-count growth (+85) tracks the proved multi-pair IR slice (see
[ir.md](ir.md)). CPU use stays bounded on developer machines: the default
job count is `cores - 2` (all cores inside CI), so gnatprove never starves
the desktop.

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
~41 ms.

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

The debug-symbol-carrying build is ~9 MiB. Stripping (`strip bin/adacovex`) yields ~3.6 MiB (~60% smaller) without affecting behaviour. GNAT's default build keeps symbols for debugging (`gdb` works). Release artifacts are stripped. `make bench` always reports both.

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
