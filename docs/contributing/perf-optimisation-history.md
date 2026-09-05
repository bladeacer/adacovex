# Performance optimisation history

Reverse-chronological record of the optimisations that keep the pipeline and prove paths fast.  Each entry names the measurement that drove it.  Benchmark methodology and current figures are on [Performance](perf.md); the `make prove` timing table is on [Prove timing and the optimisation review](perf-prove-timing.md).

## Optimisation history

Kept in reverse-chronological order. Every entry names the measurement that
drove it so the next round of work can see whether the previous assumption
still holds.

### Opt-out marker machinery + the dead proof-probe removal (1.46.0)

The 1.46.0 per-file opt-out markers added two new per-file probes to the
cold paths, so the release was profiled before shipping
(`make perf-bench` plus `strace` over the cold and warm prove shapes):

- **Warm shapes are untouched.** The `no-covex-spark-proof` marker walk
  runs only after the result-cache lookup misses, so a warm prove hit
  returns before the walk starts. The table column is flat (prove warm
  46 ms, pipeline warm 41 ms).
- **The profile shows cache health.** L1-dcache miss rates sit at
  0.1-0.7% -- far under the ~5% level where data-layout work pays -- and
  the ~6.3k `newfstatat` per warm run (~67% of syscall time) is the
  established I/O floor, not a regression.
- **A dead probe was found and removed.** The Ada source scanner called
  the opt-out detector twice per scanned spec -- once for the docstring
  marker and once for the SPARK-proof marker -- but the proof flag it
  wrote (`Pkg.Proof_Opt_Out`) was never read anywhere: the `prove`
  subcommand probes the markers itself for its `-u` unit list. Removing
  the redundant probe (and the dead `Package_Info` field, which bumped
  `Cache_Schema` to s11) saves one `open` plus one header read per
  scanned spec on every cold scan -- measured at ~160 -> ~120 source-file
  opens on the cold self-assessment. It is sub-millisecond against the
  ~88 ms cold wall, but it was pure dead work on the hottest per-file
  path.

### Shared directory-snapshot memo + correct-version probe validation (1.45.0)

Two findings drove 1.45.0, both from strace profiles of the warm path
after 1.44.0:

1. **Same directory, different memo key.** The walkers spelled the same
   directories differently (`"."`, `"src"`, `"/abs/src"`), so the 1.44.0
   snapshot memo served hits only within one spelling. The memo now
   resolves every key to its absolute image (the process working
   directory is read once), and the slot table grew from 64 to 256 (the
   self tree enumerates ~120 distinct directories). Warm hits rose from
   43/82 to 107/58 on the self audit, and `Collect_GPR_Files` joined the
   shared-snapshot walkers.
2. **`docs/_build` was still walked.** The shared `Skip_Walk_Dir` did not
   exclude it, so the vendored-discovery walk enumerated ~750 Sphinx
   build-product files per run. A build-product tree can never be a
   vendored package, so `_build` joined the shared skip set.

The same release fixed a correctness bug the perf work exposed: cached
system-tool versions were keyed only on the tool name and a 7-day TTL,
so an upgraded binary kept its old version in the SBOM for up to a week.
Both cache layers (the probe store and the tools-set blob) now carry the
identity digest of the installed binary (path + size + mtime, SHA-256
folded); a changed digest re-probes exactly once, then serves from cache
again. Verified with a PATH shim whose `jj --version` changes between
runs: run 1 probes 0.44.0, run 2 (upgraded shim) re-probes 0.50.0 in a
fully warm cache, run 3 serves 0.50.0 from cache (49 ms), run 4 (real
binary restored) re-probes 0.45.1.

Net effect on the table: warm syscalls ~6k (docs/_build gone, but the
PATH re-resolution and wider memo cost a few stats), warm wall 41 ms
(1.44.0's 23 ms plus the safety work), prove cold unchanged at the
solver floor.

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
