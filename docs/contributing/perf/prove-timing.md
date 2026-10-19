# Prove timing and the optimisation review

<!-- no-covex-docs-loc: timing page with a long phase table, line cap does not apply -->

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

The measured phases are 1.55.0-1.56.0, 1.57.0-1.60.0, and 1.61.0-. A
version joins the open phase while the methodology is unchanged; a methodology
shift closes the phase and opens a new one.

The table holds the two most recent closed phases plus the open one. A retired
phase is deleted rather than kept, so the page does not grow without bound, and
whatever still explains a surviving number moves into the "Across every phase"
notes first. The phases retired so far are 1.40.0-1.41.0, 1.42.0-1.44.0,
1.45.0-1.47.0, and 1.48.0-1.54.0; the stat-stamp work behind the warm syscall
floor is written up on [Performance optimisation
history](optimisation-history.md).

**The 1.55.0-1.56.0 phase is closed, with 1.55.0 as its representative.**
1.55.0 opens it and changes the methodology, not only the code: every figure in
this phase is taken with `/proc/loadavg` recorded beside it, because this
machine is shared and the load moves the cold rows by more than 50 percent on
the same binary. 1.56.0 folds in because it edited documentation sources, one
browser script, and Python tooling, and added no Ada unit, so the pipeline and
the prover see the same work as 1.55.0 did. It also re-baselines the fully cold
prove shape, which no earlier phase recorded.

**The 1.57.0-1.60.0 phase is closed, with 1.58.0 as its representative.**
1.57.0 shifts the methodology, because the tree gained a development profile
and a release profile. Every figure on this page is taken on the **release**
profile (`-O2 -gnatn`, no debug information), because that is the binary the
released figures describe. A development build is `-O1 -gnatn -g` and is about
half the serial compile time, so an `-O1` figure is not comparable with an
`-O2` one, and the profile is named beside every number. 1.58.0 folds in
because it changed no measurement methodology: its Ada work is the C7 proof
opt-in sweep and the H2 dead-initialiser fix, both of which the prover sees,
and its other work is documentation, one browser script, and Python tooling.
1.59.0 and 1.60.0 fold in for the same reason, and their notes sit below.
Every number below is hyperfine on the self tree (gnatprove 16.1.0, 12 logical
cores, 10 proof jobs, release profile) unless a note says otherwise.

**The 1.61.0- phase is open, with 1.61.0 as its representative.** The phase
opens at 1.61.0 because its work changes the implementation methodology as well
as the code: the directory-snapshot memo's layout and per-directory cap, the
parallel pre-build generator bundle, and the per-step build-phase profile all
land here. 1.61.0 supplies the phase's complete metric set from
`perf-analysis.md` -- pipeline warm 41.7 ms and cold about 72 ms, prove warm
about 53 ms and cold 60-72 s on 1022 VCs with 0 unproved, 14 106 warm
`newfstatat`, and 5.9 MiB stripped. Every later version in the range folds in
with its figures noted beside the column, never promoted into it.

**Scenario order biases the cold rows, so read every figure with its load.**
Each scenario loads the box, so one measured late inherits the load the earlier
ones left behind. `just bench` prints the load in front of every scenario for
that reason. Compare two shapes paired, not as two rows of one sequential pass:
the clone row below is a case where sequence order alone manufactured an
apparent 14-second gap that a paired run did not reproduce.

## Pipeline timing by phase

| Phase | Representative | Pipeline warm | Pipeline cold |
|-------|----------------|---------------|---------------|
| 1.55.0-1.56.0 | 1.55.0 | 41 ms | 66 ms |
| 1.57.0-1.60.0 | 1.58.0 | 35.5 ms +/- 1.8 ms | 62.3 ms +/- 0.8 ms |
| 1.61.0- | 1.61.0 | 41.7 ms | about 72 ms |

The 1.58.0 rows are one hyperfine session on the release profile at the shipped
1047 VCs: 15 runs for warm and 10 for cold, taken at load 0.59. The 1.61.0 rows
are the analysis file's sample; the reading notes carry the other 1.61.0 samples
with their loads.

## Prove timing by phase

| Phase | Representative | Prove warm (cache short-circuit) | Prove cold (result cache + session wiped) |
|-------|----------------|----------------------------------|-------------------------------------------|
| 1.55.0-1.56.0 | 1.55.0 | 50 ms | 72-82 s / 878 VCs (120.6 s under heavy load) |
| 1.57.0-1.60.0 | 1.58.0 | 45.8 ms +/- 3.9 ms | 63.8 s / 1047 VCs (3 runs, 59.1-67.3 s) |
| 1.61.0- | 1.61.0 | about 53 ms | 60-72 s / 1022 VCs |

The 1.58.0 warm row is 15 runs. Its cold row is 3 runs from the same session,
and the gnatprove session store is wiped before each one.

## Warm-run syscalls by phase

| Phase | Representative | Warm-run `newfstatat` (strace) |
|-------|----------------|--------------------------------|
| 1.55.0-1.56.0 | 1.55.0 | ~7.3k |
| 1.57.0-1.60.0 | 1.58.0 | 7 508 (~7.5k) |
| 1.61.0- | 1.61.0 | 14 106 (~14.1k) |

## Reading the numbers

### 1.55.0-1.56.0 (representative 1.55.0)

- The phase's adacovex-side shapes are flat or slightly better than the retired
  1.48.0-1.54.0 column: pipeline warm 41.3 ms, pipeline cold 66.5 ms, prove
  warm 49.9 ms, and warm `newfstatat` 7.3k, all at load 0.5-0.6. The
  retired phase read 46 ms, 73 ms, 55 ms, and ~6.9k. Nothing in 1.55.0 is on a
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

### 1.57.0-1.60.0 (representative 1.58.0)

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
- **1.59.0 and 1.60.0 fold in, and 1.58.0 keeps the representative slot.**
  Neither changes a measurement methodology: 1.59.0 and 1.60.0 are the
  cross-platform path and time-stamp work plus the task-runner migration, and
  their figures sit inside the column's spread.

### 1.61.0- (representative 1.61.0)

- **The phase's methodology shift is the measurement and the memo.** 1.61.0
  records every figure with `/proc/loadavg` beside it and reads its own profile;
  1.63.0 then changes the directory-snapshot memo's layout and per-directory
  cap, runs the five pre-build generators concurrently, and gives `just bench`
  a per-step build-phase breakdown. The representative is still 1.61.0, because
  its set is complete and every later figure is read beside the column rather
  than picked row by row from different versions.
- **Every 1.61.0 figure is higher than the 1.58.0 column, and the load explains
  most of the gap.** The phase's representative set reads pipeline warm
  41.7 ms (against 35.5 ms), pipeline cold about 72 ms (against 62.3 ms), prove
  warm about 53 ms (against 45.8 ms), and prove cold 60-72 s (against 63.8 s).
  The box was shared throughout, and a figure taken at load 1.0 cannot displace
  one taken at 0.59 on a row the page already documents as load-sensitive, so
  the higher numbers stay with the load named beside them.
- **The 1.61.0 record carries two samples, and the representative uses the
  analysis file's set.** The release note for 1.61.0 read pipeline warm 43.2 ms
  at load 1.04, pipeline cold 69.5-87.8 ms across three sessions at load
  0.61-0.97, prove warm 53.3 ms at load 0.74, prove cold 60-72 s at load 0.9,
  and 7 827 warm `newfstatat` across two `strace` runs;
  `perf-analysis.md` reads 41.7 ms warm, about 72 ms cold, about 53 ms prove
  warm, and 14 106 warm `newfstatat`. The two syscall counts disagree because
  they were taken on different tree states; the 14 106 figure is the one that
  matches this tree before the 1.63.0 memo work measured 14 597, so it is the
  representative's.
- **The prove-cold wall did not move while the campaign shrank by 25 VCs.**
  1.61.0 constrains the `Suggest_Flags` return type and contracts three
  helpers, which takes the campaign from 1047 to 1022 VCs with 0 unproved.
  The cold row is unchanged at 60-72 s against 63.8 s, which is the phase's
  third confirmation that this row is bound by the solver's time on the checks
  that were always there rather than by the check count.
- **The warm stat count tracks the tree's file count, not a new walk.** The
  1.61.0 release note read 7 827 against the 7 508 recorded for 1.58.0, stable
  across two `strace` runs. The path, time-zone, and task-runner work of
  1.59.0-1.60.0 added source files, and the per-file stat set grows with them.
  Treat the trend across phases, not the single step.
- **The 1.62.0 proof figures fold in beside the column.** They were measured on
  this machine on the release profile with `/proc/loadavg` beside each sample:
  prove warm 54.1 ms +/- 3.2 ms (15 hyperfine runs plus two warm-ups, at load
  2.8 on the decay tail of the cold pass before it) and prove cold 64.5 s +/-
  4.2 s (59.7-67.6 s across three runs with the result cache and the gnatprove
  session wiped each time, at load 0.78), both at 1054 VCs with 0 unproved.
  Neither row moves: the cold mean sits inside the 60-72 s the 1.61.0 figures
  read at 1022 VCs, and the campaign's growth to 1054 costs nothing the solver
  variance does not hide already. The full record, with both samples and their
  loads, is `perf-analysis-1.62.0.md` at the repository root, beside the
  1.61.0 record.
- **1.63.0's two fixes fold in with a paired measurement, and the memo is the
  one that moved a number.** The directory memo now packs an entry to 66 bytes,
  caps the memo key at 128 bytes, and raises the per-directory entry cap to 128,
  so `src/parsers` (78 entries) and `docs/api-docs` (84) are memoised instead of
  re-enumerated by every walker. Paired against the pre-change binary on the
  same tree at the same load, pipeline warm reads 46.8 ms +/- 2.6 ms against
  51.8 ms +/- 4.7 ms (-9.7 percent), warm `newfstatat` falls from 14 597 to
  8 142, and the memo reports 131 hits and 60 misses against 105 and 86. The
  process peak resident set grows 1.7 MiB (28.5 to 30.2 MiB) for the wider
  slots. A pinned `perf stat` sample did not put the L1 dcache-miss rate below
  the run-to-run spread, so the syscall count and the wall time are the
  evidence, not the miss rate.
- **The pre-build generators are independent, so 1.63.0 runs them
  concurrently.** The five steps cost 463 ms summed and 295 ms as the bundle
  that `tools/build.py` runs (load 2.7-2.8; 168 ms, 36 percent, of overlap). A
  no-op `just build` therefore reads 609 ms against 732 ms for the serial
  recipe in a paired ten-run sample (-16.8 percent), and the per-step breakdown
  that produced those figures is now part of `just bench`.

### Across every phase

- The prove-cold row is gnatprove's own cost and tracks the VC count (39.1 s at
  876 VCs; the growth past that point is the proved multi-pair IR slice and the
  C7 opt-in sweep, see [ir.md](../ir.md)). It is paid once per session, not per
  run: with the result cache wiped but the gnatprove session intact, the same
  run is ~1.1 s.
- **The retired 1.48.0-1.54.0 phase explains the floor that every later column
  inherits.** Its methodology shift was the deterministic, incremental doc
  bundling of 1.50.0: the generated manual spec became byte-identical between a
  developer tree and a clean build, and both generated bundle specs were
  excluded from the proof-input hash, so a docs or dashboard edit no longer
  invalidated a cached proof or recompiled the 28k-line unit. Its shapes were
  otherwise flat by design -- pipeline warm 46 ms, pipeline cold 73 ms, prove
  warm 55 ms, prove cold 61-88 s at 880 VCs -- because the release removes
  failed work rather than steady work. 1.51.0's encode cache, parallel encoder,
  and incremental Sphinx build folded in as build-side speed-ups that leave the
  emitted spec byte-identical, and 1.52.0's `--level=4` gate folded in because
  the prove subcommand forwards `--level` verbatim.
- **The warm syscall floor is the directory walk, not the prove campaign.**
  The tree's I/O floor was ~6.9k `newfstatat` calls per warm pipeline run in the
  retired phase. The direct-enumeration walker enumerates `src/` and `..`
  entries, and the guard that skips `.` and `..` was added in the v1.61.0 perf
  commit; earlier versions without it would climb into `..` and back down,
  causing path overflow and crashing `covex sbom`. The 1.63.0 memo work then
  cut the count to 8 142 from 14 597 by memoising the directories the old
  64-entry cap rejected.
- **A benchmark on the self tree cannot find a vendored-code regression.** The
  self tree has zero vendored components, so a change that only touches
  vendored code is invisible to it. Measure such a change on a fixture with
  the shape it touches, paired against a build of the base commit.
- `just prove` on an unchanged tree is not the warm short-circuit either. The
  target also regenerates the bundled manual and the dashboard template and
  re-checks the generators, so it costs about 1.12 s where `./bin/covex prove`
  alone costs 46 ms.
- A warm hit restores the proof artefacts since 1.43.0: the cache stores the
  summary content, so a hit on a tree whose `obj/gnatprove/` was wiped reports
  Platinum at the VC count of the run that produced it. Before 1.43.0 the cache
  stored only a success marker, so such a hit reported Stone / 0 VCs. Since
  1.60.0 the cache stores and restores the complete pair (`gnatprove.out` and
  `gnatprove.sarif`), so a warm hit also leaves the `spark-coverage` report and
  its CI gate with the artefacts they read; the hit marker is written only when
  both blobs were cached, and a cache that holds the summary alone falls through
  to a real gnatprove run.
- Proof effort is a solver-time dial. `--level=1` cold doubles the wall
  (~35 s to ~68 s at `-j0` here) at the same 876 VCs, because level 1 re-tries
  each check with stronger solver configurations. Lower levels are not strictly
  faster; `--level=0` cold is ~35 s.
- CPU use stays bounded on developer machines: the default job count is
  `cores - 2` (all cores inside CI), so gnatprove never starves the desktop.
