# Performance optimisation history: earlier releases

> **Archived record.**  These entries cover releases 1.27.0 to 1.42.0.
> The live history continues on the
> [optimisation history](../contributing/perf/optimisation-history.md).

This page is the earlier half of the [performance optimisation
history](../contributing/perf/optimisation-history.md), from 1.42.0 back to
1.27.0. Each entry names the measurement that drove it. The 1.43.0 and later
entries, and the benchmark methodology, are on the [optimisation
history](../contributing/perf/optimisation-history.md) and the [performance
page](../contributing/perf/index.md).

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
to ~545 ms, and reduced the warm-run syscall count to ~12k.
