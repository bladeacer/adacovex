# Prove timing and the optimisation review

This page covers the `just prove` timing table (the true proof-performance
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
bound, and whatever still explains a surviving number moves into the "Across
every phase" notes first. The phases retired so far are 1.40.0-1.41.0 and
1.42.0-1.44.0; the stat-stamp work behind the warm syscall floor is written up
on [Performance optimisation history](optimisation-history.md).

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
the same binary. 1.56.0 folds in because it edited documentation sources, one
browser script, and Python tooling, and added no Ada unit, so the pipeline and
the prover see the same work as 1.55.0 did. It also re-baselines the fully cold
prove shape, which no earlier phase recorded.

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

**Scenario order biases the cold rows, so read every figure with its load.**
Each scenario loads the box, so one measured late inherits the load the earlier
ones left behind. `just bench` prints the load in front of every scenario for
that reason. Compare two shapes paired, not as two rows of one sequential pass:
the clone row below is a case where sequence order alone manufactured an
apparent 14-second gap that a paired run did not reproduce.

## Pipeline timing by phase

| Phase | Representative | Pipeline warm | Pipeline cold |
|-------|----------------|---------------|---------------|
| 1.45.0-1.47.0 | 1.47.0 | ~43 ms | ~74 ms |
| 1.48.0-1.54.0 | 1.50.0 | 46 ms | 73 ms |
| 1.55.0-1.56.0 | 1.55.0 | 41 ms | 66 ms |
| 1.57.0-1.58.0 | 1.58.0 | 35.5 ms +/- 1.8 ms | 62.3 ms +/- 0.8 ms |

The 1.58.0 rows are one hyperfine session on the release profile at the shipped
1047 VCs: 15 runs for warm and 10 for cold, taken at load 0.59.

## Prove timing by phase

| Phase | Representative | Prove warm (cache short-circuit) | Prove cold (result cache + session wiped) |
|-------|----------------|----------------------------------|-------------------------------------------|
| 1.45.0-1.47.0 | 1.47.0 | ~53 ms | ~37 s / 876 VCs (40-110 s load-dependent) |
| 1.48.0-1.54.0 | 1.50.0 | 55 ms | 61-88 s / 880 VCs (load-dependent; 878 VCs from 1.52.0) |
| 1.55.0-1.56.0 | 1.55.0 | 50 ms | 72-82 s / 878 VCs (120.6 s under heavy load) |
| 1.57.0-1.58.0 | 1.58.0 | 45.8 ms +/- 3.9 ms | 63.8 s / 1047 VCs (3 runs, 59.1-67.3 s) |

The 1.58.0 warm row is 15 runs. Its cold row is 3 runs from the same session,
and the gnatprove session store is wiped before each one.

## Warm-run syscalls by phase

| Phase | Representative | Warm-run `newfstatat` (strace) |
|-------|----------------|--------------------------------|
| 1.45.0-1.47.0 | 1.47.0 | ~6k |
| 1.48.0-1.54.0 | 1.50.0 | ~6.9k |
| 1.55.0-1.56.0 | 1.55.0 | ~7.3k |
| 1.57.0-1.58.0 | 1.58.0 | 7 508 (~7.5k) |

## Reading the numbers

### 1.45.0-1.47.0 (representative 1.47.0)

- The phase opens with new safety work, not a regression in the I/O layer: the
  correct-version probe validation re-validates each cached system-tool version
  against the identity digest of the installed binary, so a run re-resolves
  every tool's PATH entry. That work and the shared directory-snapshot memo are
  written up on [Performance optimisation
  history](optimisation-history.md).
- The 1.46.0 opt-out machinery is invisible to every warm shape: the marker scan
  runs only after the result-cache lookup misses, so a warm prove hit returns
  before the walk starts. A cold prove pays the count walk once, which is noise
  against the solver floor at 876 VCs.
- The 1.47.0 `-O2 -gnatn` release build is why 1.47.0 represents the phase: the
  previously unoptimised build becomes the release build, pipeline cold reaches
  its best figure (~74 ms), and the stripped binary shrinks to 5.39 MiB. The
  solver-dominated prove-cold shape does not move, and the phase's syscall
  count stays at ~6k, half of the ~12k the walk-skip work left behind.

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
  tree at gnatprove **level 4** and proves clean there with no new VCs, and the
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
  unchanged tree.
- **The manual link check no longer builds the manual a second time.** It shares
  one content-keyed Sphinx build with the offline-manual generator, so the gate
  goes from about 18.6 s to 0.44 s warm and the `tools-check` suite that
  exercises it from 28.9 s to 2.5 s.
- **Go dependency resolution is the one feature that adds work, and it is
  bounded.** Each vendored Go component costs one `modules.txt` lookup and two
  licence-file probes. The self tree has no vendored component, so no figure in
  this column can see that cost; on a synthetic tree with 100 vendored Go
  modules the new build reads 39.7 ms against a 40.9 ms base, inside the spread.
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
- **Every adacovex-side shape is flat or better than the closed
  1.55.0-1.56.0 column.** Pipeline warm is 35.5 ms against the closed phase's
  41 ms, prove warm is 45.8 ms against 50 ms, and pipeline cold is 62.3 ms
  against 66 ms. Warm `newfstatat` is 7 508 against ~7.3k, so the tree's I/O
  floor held while the manifest package gained 19 separate bodies.
- **The VC count grew by a fifth and the prove-cold row still improved.** C7
  moved thirteen in-package subprograms into the proved set, taking the
  campaign from 878 VCs in 1.55.0 to 1047. The cold prove row is 63.8 s at
  1047 VCs against the closed phase's 72-82 s at 878 VCs. The 169 extra checks
  cost no measurable wall, because the row is bound by the solver's time on the
  checks that were always there. Read that comparison as approximate: the
  closed figures were taken at higher loads.
- **H2 shrank the campaign while clearing every prove warning, and that moved
  the cold row by nothing.** Removing the seven dead initialisers the plain way
  would have cost seven extra initialisation checks, landing at 1060.
  Restructuring the five declarations so each initial value is live instead took
  the campaign to 1047, six below the 1053 that C7 alone reached, with no
  warnings. The check count is a reported number, and this release moved it by
  13 without moving the wall.
- **The manifest split did not shorten the build, and the plan recorded that
  rather than assuming it.** 1.57.0 split the slowest body in the tree into 19
  separate bodies, on the expectation that it would shorten the critical path of
  a parallel build. It did not: an Ada separate body shares its parent's `gnat1`
  invocation, so the file split but the compile did not. Measured with the load
  recorded, the original tree built in 60.7 s and 62.7 s and the split tree in
  57.3 s and 59.8 s. That moves no row above, but it is the phase's main
  negative result.
- **The fully cold clone shape costs the same as prove cold, and the apparent
  gap in the bench is measurement order, not work.** The recorded row reads
  78.0 s against 63.8 s, but the clone scenario runs last in `just bench`, so
  the earlier scenarios have already loaded the box. A paired comparison settles
  it, running the two shapes back to back with the load in front of each. Across
  three paired rounds, the one pair at comparable load (16.8 against 14.4) put
  the clone at 68.8 s and prove cold at 70.2 s, so the clone was not slower. The
  round that produced the recorded gap ran the clone at load 11.6 against prove
  cold at 1.1.
- **The prove warm path got a correctness fix, not a speed-up.** H1 restored a
  truthfulness gap in the short-circuit: a cache hit that failed to restore a
  usable summary used to print "reusing prior proof" and return success without
  running the prover. The runner now falls through to a real gnatprove run. The
  warm row is unaffected, because a healthy warm hit was already a cache hit.
- `just prove` on an unchanged tree measures 1.12 s, where `./bin/covex prove`
  alone costs 45.8 ms. The stripped binary is 6.0 MiB against 9.5 MiB
  unstripped, so the phase is 36.6 percent smaller after `strip`. The Ada_CRDT
  second datapoint reads 27.6 ms warm and 48.0 ms cold.

### Across every phase

- The prove-cold row is gnatprove's own cost and tracks the VC count (39.1 s at
  876 VCs; the growth past that point is the proved multi-pair IR slice and the
  C7 opt-in sweep, see [ir.md](../ir.md)). It is paid once per session, not per
  run: with the result cache wiped but the gnatprove session intact, the same
  run is ~1.1 s.
- **A benchmark on the self tree cannot find a vendored-code regression.** The
  self tree has zero vendored components, so a change that only touches
  vendored code is invisible to it. Measure such a change on a fixture with
  the shape it touches, paired against a build of the base commit.
- `just prove` on an unchanged tree is not the warm short-circuit either. The
  target also regenerates the bundled manual and the dashboard template and
  re-checks the generators, so it costs about 1.12 s where `./bin/covex prove`
  alone costs 46 ms.
- A warm hit restores `gnatprove.out` since 1.43.0: the cache stores the summary
  content, so a hit on a tree whose `obj/gnatprove/` was wiped reports Platinum
  at the VC count of the run that produced it. Before 1.43.0 the cache stored
  only a success marker, so such a hit reported Stone / 0 VCs.
- Proof effort is a solver-time dial. `--level=1` cold doubles the wall
  (~35 s to ~68 s at `-j0` here) at the same 876 VCs, because level 1 re-tries
  each check with stronger solver configurations. Lower levels are not strictly
  faster; `--level=0` cold is ~35 s.
- CPU use stays bounded on developer machines: the default job count is
  `cores - 2` (all cores inside CI), so gnatprove never starves the desktop.