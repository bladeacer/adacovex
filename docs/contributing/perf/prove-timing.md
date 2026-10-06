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

The measured phases are 1.45.0-1.47.0, 1.48.0-1.54.0, 1.55.0-1.56.0, and
1.57.0-1.58.0. A version joins the open phase while the methodology is
unchanged; a methodology shift closes the phase and opens a new one.

The table holds the three most recent closed phases plus the open one. A
retired phase is deleted rather than kept, so the page does not grow without
bound. Before a phase is deleted, whatever still explains a surviving number
moves into the "Across every phase" notes. The phases retired so far are
1.40.0-1.41.0 and 1.42.0-1.44.0; their two contributions survive in prose,
because the walker-skip and stat-stamp work behind the warm syscall floor is
written up in full on [Performance optimisation
history](optimisation-history.md#walker-skip-completion--cached-proof-restore-1430),
and a warm hit restoring `gnatprove.out` is noted below.

**The 1.48.0-1.54.0 phase is closed, with 1.50.0 as its representative.**  Its
methodology shift was the deterministic, incremental doc bundling of 1.50.0.
Every later version in the range folds in because it changed no performance
methodology: the 1.51.0 encode cache and parallel encoder are build-side
speed-ups, and the 1.52.0 `--level=4` gate is a gate setting that the prove
subcommand forwards verbatim.

**The 1.55.0-1.56.0 phase is closed, with 1.55.0 as its representative.**
1.55.0 opens it and changes the methodology, not only the code: every figure in
this phase is taken with `/proc/loadavg` recorded beside it, because this
machine is shared and the load moves the cold rows by more than 50 percent on
the same binary. 1.56.0 folds in because it changed no measurement
methodology: it edits documentation sources, one browser script, and Python
tooling, and adds no Ada unit, so the pipeline and the prover see the same work
as 1.55.0 did. The phase also re-baselines the fully cold prove shape, which no
earlier phase recorded, and replaces the gate's second full Sphinx build with
one content-keyed shared build.

**The 1.57.0-1.58.0 phase is open, with 1.58.0 as its representative.**
1.57.0 shifts the methodology, because the tree gained a development profile
and a release profile. Every figure on this page is taken on the **release**
profile (`-O2 -gnatn`, no debug information), because that is the binary the
released figures describe. A development build is `-O1 -gnatn -g` and is about
half the serial compile time, so an `-O1` figure is not comparable with an
`-O2` one, and the profile is named beside every number. 1.58.0 folds in
because it changed no measurement methodology: its Ada work is the C7 proof
opt-in sweep and the H2 dead-initialiser fix, both of which the prover sees,
and its other work is documentation, one browser script, and Python tooling.
Every number below is hyperfine on the self tree (gnatprove 16.1.0, 12 logical
cores, 10 proof jobs, release profile) unless a note says otherwise.

## Pipeline timing by phase

| Phase | Representative | Pipeline warm | Pipeline cold |
|-------|----------------|---------------|---------------|
| 1.45.0-1.47.0 | 1.47.0 | ~43 ms | ~74 ms |
| 1.48.0-1.54.0 | 1.50.0 | 46 ms | 73 ms |
| 1.55.0-1.56.0 | 1.55.0 | 41 ms | 66 ms |
| 1.57.0-1.58.0 | 1.58.0 | 38.4 ms +/- 2.5 ms | 68.6 ms +/- 5.5 ms |

The 1.58.0 rows are hyperfine samples on the release profile at load 0.95:
15 runs for warm and 10 for cold.

## Prove timing by phase

| Phase | Representative | Prove warm (cache short-circuit) | Prove cold (result cache + session wiped) |
|-------|----------------|----------------------------------|-------------------------------------------|
| 1.45.0-1.47.0 | 1.47.0 | ~53 ms | ~37 s / 876 VCs (40-110 s load-dependent) |
| 1.48.0-1.54.0 | 1.50.0 | 55 ms | 61-88 s / 880 VCs (load-dependent; 878 VCs from 1.52.0) |
| 1.55.0-1.56.0 | 1.55.0 | 50 ms | 72-82 s / 878 VCs (120.6 s under heavy load) |
| 1.57.0-1.58.0 | 1.58.0 | 46.0 ms +/- 3.4 ms | 76.4 s / 1060 VCs (3 runs, 74.0-78.1 s) |

The 1.58.0 warm row is 15 runs at load 0.95. Its cold row is 3 runs at the
same load, and the gnatprove session store is wiped before each one.

## Warm-run syscalls by phase

| Phase | Representative | Warm-run `newfstatat` (strace) |
|-------|----------------|--------------------------------|
| 1.45.0-1.47.0 | 1.47.0 | ~6k |
| 1.48.0-1.54.0 | 1.50.0 | ~6.9k |
| 1.55.0-1.56.0 | 1.55.0 | ~7.3k |
| 1.57.0-1.58.0 | 1.58.0 | 7 474 (~7.5k) |

## Reading the numbers

### 1.45.0-1.47.0 (representative 1.47.0)

- The phase opens with new safety work, not a regression in the I/O layer: the
  correct-version probe validation re-validates each cached system-tool version
  against the identity digest of the installed binary, so a run re-resolves
  every tool's PATH entry. Both this work and the shared directory-snapshot
  memo are written up on [Performance optimisation
  history](optimisation-history.md).
- The 1.46.0 opt-out machinery is invisible to every warm shape: the marker scan
  runs only after the result-cache lookup misses, so a warm prove hit returns
  before the walk starts. A cold prove pays the count walk once, which is noise
  against the solver floor at 876 VCs.
- The 1.47.0 `-O2 -gnatn` release build is why 1.47.0 represents the phase: the
  previously unoptimised build becomes the release build, pipeline cold reaches
  its best figure (~74 ms), and the stripped binary shrinks from 6.49 MiB to
  5.39 MiB. The solver-dominated prove-cold shape does not move, and the phase's
  syscall count stays at ~6k, half of the ~12k the walk-skip work left behind.

### 1.48.0-1.54.0 (representative 1.50.0)

- The phase's methodology shift is in the build, not in the binary: doc bundling
  became deterministic and incremental, so the generated manual spec no longer
  differs between a developer tree and a fresh clone. The mechanics are on
  [Performance optimisation history](optimisation-history.md).
- The fix removes failed work rather than steady work, which is why the binary
  shapes are flat by design: pipeline warm 46 ms and prove warm 55 ms sit within
  noise of 1.47.0, and warm `newfstatat` is ~6.9k, the tree's I/O floor. A
  changed spec also no longer invalidates the proof result cache, because the
  generated bundle specs are excluded from the proof-input hash.
- 1.51.0 folds in without moving a row: its encode cache, parallel encoder, and
  incremental Sphinx build are build-side speed-ups that leave the emitted spec
  byte-identical, so 1.50.0 keeps the representative slot. 1.52.0 verifies the
  tree at gnatprove **level 4** and proves clean there with no new VCs. The
  prove subcommand forwards `--level` verbatim, so a level-4 run costs exactly
  gnatprove's overhead and nothing from adacovex.
- The prove-cold row is solver-bound and load-dependent as always: single shots
  measured 61 s and 67 s, and a three-run hyperfine sample under load measured
  87.6 s, all at 880 VCs. Treat 61-88 s as the observed range.

### 1.55.0-1.56.0 (representative 1.55.0)

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
  40.9 ms base, inside the paired spread.
- The prove-cold row is solver-bound and load-dependent as in every phase: 72.0 s
  and 73.1 s at load 3.6 and 5.0, 80.2 s at load 7.2, 81.7 s at load 2.3, and
  120.6 s at load 21.9, all at 878 VCs with 0 unproved. Read the row as 72-82 s
  on an idle to moderately loaded box and up to 121 s under heavy load. The
  full method and every figure are on [The 1.55.0 timing
  re-baseline](prove-rebaseline.md).

### 1.57.0-1.58.0 (representative 1.58.0)

- **The phase's methodology shift is the build profile, and it is the reason
  this column is separate rather than a fold-in.** 1.57.0 split the tree into a
  development profile (`-O1 -gnatn -g`) and a release profile (`-O2 -gnatn`), and
  made the development profile the default for a plain `alr build`. A column
  whose representative was measured at `-O2` cannot also carry an `-O1` figure,
  so the profile is named beside every number here and the measurement is taken
  on the release profile.
- **Every adacovex-side shape is flat or slightly better than the closed
  1.55.0-1.56.0 column, and the margins are small enough to read as noise.**
  Pipeline warm is 38.4 ms against the closed phase's 41 ms, prove warm is
  46.0 ms against 50 ms, and pipeline cold is 68.6 ms against 66 ms. Warm
  `newfstatat` is 7 474 against ~7.3k, so the tree's I/O floor held while the
  manifest package gained 19 separate bodies.
- **The VC count grew by a fifth and the prove-cold row did not.** C7 moved
  thirteen in-package subprograms into the proved set and H2 removed seven dead
  initialisers, taking the campaign from 878 VCs in 1.55.0 to 1060. The cold
  prove row is 76.4 s at 1060 VCs, inside the 72-82 s band the closed phase
  recorded at 878 VCs. The extra 182 checks cost no measurable wall on this
  machine, because the row is bound by the solver's time on the checks that were
  always there.
- **The manifest split did not shorten the build, and the plan recorded that
  rather than assuming it.** 1.57.0 split the slowest body in the tree into 19
  separate bodies, on the expectation that it would shorten the critical path of
  a parallel build. It did not: an Ada separate body shares its parent's `gnat1`
  invocation, so the file split but the compile did not. Measured with the load
  recorded, the original tree built in 60.7 s and 62.7 s and the split tree in
  57.3 s and 59.8 s. That is a build-side figure and moves no row above, but it
  is the phase's main negative result.
- **The fully cold clone shape moves with the phase.** The fresh-tree prove
  measures 80.7 s over two runs (78.9-82.4 s) against 76.4 s for prove cold in
  the same session. The tree copy adds well under a second, so the two rows are
  one number with two names, as in every earlier phase.
- **The prove warm path got a correctness fix, not a speed-up.** H1 restored a
  truthfulness gap in the short-circuit: a cache hit that failed to restore a
  usable summary used to print "reusing prior proof" and return success without
  running the prover. The runner now falls through to a real gnatprove run. The
  warm row is unaffected, because a healthy warm hit was already a cache hit.
- `make prove` on an unchanged tree measures 1.0 s and 1.03 s on two consecutive
  runs at load 2.7, where `./bin/covex prove` alone costs 46.0 ms. The stripped
  binary is 6.0 MiB, down from the 9.5 MiB unstripped build, so the phase is
  36.6 percent smaller after `strip`. The Ada_CRDT second datapoint reads 36.2
  ms cold and 26.9 ms warm.

### Across every phase

- The prove-cold row is gnatprove's own cost and tracks the VC count (39.1 s at
  876 VCs; the growth past that point is the proved multi-pair IR slice and the
  C7 opt-in sweep, see [ir.md](../ir.md)). It is paid once per session, not per
  run: with the result cache wiped but the gnatprove session intact, the same
  run is ~1.1 s, and gnatprove's session store re-analyses only the changed unit
  and its dependents after a real edit (roughly 6-9 s wall for a body-only
  edit).
- **A benchmark on the self tree cannot find a vendored-code regression.** The
  self tree has zero vendored components, so a change that only touches
  vendored code is invisible to it. Measure such a change on a fixture that
  has the shape it touches, paired against a build of the base commit.
- A cold first run on a fresh clone lands in the same band, because a clone has
  no result cache and no session either; the only extra work over that shape is
  the assessment that follows the proof, about 45 ms.
- `make prove` on an unchanged tree is not the same shape as the warm prove
  short-circuit. The target also regenerates the bundled manual and the dashboard
  template and re-checks the generators, so it costs about 1.0 s where
  `./bin/covex prove` alone costs 46 ms.
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