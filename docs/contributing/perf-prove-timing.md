# Prove timing and the optimisation review

This page covers the `make prove` timing table (the true proof-performance test) and the 1.46.0 SIMD and optimisation candidate review.  Benchmark methodology and current figures are on [Performance](perf.md); the full optimisation history is on [Performance optimisation history](perf-optimisation-history.md).

## `make prove` timing (the true proof-performance test)

The true test of proof performance is the `prove` subcommand --
`./bin/covex prove` -- measured at the adacovex-binary level, not just at
the gnatprove level. The benchmark categories above define the shapes
precisely; the table compares them across the last seven trees
(gnatprove 16.1.0, 12 logical cores, 10 proof jobs; the 1.42.0 column is
the hyperfine output above, the 1.43.0 onward columns are hyperfine on
each tree):

| Scenario | 1.40.0 | 1.41.0 | 1.42.0 | 1.43.0 | 1.44.0 | 1.45.0 | 1.46.0 |
|----------|--------|--------|--------|--------|--------|--------|--------|
| Pipeline warm | ~1.02 s* | ~104 ms | 40 ms | 35 ms | 23 ms | 41 ms | 41 ms |
| Pipeline cold | ~1.4 s* | ~545 ms* | 91 ms | 86 ms | 60 ms | 84 ms | 88 ms |
| Prove warm (result-cache short-circuit) | 1.6 s | 2.5 s | 47 ms | 40 ms | 44 ms | 46 ms | 46 ms |
| Prove cold (result cache + session wiped) | 39.0 s / 725 VCs | 42.8 s / 791 VCs | 39.3 s / 876 VCs | 39.4 s / 876 VCs | 36.4 s / 876 VCs | 36.8 s / 876 VCs | 37.3 s / 876 VCs |
| Warm-run syscalls (`newfstatat`, strace) | ~218k | ~15k | ~21k | ~12k | ~2k | ~6k | ~6k |

\* 1.40.0/1.41.0 pipeline figures predate the four-scenario bench script
(single-shot `time` runs, coarser sampling).

The 1.45.0 warm/cold wall figures carry new safety work, not a
regression in the I/O layer: the correct-version probe validation (each
cached system-tool version is re-validated against the identity digest
of the installed binary) re-resolves every tool's PATH entry per run,
and the absolute-path memo keys make the shared directory snapshot serve
more walkers. The syscall column still shows the real I/O story: ~6k
stats versus 1.43.0's ~12k, with `docs/_build` (a Sphinx build product,
~750 stats/run) now excluded from every walk. Prove cold stays pinned at
the solver floor (36.8 s at 876 VCs), and prove warm stays under 50 ms.

The 1.46.0 column is flat because the per-file opt-out machinery is
invisible to every warm shape.  The `no-covex-spark-proof` marker scan
(`Append_Unit_List` walking the project's source directories) runs only
after the result-cache lookup misses, so a warm prove hit returns before
the walk starts (46 ms prove warm, unchanged).  A cold prove pays the
count walk once, but it is a directory enumeration over the same trees
the cold run already hashes -- noise against the 37.3 s solver floor at
the same 876 VCs.  Pipeline warm and cold are likewise flat (41 ms /
88 ms): the complexity gate now scans Markdown, but that gate is a
separate subcommand and is not part of the assessed pipeline, and the
marker scan in the source scanner adds no per-byte cost to a warm run.

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

## SIMD and other optimisation candidates (1.46.0)

An optimisation review in 1.46.0 asked whether SIMD or other low-level
speed-ups could improve the pipeline. The measurements say no:

- A cold self-assessment (no result cache, ~250 source files) completes in
  ~88 ms and a warm one in ~41 ms on the dev machine (hyperfine, 1.46.0),
  even though the local build profile is unoptimised (no `-O` flags). The
  pipeline is I/O-bound and cache-bound, not compute-bound.
- `make perf-bench` (perf + strace over the same tree, 1.46.0) shows the
  cache is healthy: L1-dcache miss rates of 0.1-0.7% sit far under the
  ~5% level where data-layout work pays, so no struct packing or
  prefetching is warranted. The I/O story is the same as the last
  release: ~6.3k `newfstatat` on a warm run (~67% of syscall time) is
  the walk floor, and the cold scan opens each source file once.
- A `prove` run is dominated by the gnatprove solver floor (~39 s cold;
  warm runs serve the cached proof in milliseconds). The adacovex-side share
  of a cold prove run is about a second.
- The per-byte scanning loops (comment stripping, decision counting, HLR
  tags) are the only SIMD candidates. They process short lines one byte at
  a time; auto-vectorisation needs `-O3` (or `-ftree-vectorize`) and gains
  little on data this small, at the cost of the zero-dependency build's
  simplicity.

Conclusion: no SIMD or assembly is added. The sanctioned path to more
speed is the existing one -- higher optimisation in release profiles
(`alr` release builds already enable `-O2`), the shared directory snapshot
memo, and the content-hashed result cache. If a future profile shows the
scanner hot, the first move is whole-file buffered reads, not SIMD.
