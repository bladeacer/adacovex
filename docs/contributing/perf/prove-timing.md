# Prove timing and the optimisation review

This page covers the `make prove` timing table (the true proof-performance
test) and the 1.46.0 SIMD and optimisation candidate review.  Benchmark
methodology and current figures are on [Performance](index.md); the full
optimisation history is on [Performance optimisation
history](optimisation-history.md).

## How the phase table works

The true test of proof performance is the `prove` subcommand --
`./bin/covex prove` -- measured at the adacovex-binary level, not just at
the gnatprove level.  The table keeps one column per **phase**: a range of
versions whose implementation methodology is largely similar.

Each phase carries one **representative** version.  That version supplies
the complete metric set for the phase, so a column is never assembled from
the best value of each row across different versions.  When the metrics
trade off, the reading notes name the representative and the reason for the
pick.

The measured phases are 1.40.0-1.41.0, 1.42.0-1.44.0, and 1.45.0-1.47.0.  A
version joins the open phase while the methodology is unchanged; a
methodology shift closes the phase and opens a new one.

**The 1.48.0 phase is open.**  1.48.0 and 1.49.0 add no
performance-methodology change, so the tables carry no column for them yet.
The open phase takes its representative version only when `make bench` runs
on the tree that first shifts the methodology.  Every number below is
hyperfine on the self tree (gnatprove 16.1.0, 12 logical cores, 10 proof
jobs) unless a note says otherwise.

## Pipeline timing by phase

| Phase | Representative | Pipeline warm | Pipeline cold |
|-------|----------------|---------------|---------------|
| 1.40.0-1.41.0 | 1.41.0 | ~104 ms | ~545 ms* |
| 1.42.0-1.44.0 | 1.44.0 | 23 ms | 60 ms |
| 1.45.0-1.47.0 | 1.47.0 | ~43 ms | ~74 ms |

\* The 1.40.0/1.41.0 pipeline figures predate the four-scenario bench script
(single-shot `time` runs, coarser sampling).

## Prove timing by phase

| Phase | Representative | Prove warm (cache short-circuit) | Prove cold (result cache + session wiped) |
|-------|----------------|----------------------------------|-------------------------------------------|
| 1.40.0-1.41.0 | 1.41.0 | 2.5 s | 42.8 s / 791 VCs |
| 1.42.0-1.44.0 | 1.44.0 | 44 ms | 36.4 s / 876 VCs |
| 1.45.0-1.47.0 | 1.47.0 | ~53 ms | ~37 s / 876 VCs (40-110 s load-dependent) |

## Warm-run syscalls by phase

| Phase | Representative | Warm-run `newfstatat` (strace) |
|-------|----------------|--------------------------------|
| 1.40.0-1.41.0 | 1.41.0 | ~15k |
| 1.42.0-1.44.0 | 1.44.0 | ~2k |
| 1.45.0-1.47.0 | 1.47.0 | ~6k |

## Reading the numbers

### 1.40.0-1.41.0 (representative 1.41.0)

- The warm short-circuit dropped from seconds to tens of milliseconds: the
  1.41.0 stamp map removed the per-run re-hash.  The 1.40.0/1.41.0 "idle"
  runs of 1.6-2.5 s were dominated by the per-run `.gpr` walk enumerating
  `.venv`, not by the proof.  Both pipeline figures are single-shot `time`
  runs, because the four-scenario bench script did not exist yet.

### 1.42.0-1.44.0 (representative 1.44.0)

- The 1.43.0 walk-skip work cut the warm syscall count from ~21k to ~12k by
  keeping the Sphinx build tree (`docs/_build`) and the installer trees out
  of every walker.  The strace profile showed ~14 distinct walkers
  re-enumerating `docs/_build` for ~53% of all warm-run stat syscalls on
  this repo.
- The 1.44.0 persistent stat-stamp store cut the remaining warm stat traffic
  another 6x (~12k to ~2k): every walker stats each directory entry once,
  and unchanged files are never re-read across runs.  Pipeline warm dropped
  35 ms to 23 ms, and a *wiped result cache* on a stamped machine
  re-serialises instead of re-hashing, so pipeline cold dropped 86 ms to
  60 ms.

### 1.45.0-1.47.0 (representative 1.47.0)

- The phase opens with new safety work, not a regression in the I/O layer:
  the correct-version probe validation re-validates each cached system-tool
  version against the identity digest of the installed binary, so a run
  re-resolves every tool's PATH entry.  The absolute-path memo keys make the
  shared directory snapshot serve more walkers, while `docs/_build` stays
  excluded from every walk.
- The 1.46.0 opt-out machinery is invisible to every warm shape.  The
  `no-covex-spark-proof` marker scan runs only after the result-cache lookup
  misses, so a warm prove hit returns before the walk starts (46 ms prove
  warm, unchanged).  A cold prove pays the count walk once, which is noise
  against the solver floor at the same 876 VCs.
- The 1.47.0 `-O2 -gnatn` release build is why 1.47.0 represents the phase:
  the previously unoptimised build becomes the release build, pipeline cold
  reaches its best figure (~74 ms), and the stripped binary shrinks from
  6.49 MiB to 5.39 MiB.  The solver-dominated prove-cold shape does not
  move.  The phase's warm/cold syscall count stays at ~6k, half of 1.43.0's
  ~12k.

### Across every phase

- The prove-cold row is gnatprove's own cost and tracks the VC count (39.1 s
  at 876 VCs; the +85 VCs over 1.41.0 are the proved multi-pair IR slice,
  see [ir.md](../ir.md)).  It is paid once per session, not per run: with the
  result cache wiped but the gnatprove session intact, the same run is
  ~1.1 s, and gnatprove's session store re-analyses only the changed unit
  and its dependents after a real edit (roughly 6-9 s wall for a body-only
  edit on this machine).
- A warm hit restores `gnatprove.out` since 1.43.0: the cache stores the
  summary content, so a hit on a tree whose `obj/gnatprove/` was wiped
  reports Platinum / 876 VCs exactly like the run that produced it.  Before
  1.43.0 the cache stored only a success marker, so such a hit reported
  Stone / 0 VCs and the assessment failed.
- Proof effort is a solver-time dial.  `--level=1` cold doubles the
  from-scratch wall (~35 s default to ~68 s at `-j0` on this machine) at the
  same 876 VCs, because level 1 re-tries each check with stronger solver
  configurations.  Lower levels are not strictly faster; `--level=0` cold is
  ~35 s.
- CPU use stays bounded on developer machines: the default job count is
  `cores - 2` (all cores inside CI), so gnatprove never starves the desktop.

## SIMD and other optimisation candidates (1.46.0)

An optimisation review in 1.46.0 asked whether SIMD or other low-level
speed-ups could improve the pipeline.  The measurements say no:

- A cold self-assessment (no result cache, ~250 source files) completes in
  ~88 ms and a warm one in ~41 ms on the dev machine (hyperfine, 1.46.0),
  even though the local build profile is unoptimised (no `-O` flags).  The
  pipeline is I/O-bound and cache-bound, not compute-bound.
- `make perf-bench` (perf + strace over the same tree, 1.46.0) shows the
  cache is healthy: L1-dcache miss rates of 0.1-0.7% sit far under the
  ~5% level where data-layout work pays, so no struct packing or
  prefetching is warranted.  The I/O story is the same as the last
  release: ~6.3k `newfstatat` on a warm run (~67% of syscall time) is
  the walk floor, and the cold scan opens each source file once.
- A `prove` run is dominated by the gnatprove solver floor (~39 s cold;
  warm runs serve the cached proof in milliseconds).  The adacovex-side share
  of a cold prove run is about a second.
- The per-byte scanning loops (comment stripping, decision counting, HLR
  tags) are the only SIMD candidates.  They process short lines one byte at
  a time; auto-vectorisation needs `-O3` (or `-ftree-vectorize`) and gains
  little on data this small, at the cost of the zero-dependency build's
  simplicity.

Conclusion: no SIMD or assembly is added.  The sanctioned path to more
speed is the existing one -- higher optimisation in release profiles
(`alr` release builds already enable `-O2`), the shared directory snapshot
memo, and the content-hashed result cache.  If a future profile shows the
scanner hot, the first move is whole-file buffered reads, not SIMD.
