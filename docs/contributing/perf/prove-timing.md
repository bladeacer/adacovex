# Prove timing and the optimisation review

The `prove` subcommand sets the proof performance, so this page measures that
subcommand at the binary level (`./bin/covex prove`). The method is on
[Benchmarking adacovex](benchmarks.md), the work behind each figure is on
[Performance optimisation history](optimisation-history.md), the 1.55.0 detail
is on [The 1.55.0 timing re-baseline](prove-rebaseline.md), and the latest
figures are on [Measured figures](../../stats/index.md). Every figure is a
release-profile sample with its load average, and the host profile is on the
measured-figures page.

## How the phase table works

A phase is a range of versions with one implementation methodology. Each phase
has exactly one representative version, and that version supplies the complete
metric set for its column. The page never picks the best value of each row from
different versions.

The table holds the three most recent closed phases and the open one, and a
retired phase is deleted. Anything that still explains a surviving number moves
to "Across every phase" first.

A version folds into the open phase while the methodology holds, and a
methodology shift closes the phase. From 1.75.0 the open column is re-measured
at each version, so its representative is the latest measured version.

A row that the measuring session did not take reads "not measured". A number
from an older version never fills the gap.

## The phases

- **1.55.0-1.56.0** (closed, representative 1.55.0): the load average joined
  every figure, and the fully cold prove shape was recorded for the first time.
- **1.57.0-1.60.0** (closed, representative 1.58.0): the tree gained a
  development profile and a release profile, so only figures from one profile
  are comparable.
- **1.61.0-1.62.0** (closed, representative 1.62.0): every figure records
  `/proc/loadavg`, because this shared box moves the cold rows by more than 50
  percent on one binary.
- **1.63.0-1.75.0** (open, representative 1.75.0): the packed directory memo,
  the concurrent pre-build bundle, and the `just bench` step breakdown opened
  the phase. 1.69.0-1.74.0 fold in: the campaign grew to 1060 VCs and the
  tooling moved, but the prove path and the measurement did not.

## Pipeline timing by phase

| Phase | Representative | Pipeline warm | Pipeline cold |
|-------|----------------|---------------|---------------|
| 1.55.0-1.56.0 | 1.55.0 | 41 ms | 66 ms |
| 1.57.0-1.60.0 | 1.58.0 | 35.5 ms +/- 1.8 ms | 62.3 ms +/- 0.8 ms |
| 1.61.0-1.62.0 | 1.62.0 | 41.7 ms | about 72 ms |
| 1.63.0-1.75.0 | 1.75.0 | 5.93 s +/- 425 ms | 6.02 s +/- 812 ms |

## Prove timing by phase

| Phase | Representative | Prove warm (cache hit) | Prove cold (cache and session wiped) |
|-------|----------------|------------------------|--------------------------------------|
| 1.55.0-1.56.0 | 1.55.0 | 50 ms | 72-82 s / 878 VCs |
| 1.57.0-1.60.0 | 1.58.0 | 45.8 ms +/- 3.9 ms | 63.8 s / 1047 VCs |
| 1.61.0-1.62.0 | 1.62.0 | 54.1 ms +/- 3.2 ms | 64.5 s +/- 4.2 s / 1054 VCs |
| 1.63.0-1.75.0 | 1.75.0 | 6.01 s +/- 550 ms | not measured (see the 1.75.0 notes) |

## Warm-run syscalls by phase

| Phase | Representative | Warm-run `newfstatat` (strace) |
|-------|----------------|--------------------------------|
| 1.55.0-1.56.0 | 1.55.0 | ~7.3k |
| 1.57.0-1.60.0 | 1.58.0 | 7 508 |
| 1.61.0-1.62.0 | 1.62.0 | 14 106 |
| 1.63.0-1.75.0 | 1.75.0 | 282 020 |

## Reading the numbers

### 1.75.0 (open phase)

- The column is one session on 2026-11-24 on the release profile and a 12-core
  i7-1255U, at load 18.5 because other work shared the box: pipeline warm
  5.93 s (10 runs), pipeline cold 6.02 s (5 runs), and prove warm 6.01 s (5
  runs). The campaign is 1060 VCs with 0 unproved, the stripped binary is
  7 442 032 bytes (7.1 MiB) against 11 269 352 bytes raw, the warm run makes
  282 020 `newfstatat` calls, and the suite is 2494 tests.
- **The warm stat count regressed, and a stat count does not follow the load.**
  The 1.63.0 column read 7 924 calls, so this session reads 35 times more.
  The trace shows each directory stat'ed about 52 times per run, and the macOS
  marker `/System/Library/CoreServices` 525 times; that path exists only on
  macOS, so on Linux the stat fails by design and reveals how often the
  platform probe repeats. The walk no longer shares one snapshot.
- An earlier session read 2.72 s on this tree at load 3.2, so read the walls as
  the loaded session and not as a second regression. [Technical debt
  register](../debt.md) entry D16 owns the fix.
- Prove cold is not measured. Three cold runs did not finish inside the session
  budget on this shared box, and another version's number would not describe
  1.75.0. The row stays a gap until the next session takes it.
- The 1.63.0 record of this phase is the paired evidence that its release did
  not regress: the packed memo cut one tree from 13 428 to 7 924 stats and read
  5 ms faster warm against the v1.62.0 binary.
- The D16 fix landed after this column and reads 18 904 stats, 378 ms pipeline
  warm, and 680 ms prove warm at load 0.7, on the same release profile and the
  same tree. Those figures are the v1.76.0 column when that version is
  measured; this row stays the 1.75.0 record.

### 1.55.0-1.62.0 (the three closed phases)

- **1.55.0 removed failed work.** A stale tool fingerprint re-probed on every
  run, so a corrupted blob cost 11 spawns and 976 ms against one spawn and
  57 ms. One shared Sphinx build also took the manual link check from 18.6 s to
  0.44 s warm.
- **1.58.0 is the release-profile phase.** The development build is
  `-O1 -gnatn -g` and the release build is `-O2 -gnatn`, so an `-O1` figure
  is not comparable with an `-O2` one. The campaign grew from 878 to 1047 VCs
  and the cold row still improved, because the solver's time on the checks that
  were always there sets that row.
- **1.62.0 is the load-recorded phase.** Pipeline warm 41.7 ms, prove warm
  54.1 ms, and 14 106 warm stats, each read beside its load. One binary read 36
  percent apart in two sessions, so compare two versions with a paired run on
  one box.

### Across every phase

- The prove-cold row is gnatprove's own cost and tracks the VC count. It is paid
  once per session: with the result cache wiped but the session intact, a run
  takes about 1.1 s.
- The warm syscall floor is the directory walk. The 1.63.0 memo took it from
  14 597 to 7 924 by memoising the directories the old 64-entry cap rejected,
  and the 1.75.0 regression is that walk with the memo's benefit lost.
- A session is not a measurement. Treat an absolute figure as the shape of its
  session, and prove a difference with a paired run.
- The self tree has no vendored component, so a change that only touches
  vendored code is invisible here. Measure it on a fixture with that shape,
  paired against the base commit.
- `just prove` on an unchanged tree costs about 1.1 s, because the target also
  regenerates the manual and the dashboard. The measured shape is
  `./bin/covex prove` alone.
- Proof effort is a solver-time dial: `--level=1` cold doubles the wall at the
  same VC count, and `--level=0` cold is about 35 s. The default job count is
  `cores - 2`, and all cores inside CI.
