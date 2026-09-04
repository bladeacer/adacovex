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

### Sample output (hyperfine, x86-64, 12-core machine, 1.43.0)

```
=== Pipeline cold (fresh result cache) ===
  Time (mean +/- sigma):  85.7 ms +/- 2.1 ms    [User: 59.7 ms, System: 15.5 ms]
  Range (min ... max):    82.3 ms ... 89.5 ms   8 runs

=== Pipeline warm (populated caches) ===
  Time (mean +/- sigma):  35.1 ms +/- 1.6 ms    [User: 14.9 ms, System: 9.8 ms]
  Range (min ... max):    32.6 ms ... 38.4 ms   10 runs

=== Prove cold (--no-cache, result cache + gnatprove session wiped) ===
  Time (mean +/- sigma):  39.4 s (single run; see the comparison table below)

=== Prove warm (populated prove cache) ===
  Time (mean +/- sigma):  40.1 ms +/- 2.2 ms    [User: 19.4 ms, System: 10.3 ms]
  Range (min ... max):    36.5 ms ... 44.1 ms   10 runs

== Binary size ==
bin/adacovex            11.2 MiB (11694008 bytes)
after strip             6.1 MiB (6376696 bytes)
savings                 45.5%
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

## What the numbers mean

Figures below are from `make bench`/`perf-bench` on this machine (hyperfine,
cold + warm per scenario, warmups as listed above). They shift with the
machine and the codebase. What matters is the shape:

- **Pipeline cold ~86 ms**: dominated by source scanning (Ada file
  enumeration and SHA-256 of every scanned file), the SBOM tree walk and
  word scan, and the renderers. Nothing here can be skipped: the result
  cache is empty, so every file must be read and hashed at least once. The
  system-tool version probes and the ecosystem-metadata registry lookups
  are *not* part of cold anymore (both live per-machine, outside the result
  cache, and are cached across cache wipes).
- **Pipeline warm ~35 ms**: the on-disk result cache (content-addressed per
  file, oldest-first eviction) skips re-parsing unchanged sources. The
  stamp fast-path skips the per-file SHA-256 entirely (a file unchanged in
  size is not re-hashed). The tools-set cache skips the whole SBOM
  dev-dependency word scan and the tool probes for an unchanged project.
  The remaining time is process startup (dynamic loader hwcaps probing,
  elaboration), the directory walks, and the blob deserialization.
- **Prove cold ~39.4 s**: a from-scratch solver run over 876 VCs plus the
  whole pipeline. This is dominated by gnatprove itself (note the ~200 s
  of user CPU across 10 proof jobs) and is paid once per gnatprove
  session, not per run.
- **Prove warm ~40 ms**: the prove result cache serves the stored proof
  after one content-hash of the input tree, and restores the cached
  `gnatprove.out` so the assessment parses it. This is the number a
  developer hits on an unchanged tree, and the one the perf targets below
  refer to.  Back-to-back `make prove` runs sit here (measured: 20
  consecutive runs, max 2.9 s wall for `make prove` including the ~2.5 s
  `alr build`; the adacovex run itself is ~0.04 s).
- System time is the tell. Pipeline cold runs show ~16 ms of system time
  (file I/O); pipeline warm runs show ~10 ms.

## `make prove` timing (the true proof-performance test)

The true test of proof performance is the `prove` subcommand --
`./bin/covex prove` -- measured at the adacovex-binary level, not just at
the gnatprove level. The benchmark categories above define the shapes
precisely; the table compares them across the last five trees
(gnatprove 16.1.0, 12 logical cores, 10 proof jobs; the 1.42.0 column is
the hyperfine output above, the 1.43.0/1.44.0 columns are hyperfine on
each tree):

| Scenario | 1.40.0 | 1.41.0 | 1.42.0 | 1.43.0 | 1.44.0 |
|----------|--------|--------|--------|--------|--------|
| Pipeline warm | ~1.02 s* | ~104 ms | 40 ms | 35 ms | 23 ms |
| Pipeline cold | ~1.4 s* | ~545 ms* | 91 ms | 86 ms | 60 ms |
| Prove warm (result-cache short-circuit) | 1.6 s | 2.5 s | 47 ms | 40 ms | 44 ms |
| Prove cold (result cache + session wiped) | 39.0 s / 725 VCs | 42.8 s / 791 VCs | 39.3 s / 876 VCs | 39.4 s / 876 VCs | 36.4 s / 876 VCs |
| Warm-run syscalls (`newfstatat`, strace) | ~218k | ~15k | ~21k | ~12k | ~2k |

\* 1.40.0/1.41.0 pipeline figures predate the four-scenario bench script
(single-shot `time` runs, coarser sampling).

Reading the table:

- The warm short-circuit dropped from seconds to ~40 ms: the 1.41.0 stamp
  map plus the 1.42.0/1.43.0 walk-skip sets (the 1.40.0/1.41.0 "idle" runs
  of 1.6-2.5 s were dominated by the per-run `.gpr` walk enumerating
  `.venv`).  Once the cache is populated, consecutive `make prove` runs are
  consistently instant -- measured across 20 consecutive runs, the
  adacovex step stays at ~0.04 s (the 2.4-2.9 s `make prove` wall is the
  `alr build` dependency, not the proof).
- The 1.43.0 walk-skip work cut the warm syscall count again (~21k to
  ~12k) by keeping the Sphinx build tree (`docs/_build`) and the installer
  trees out of every walker: the strace profile showed ~14 distinct walkers
  re-enumerating `docs/_build` for ~53% of all warm-run stat syscalls on
  this repo.  Warm wall dropped 40 ms to 35 ms and warm system time from
  ~16 ms to ~10 ms.
- The 1.44.0 persistent stat-stamp store (below) cut the remaining warm
  stat traffic another 6x (~12k to ~2k): every walker now stats each
  directory entry once, and unchanged files are never re-read across
  runs.  Pipeline warm dropped 35 ms to 23 ms; a *wiped result cache* on
  a stamped machine re-serialises instead of re-hashing, so pipeline cold
  dropped 86 ms to 60 ms and prove-cold's adacovex-side share shrank
  again (the solver keeps the 36.4 s floor).
- The prove-cold row is gnatprove's own cost and tracks the VC count
  (39.1 s at 876 VCs; the +85 VCs over 1.41.0 are the proved multi-pair
  IR slice, see [ir.md](ir.md)). It is paid once per session, not per run:
  with the result cache wiped but the gnatprove session intact, the same
  run is ~1.1 s, and gnatprove's session store re-analyses only the
  changed unit and its dependents after a real edit (roughly 6-9 s wall
  for a body-only edit on this machine).
- **A warm hit now restores `gnatprove.out`.**  In 1.42.0 the cache stored
  only a success marker, so a warm hit on a tree whose `obj/gnatprove/`
  had been wiped reported Stone / 0 VCs (the pipeline had no summary to
  parse) and the assessment failed.  Since 1.43.0 the cache also stores
  the summary content, and a warm hit writes it back to
  `<target>/obj/gnatprove/gnatprove.out` -- the restored run reports
  Platinum / 876 VCs exactly like the run that produced it.
- **Proof effort is a solver-time dial.**  `--level=1` cold doubles the
  from-scratch wall (~35 s default -> ~68 s at `-j0` on this machine) at
  the same 876 VCs: level 1 re-tries each check with stronger solver
  configurations.  Lower levels are not strictly faster; `--level=0`
  cold is ~35 s.  A cold run's cost is dominated by the solver either
  way -- the adacovex-side share of a prove-cold run is ~1 s of the
  ~39 s.

CPU use stays bounded on developer machines: the default job count is
`cores - 2` (all cores inside CI), so gnatprove never starves the desktop.

## Optimisation history

Kept in reverse-chronological order.  Every entry names the measurement that
drove it so the next round of work can see whether the previous assumption
still holds.

### Persistent stat-stamp store, learned from language servers (1.44.0)

The 1.43.0 warm profile still showed ~2k stats per file per run: every
adacovex invocation re-opened and re-hashed every unchanged file (sources
for scan keys, manifests and vendored trees for graph keys) because the
1.28.0 stamp map dies with the process.  Language servers solved this
class of problem years ago: the
[Ada Language Server](https://github.com/AdaCore/ada_language_server)
keeps a persistent indexed file set and re-parses only files whose on-disk
state changed between sessions
(`lsp-ada_file_sets.ads`, studied in the local checkout), and
[tree-sitter](https://github.com/tree-sitter/tree-sitter) keeps its parse
input in a single reusable buffer (`TSInput`, `tree_sitter/api.h`).
adacovex adopts the first technique directly:

- `Hash_File` gained a second fast path backed by a **persistent
  stat-stamp store** at `~/.adacovex/stamps/` (machine-local, like the
  probe and meta stores, so `--cache-dir` wipes never cost re-hashes).
  A record is `<sha-256-of-path>` holding size, mtime, record time, and
  the digest; a lookup is one open + four short reads and validates two
  stats (size + mtime) against the stored pair.
- The store is **size-gated at 16 KiB**.  Measured on the self-audit
  tree, stamping the 38 small `.ads` sources made warm runs *slower*
  (a lookup costs more than re-hashing a 10 KB file); the gate keeps the
  store for the payloads where re-hashing actually dominates -- vendored
  manifests, lockfiles, generated assets.  This is the same cost model
  language servers apply when deciding whether dirty-tracking pays.
- Two git-proven safety rules keep a stale digest from ever being served:
  the size AND mtime must both match, and a file modified during the
  second the record was written is never recorded (git's racy-clean
  rule).  A `Reset_Process_Stamps` diagnostic lets tests (and long-lived
  `--serve` processes) re-walk files as a fresh run would.
- Result: warm syscalls ~12k -> ~2k (`newfstatat` ~26.8k -> ~2k on a
  stamped tree), pipeline warm 35 -> 23 ms, pipeline cold 86 -> 60 ms
  (a wiped result cache re-serialises instead of re-hashing).
  `Persistent_Stamp_Hits` / `Persistent_Stamp_Misses` counters make the
  fast path testable (Result-cache tests 22+).

### Walker-skip completion + cached-proof restore (1.43.0)

The 1.43.0 strace profile of a warm run showed ~21k `newfstatat` calls,
and 13.3k of them (~53%) hit `docs/_build` -- the Sphinx build tree of
the bundled offline manual, a gitignored build product with 461 files.
Fourteen distinct walkers re-enumerated it per run: the tools-key source
tree hash, the vendored discovery walk, the graph-key language probe and
vendored hash, the GPR collection walk, and more.  Four changes cut the
warm syscall count to ~12k and warm wall to ~35 ms:

- The shared `Skip_Walk_Dir`-governed walks (tools scan, graph key,
  vendored hash) plus the scanner, GPR-collection, and vendored-component
  walks now skip `_build` explicitly.  `Skip_Walk_Dir` itself deliberately
  does *not* skip `node_modules`: the generic vendored discovery descends
  into it to find package manifests, and its own vendor-scan skip list is
  unchanged.  A build-product tree is a per-walker decision, not a global
  one -- vendor roots must stay discoverable.
- The `Vendored_Hash` internal tree hash now honours `Skip_Walk_Dir`, so
  the graph-key walk never descends into `.venv`/`alire`/build trees
  either.
- The prove-input walk skips `_build` (its skip set already covered
  `docs/` and the installer trees).
- `Restore_Proof_Output` (see the table notes above): a warm prove hit
  writes the cached `gnatprove.out` content back to
  `<target>/obj/gnatprove/`, so a wiped session store no longer turns a
  cache hit into a Stone/0-VC assessment failure.

`make perf-bench` itself had two reporting bugs fixed while profiling
this: `perf stat` writes its counter table to stderr, which the old
`capture_output` + `print(stdout)` shape discarded (the perf sections
printed adacovex output but no counters), and the `strace ... 2>&1 |
tail -20` pipe interleaved the workload's stdout with the table and cut
the header rows.  Both tables now print in full, and a missing `perf` or
`strace` fails loudly instead of silently printing nothing.

Deploying a manifest-pinned gnatprove prints a progress line (`deploy:
gnatprove <v> not in ~/.adacovex/toolchain -- downloading via alr
(one-time, may take a minute)...`) -- the first deployment downloads a
~130 MB bundle through `alr -n get` and a silent minute of nothing read
as a hang.  The deployment is one-time per version; every later run
reuses the deployed crate with no download.

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
