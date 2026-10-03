# Prove timing and the optimisation review

This page covers the `make prove` timing table (the true proof-performance
test) and the 1.46.0 SIMD and optimisation candidate review. Benchmark
methodology is on [Performance](index.md), the optimisation history is on
[Performance optimisation history](optimisation-history.md), and the 1.55.0
re-baseline detail is on [The 1.55.0 timing re-baseline](prove-rebaseline.md).

## How the phase table works

The true test of proof performance is the `prove` subcommand --
`./bin/covex prove` -- measured at the adacovex-binary level, not just at the
gnatprove level. The table keeps one column per **phase**: a range of versions
whose implementation methodology is largely similar. Each phase carries one
**representative** version, and that version supplies the complete metric set
for the phase, so a column is never assembled from the best value of each row
across different versions.

The measured phases are 1.40.0-1.41.0, 1.42.0-1.44.0, 1.45.0-1.47.0,
1.48.0-1.54.0, and 1.55.0-1.56.0. A version joins the open phase while the
methodology is unchanged; a methodology shift closes the phase and opens a new
one.

**The 1.48.0-1.54.0 phase is closed, with 1.50.0 as its representative.**  Its
methodology shift was the deterministic, incremental doc bundling of 1.50.0.
Every later version in the range folds in because it changed no performance
methodology: the 1.51.0 encode cache and parallel encoder are build-side
speed-ups, and the 1.52.0 `--level=4` gate is a gate setting that the prove
subcommand forwards verbatim.

**The 1.55.0-1.56.0 phase is open, with 1.55.0 as its representative.**
1.55.0 opens it and changes the methodology, not only the code: every figure in
this phase is taken with `/proc/loadavg` recorded beside it, because this
machine is shared and the load moves the cold rows by more than 50 percent on
the same binary. 1.56.0 folds in because it changed no measurement
methodology: it edits documentation sources, one browser script, and Python
tooling, and adds no Ada unit, so the pipeline and the prover see the same work
as 1.55.0 did. The phase also re-baselines the fully cold prove shape, which no
earlier phase recorded, and replaces the gate's second full Sphinx build with
one content-keyed shared build. Every number below is hyperfine on the self tree
(gnatprove 16.1.0, 12 logical cores, 10 proof jobs) unless a note says
otherwise.

## Pipeline timing by phase

| Phase | Representative | Pipeline warm | Pipeline cold |
|-------|----------------|---------------|---------------|
| 1.40.0-1.41.0 | 1.41.0 | ~104 ms | ~545 ms* |
| 1.42.0-1.44.0 | 1.44.0 | 23 ms | 60 ms |
| 1.45.0-1.47.0 | 1.47.0 | ~43 ms | ~74 ms |
| 1.48.0-1.54.0 | 1.50.0 | 46 ms | 73 ms |
| 1.55.0-1.56.0 | 1.55.0 | 41 ms | 66 ms |

\* The 1.40.0/1.41.0 pipeline figures predate the four-scenario bench script.
## Prove timing by phase

| Phase | Representative | Prove warm (cache short-circuit) | Prove cold (result cache + session wiped) |
|-------|----------------|----------------------------------|-------------------------------------------|
| 1.40.0-1.41.0 | 1.41.0 | 2.5 s | 42.8 s / 791 VCs |
| 1.42.0-1.44.0 | 1.44.0 | 44 ms | 36.4 s / 876 VCs |
| 1.45.0-1.47.0 | 1.47.0 | ~53 ms | ~37 s / 876 VCs (40-110 s load-dependent) |
| 1.48.0-1.54.0 | 1.50.0 | 55 ms | 61-88 s / 880 VCs (load-dependent; 878 VCs from 1.52.0) |
| 1.55.0-1.56.0 | 1.55.0 | 50 ms | 72-82 s / 878 VCs (120.6 s under heavy load) |

## Warm-run syscalls by phase

| Phase | Representative | Warm-run `newfstatat` (strace) |
|-------|----------------|--------------------------------|
| 1.40.0-1.41.0 | 1.41.0 | ~15k |
| 1.42.0-1.44.0 | 1.44.0 | ~2k |
| 1.45.0-1.47.0 | 1.47.0 | ~6k |
| 1.48.0-1.54.0 | 1.50.0 | ~6.9k |
| 1.55.0-1.56.0 | 1.55.0 | ~7.3k |

## Reading the numbers

### 1.40.0-1.41.0 (representative 1.41.0)

- The warm short-circuit dropped from seconds to tens of milliseconds: the
  1.41.0 stamp map removed the per-run re-hash. The 1.40.0/1.41.0 "idle" runs
  of 1.6-2.5 s were dominated by the per-run `.gpr` walk enumerating `.venv`,
  not by the proof. Both pipeline figures are single-shot `time` runs,
  because the four-scenario bench script did not exist yet.

### 1.42.0-1.44.0 (representative 1.44.0)

- The 1.43.0 walk-skip work cut the warm syscall count from ~21k to ~12k by
  keeping the Sphinx build tree (`docs/_build`) and the installer trees out of
  every walker. The strace profile showed ~14 walkers re-enumerating
  `docs/_build` for ~53% of all warm-run stat syscalls on this repo. The 1.44.0
  persistent stat-stamp store cut the remaining warm stat traffic another 6x
  (~12k to ~2k): every walker stats each directory entry once, and unchanged
  files are never re-read across runs. Pipeline warm dropped 35 ms to 23 ms, and
  a *wiped result cache* on a stamped machine re-serialises instead of
  re-hashing, so pipeline cold dropped 86 ms to 60 ms.

### 1.45.0-1.47.0 (representative 1.47.0)

- The phase opens with new safety work, not a regression in the I/O layer: the
  correct-version probe validation re-validates each cached system-tool
  version against the identity digest of the installed binary, so a run
  re-resolves every tool's PATH entry. The absolute-path memo keys make the
  shared directory snapshot serve more walkers, and `docs/_build` stays
  excluded from every walk.
- The 1.46.0 opt-out machinery is invisible to every warm shape. The
  `no-covex-spark-proof` marker scan runs only after the result-cache lookup
  misses, so a warm prove hit returns before the walk starts (46 ms prove warm,
  unchanged). A cold prove pays the count walk once, which is noise against the
  solver floor at 876 VCs.
- The 1.47.0 `-O2 -gnatn` release build is why 1.47.0 represents the phase: the
  previously unoptimised build becomes the release build, pipeline cold reaches
  its best figure (~74 ms), and the stripped binary shrinks from 6.49 MiB to
  5.39 MiB. The solver-dominated prove-cold shape does not move, and the phase's
  syscall count stays at ~6k, half of 1.43.0's ~12k.

### 1.48.0-1.54.0 (representative 1.50.0)

- The phase's methodology shift is in the build, not in the binary. The doc
  bundling became deterministic and incremental: `tools/gen-docs.py` builds
  the Sphinx output clean and writes `src/adacovex-docs_template.ads` only when
  its content changed, so the generated spec no longer differs between an
  incremental developer tree and a fresh clone.
- The cached proof now survives a docs change. The generated bundle specs are
  excluded from the proof-input hash, because a string of base85 gzip chunks has
  no proof surface. Before this phase a changed spec invalidated the proof
  result cache, so `make prove` paid a full gnatprove session (tens of seconds)
  after what looked like an unchanged tree.
- The phase also carries the manual-encoding change: the asset bodies are base85
  instead of base64 and the Furo sidebar is stored once per branch instead of
  once per page. `src/adacovex-docs_template.ads` falls from 2.34 MB to 1.93 MB,
  so the phase's stripped binary is the smallest of the three columns (5.3 MiB).
- The binary-level shapes are flat by design: pipeline warm 46 ms and prove warm
  55 ms sit within noise of 1.47.0, and warm `newfstatat` is ~6.9k, the tree's
  I/O floor. The fix removes failed work (a recompile and relink plus a
  re-proof), not steady work. The prove-cold row is solver-bound and
  load-dependent as always: single shots measured 61 s and 67 s, and a
  three-run hyperfine sample under load measured 87.6 s, all at 880 VCs. Treat
  61-88 s as the observed range.
- 1.51.0 folds into the phase without moving a row. Its changes are in
  `tools/gen-docs.py`: the manual-encode cache plus the parallel encoder cut a
  no-op `gen-docs.py --check` from about 0.6 s to about 0.3 s, and the
  incremental Sphinx build cuts a one-page prose edit from about 7 s to about
  1.2 s (a navigation change, such as a page move, pays about 5.5 s for the
  full-page rewrite). The emitted spec stays byte-identical, which is why 1.50.0
  keeps the representative slot.
- 1.52.0 verifies the tree at gnatprove **level 4** (the deepest effort) and
  proves clean there with no new VCs: the same 878 checks pass and two dead
  branches level 4's flow analysis flagged as unreachable were removed. Level 4
  costs solver time on a cold run (one full-tree level-4 session measured
  ~19 s against ~14 s at the default level on this machine), but the warm
  short-circuit is a cache hit and does not move (the 1.52.0 bench session
  measured 45.6 +/- 3.0 ms, within noise of the phase's 55 ms). The prove
  subcommand passes `--level` through verbatim, so a level-4 run costs exactly
  gnatprove's overhead and nothing from adacovex. The same release hardens the
  warm path: a stored summary that reports unproved VCs is dropped and
  re-proved instead of served.

### 1.55.0 (representative 1.55.0)

- The phase's adacovex-side shapes are flat or slightly better than the closed
  1.48.0-1.54.0 column: pipeline warm 41.3 ms, pipeline cold 66.5 ms, prove
  warm 49.9 ms, and warm `newfstatat` 7.3k, all at load 0.5-0.6. The
  closed phase read 46 ms, 73 ms, 55 ms, and ~6.9k. Nothing in 1.55.0 is on a
  hot path.
- **The tool-probe cache fix removes failed work, and the removed work is now
  visible as a floor.** A run whose cached tool fingerprint no longer matches the
  installed binary re-probed that tool on every run forever, because the re-probe
  branch and the store-back branch could never both be true. On a deliberately
  corrupted probe blob the run goes from 11 subprocess spawns and 976 ms to one
  spawn and 57 ms, which is the healthy warm floor this phase measures on an
  unchanged tree (one spawn, 49.9 ms wall).
- **The manual link check no longer builds the manual a second time.** It shares
  one content-keyed Sphinx build with the offline-manual generator, so the gate
  goes from about 18.6 s to 0.44 s warm and the `tools-check` suite that
  exercises it from 28.9 s to 2.5 s. `make prove` on an unchanged tree now
  measures 1.1 s at load 4.1.
- **Go dependency resolution is the one feature that adds work, and it is
  bounded.** Each vendored Go component costs one `modules.txt` lookup and two
  licence-file probes. The self tree has no vendored component, so no figure in
  this column can see that cost; measured against a 1.54.0 build on a synthetic
  tree with 100 vendored Go modules, the new build reads 39.7 ms against a
  40.9 ms base, inside the paired spread. The resolver skips a registry spawn
  whose row can add nothing the caller already holds, so the offline path spawns
  no tool at all.
- The prove-cold row is solver-bound and load-dependent as in every phase: 72.0 s
  and 73.1 s at load 3.6 and 5.0, 80.2 s at load 7.2, 81.7 s at load 2.3, and
  120.6 s at load 21.9, all at 878 VCs with 0 unproved. Read the row as 72-82 s
  on an idle to moderately loaded box and up to 121 s under heavy load. The
  full method and every figure are on [The 1.55.0 timing
  re-baseline](prove-rebaseline.md).

### Across every phase

- The prove-cold row is gnatprove's own cost and tracks the VC count (39.1 s at
  876 VCs; the +85 VCs over 1.41.0 are the proved multi-pair IR slice, see
  [ir.md](../ir.md)). It is paid once per session, not per run: with the result
  cache wiped but the gnatprove session intact, the same run is ~1.1 s, and
  gnatprove's session store re-analyses only the changed unit and its
  dependents after a real edit (roughly 6-9 s wall for a body-only edit).
- The **fully cold** shape is the one to read for a first run on a new
  checkout: the result cache, the gnatprove session store, and the proof
  summary are all absent, so every run pays a from-scratch solver session.
  Re-baselined for 1.55.0 it reads 72.0 s at load 3.6, 73.1 s at load 5.0,
  80.2 s at load 7.2, 81.7 s at load 2.3, and 120.6 s at load 21.9, all at
  878 VCs. Read that as 72-82 s on an idle to moderately loaded machine and
  up to 121 s under heavy load, because the load reading is the one-minute
  average taken just before the run and lags a rising load. The method and
  the full table are on [The 1.55.0 timing re-baseline](prove-rebaseline.md).
- **A benchmark on the self tree cannot find a vendored-code regression.** The
  self tree has zero vendored components, so a change that only touches
  vendored code is invisible to it. Measure such a change on a fixture that
  has the shape it touches, paired against a build of the base commit.
- A cold first run on a fresh clone lands in the same band, because a clone has
  no result cache and no session either; the only extra work over that shape is
  the assessment that follows the proof, about 45 ms.
- `make prove` on an unchanged tree is not the same shape as the warm prove
  short-circuit. The target also regenerates the bundled manual and the dashboard
  template and re-checks the generators, so it costs about 1.1 s at load 4.1
  where `./bin/covex prove` alone costs 50 ms.
- A warm hit restores `gnatprove.out` since 1.43.0: the cache stores the summary
  content, so a hit on a tree whose `obj/gnatprove/` was wiped reports Platinum
  at the VC count of the run that produced it. Before 1.43.0 the cache stored
  only a success marker, so such a hit reported Stone / 0 VCs.
- Proof effort is a solver-time dial. `--level=1` cold doubles the from-scratch wall
  (~35 s default to ~68 s at `-j0` on this machine) at the same 876 VCs, because
  level 1 re-tries each check with stronger solver configurations. Lower levels
  are not strictly faster; `--level=0` cold is ~35 s.
- CPU use stays bounded on developer machines: the default job count is
  `cores - 2` (all cores inside CI), so gnatprove never starves the desktop.
