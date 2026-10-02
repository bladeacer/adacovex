# The 1.55.0 timing re-baseline

This page holds the timing figures taken with the 1.55.0 work and the method
that makes a figure on this machine comparable. The per-phase table and the
reading notes live on [Prove timing and the optimisation
review](prove-timing.md); this page is the detail behind that phase's
re-measurement.

## Why a re-baseline was needed

The phase table already carried a prove-cold figure, but it was measured as a
small hyperfine sample at an unstated machine load. This machine is shared,
and the load moves the cold figure by 50 percent or more on the same binary
and the same cache state. A figure without a load beside it is not
comparable, so the 1.55.0 work re-measured every shape with
`/proc/loadavg` recorded next to it.

## Method

- **Machine.** 12 logical cores, 10 proof jobs, gnatprove 16.1.0 at
  `--level=4`, resolved from `~/.adacovex/toolchain/`. Sphinx 9.1.0, Python
  3.14.7, hyperfine 1.20.0, strace 7.2.
- **Tree.** The adacovex self tree, binary `bin/adacovex`, unstripped dev
  build.
- **Load.** `/proc/loadavg` read immediately before each sample. A sample
  taken while the load is rising is discarded and retaken, because the
  1-minute average lags the run.
- **Cross-check.** Every sample is compared against the `Completed in` line
  the binary prints, which measures its own work and is immune to
  process-scheduling noise around it.

## The fully cold shape

This is the shape to read for a first run on a new checkout: the result cache,
the gnatprove session store (`obj/gnatprove/`), and the proof summary are all
absent, so every run pays a from-scratch solver session.

| Sample | Figure | Load |
|--------|--------|------|
| Cold run 1 | 80.2 s | 7.2 |
| Cold run 2 | 81.7 s | 2.3 |
| Cold run 3 | 120.6 s | 21.9 |

Every sample proves 878 VCs with 0 unproved and 0 justified. The two low-load
samples agree within 2 percent, which is the repeatability of the
measurement. The high-load sample is 50 percent slower on identical inputs.

Read the figure as **80-82 s at an idle machine, and up to 121 s under heavy
load**. A cold first run on a fresh clone lands in the same band, because a
clone has no result cache and no session either.

## Every other shape

| Shape | Figure | Load |
|-------|--------|------|
| Prove warm | 58.2 ms +/- 7.7 ms | 2.8 |
| Pipeline warm | 44.1 ms +/- 3.2 ms | 2.8 |
| Pipeline cold | 75.5 ms +/- 4.1 ms | 2.8 |
| Warm `newfstatat` | 8,844 | 3.7 |
| `make prove`, unchanged tree | 2.3-2.5 s | 3.8 |
| Stripped binary | 5.47 MiB | - |
| Bundled manual spec | 1.97 MiB | - |

Each of these sits on the phase's 1.50.0 figures within noise, which is why
1.55.0 folds into the open 1.48.0-1.55.0 phase and 1.50.0 keeps the
representative slot.

## What the three changes cost

None of the three changes in 1.55.0 sits on a measured shape.

- **The tool-probe cache fix** returns a corrupted-fingerprint run to the
  healthy warm floor: 11 subprocess spawns and 976 ms become one spawn and
  57 ms, a 17x reduction. An unchanged healthy blob already cost one spawn
  and 57 ms, so the fix restores the floor rather than setting a new one.
- **The manual link-check dedup** takes the `book-links-check` gate from about
  18.6 s to 0.44 s warm, and the `tools-check` suite that exercises it from
  28.9 s to 2.5 s. It is a build-side gate, not an assessment shape.
- **Go dependency resolution** adds two offline file reads per vendored Go
  component. The self tree has **no vendored component at all**, so none of
  the figures above can see this cost. It was measured separately, against a
  build of the 1.54.0 tree, on a synthetic tree with 100 vendored Go modules
  and a cold result cache:

  | Build | Cold run | `go` spawns |
  |-------|----------|-------------|
  | 1.54.0 (base) | 39.5 ms +/- 3.9 ms | 0 |
  | 1.55.0 before the resolver skip | 561 ms +/- 32.5 ms | 100 |
  | 1.55.0 after the resolver skip | 40.9 ms +/- 3.5 ms | 0 |

  The middle row is the lesson: the first implementation gave the Go resolver
  row a live tool, which made the resolver spawn `go list -m` once per
  component and discard the answer, because the offline read had already
  supplied both fields. The resolver now skips a spawn whose row can add
  nothing the caller lacks. The remaining difference from the base is 100
  extra `newfstatat` and 200 extra `openat` calls across 100 components,
  about 1.4 ms per component.

  **A benchmark on the self tree cannot find this class of regression.** The
  self tree has zero vendored components, so any feature that only touches
  vendored code is invisible to it. Measure a change like that against a
  fixture that actually has the shape it touches.

## Two shapes that are easy to confuse

`make prove` on an unchanged tree costs about 2.3-2.5 s. `./bin/covex prove`
alone costs 58 ms. The difference is the build: the make target also
regenerates the bundled offline manual and the dashboard template and
re-checks the generators. Neither number is a substitute for the other, so
both are reported.

The same applies to the pipeline rows. A warm pipeline run reads 44.1 ms
end to end, while the `Completed in` line the binary prints for the same run
is lower, because the rest is process start and exit. Use the hyperfine figure
for shape comparison and the `Completed in` line to cross-check it.