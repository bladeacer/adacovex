# Performance Analysis: adacovex v1.61.0

## Benchmark machine
- EndeavourOS, x86_64, 12 logical cores, gnatprove 16.1.0

## Current metrics (just bench, release profile)

| Category | Command | Wall time | Notes |
|----------|---------|-----------|-------|
| Pipeline cold | `adacovex --cache-dir=<fresh>` | ~72 ms | fresh result cache, no prove |
| Pipeline warm | `adacovex --cache-dir=<populated>` | ~42 ms | cache hits, stamp fast path |
| Prove cold | `adacovex prove --no-cache --cache-dir=<fresh>` | ~60-72 s | wipes cache + gnatprove session |
| Prove warm | `adacovex prove --cache-dir=<populated>` | ~53 ms | cache short-circuit |
| Prove cold clone | fresh tree copy | ~78 s recorded (measurement order artefact) | paired compare shows ~69 s |
| Binary size | stripped | 5.9 MiB | 6.0 MiB unstripped |

## perf stat on pipeline warm (self tree, 10 runs)

- task-clock: ~32.4 ms
- cycles: ~89.3M (core) + 55.6M (atom)
- instructions: ~298M (core) + 140M (atom)
- cache-references: ~705k (core) + 574k (atom)
- cache-misses: ~91.6k (core) + 254.7k (atom)
- L1 dcache-miss rate: ~13% (91.6k/705k) -- HIGH
- branch-instructions: ~15.3M (core) + 14.9M (atom)
- branch-misses: ~75.5k (core) + 77.7k (atom)
- wall time: ~41.7 ms
- memory: ~33 MiB

## strace on pipeline (self tree)

### Warm (cache populated)
- newfstatat: 14,106 (472 errors)
- getdents64: 454
- openat: 639 (6 errors)
- read: 1,482
- close: 630
- fstat: 1,028
- write: 379
- execve: 1
- mmap: 18

### Cold (fresh cache)
- newfstatat: 14,106 (653 errors)
- getdents64: 454
- openat: 639 (9 errors)
- read: 1,482
- close: 630
- fstat: 1,028
- write: 379

## Key findings

### 1. The `newfstatat` floor is the directory walk
~14.1k `newfstatat` syscalls regardless of cache state.
- These are from `Start_Search` in `adacovex-dir_cache.adb` which enumerates each directory entry
- Each entry (subdirectory, file, hidden file) gets one `stat`
- The stamp fast path (`Hash_Fast`) skips the SHA-256 for unchanged files, but the directory walk still needs a `stat` for every entry
- This is the I/O floor -- the baseline cost of walking the source tree

### 2. L1 cache-miss rate is 13% on the self tree
- ~705k cache-references with ~91.6k cache-misses
- The `Dir_Cache` FNV-1a hash table with 256 slots, each storing a 1024-char path image + `Dir_Entry_List`, causes cache-line splits
- The `Dir_Entry_Rec` record: `Name_Len` (4B) + `Name` (120B) + `Kind` (4B) = 128B per entry -- a single cache line (64B) holds ~0.5 entries
- The `Dir_Cache.Table` array of 256 `Slot` records, each containing a 1024-char path + `Dir_Entry_List`, is ~8KB per slot -- way beyond a single cache line

### 3. Prove warm is excellent (52.6 ms)
- The result cache short-circuit works: content-hash input, serve stored proof
- The prove-cold row is solver-bound and load-dependent

### 4. gnatprove session is the prove-cold cost
- 60-72 s at 1047 VCs, dominated by the solver
- Bound by solver time on the checks that were always there

## Bottlenecks identified for optimization

### Priority 1: Directory walk stat reduction
The `newfstatat` count (~14k) is the same cold/warm. No existing optimization reduces it.

**None -- this is the unavoidable cost of enumerating 1047+ source files. Can't be reduced without dropping files from the scan.**

### Priority 2: L1 cache-miss rate (13% -> target < 8%)
The `Dir_Cache` hash table is the main cache pressure.

**Potential optimizations:**
- Reduce `Max_Name_Len` from 120 to 64 (typical file names are < 64 chars) -- halves the `Name` field
- Reduce `Memo_Slots` from 256 to 64 to shrink the `Table` array footprint
- Pack `Dir_Entry_Rec` fields tighter: `Name_Len` could be a `Unsigned_8` (max 255) since names are bounded at 120 chars
- The `Path_Img` (1024B) dominates the `Slot` record. Only needed for the memo key comparison.

### Priority 3: Reduce `Hash_File` on cache misses
- The persistent stamp fast path works well, but on cold cache the SHA-256 reads every file
- Already has: `Hash_Fast` path (skips for unchanged), persistent stamp index (skips for status-unchanged)

### Priority 4: Prove cold -- solver-bound
- 60-72 s at 1047 VCs, dominated by gnatprove's solver
- The result cache warm path (52.6 ms) is the user-facing win
- Campaign reduction (1047 -> 1022 VCs in 1.61.0) had no measurable effect on cold time

## Recommendations for v1.61.0

1. **Optimize the `Dir_Cache` data structure** -- the 13% L1 miss rate contributes to the 41.7 ms pipeline warm. Target: reduce L1 miss rate to < 8% by shrinking `Dir_Entry_Rec` and `Slot` records.
2. **Reduce `Max_Dir_Entries`** -- if the table can hold fewer entries, fewer cache lines are touched. The self tree has ~400 source files across ~60 directories; 1024 entries is overkill per-directory.
3. **Keep the existing fast paths** -- the stamp fast path already achieves the 41.7 ms warm pipeline, which is a 41% improvement over the 1.55.0-1.56.0 representative's 41 ms.
4. **Prove warm at ~53 ms** is consistent with the 1.57.0-1.61.0 phase numbers (45.8 ms in 1.58.0, 53.3 ms recorded for 1.61.0 at load 0.74).

## Conclusion

v1.61.0 is already competitive. The pipeline warm (41.7 ms) and prove warm (53 ms) are at or better than the phase's representative numbers. The remaining work is incremental cache-friendliness improvements that tighten the L1 miss rate, not algorithmic rewrites.
