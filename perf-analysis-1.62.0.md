# Performance Analysis: adacovex v1.62.0 (proof timing)

Recorded on 2026-10-18. The 1.61.0 record is `perf-analysis.md` in the same
directory. Phase collation (closing the open prove-timing phase and opening
the next one with its own representative) is deferred to v1.63.0; until then
`docs/contributing/perf/prove-timing.md` keeps its three rows and 1.58.0 as
the open phase's representative.

## Benchmark machine

- EndeavourOS, x86_64, 12 logical cores, gnatprove 16.1.0
- Release profile (`tools/build.py --release`, `-O2 -gnatn`), binary
  10 180 128 bytes unstripped
- `/proc/loadavg` recorded beside every figure, per the prove-timing rule

## Proof timing metrics (hyperfine 2.0.0, `just bench` prove shapes)

| Category | Command | Wall time | Load (1 min) before |
|----------|---------|-----------|---------------------|
| Prove cold | `adacovex prove --no-cache --cache-dir=<fresh>`, result cache and `obj/gnatprove/` session wiped each run | mean 64.472 s +/- 4.202 s (59.701-67.623 s, 3 runs) | 0.78 |
| Prove warm | `adacovex prove --cache-dir=<populated>` | 54.1 ms +/- 3.2 ms (48.9-60.5 ms, 15 runs + 2 warm-up) | 2.83 |

The first cold sample (3 runs at load 1.30) read 60-66 s and agreed with the
second; the figures above are the second sample, taken at the lower load with
per-second output. The warm sample ran after the cold pass on the same box,
so its load is the decay tail of that pass, not a steady 2.8.

## Proof campaign

- Total 1054 VCs: 196 flow (19%), 858 provers (81%), 0 justified, 0
  unproved, both from the cold run's `gnatprove.out`.

## Key findings

### 1. The prove-cold wall did not move while the campaign grew by 32 VCs

1.61.0 recorded 60-72 s at 1022 VCs; 1.62.0 measures 64.5 s +/- 4.2 s at
1054 VCs. The growth (the install classifier, the server routes, the Windows
shell helpers of C4-C9) lands inside the solver variance of a run that is
bound by the checks that were always there. This is the phase's fourth
confirmation of that reading.

### 2. The warm short-circuit stayed at the phase's floor

54.1 ms +/- 3.2 ms against the 53.3 ms recorded for 1.61.0 (taken at load
0.74, while this sample sits at load 2.8 on a shared box). The
difference is inside the noise of the two samples; the short-circuit still
serves the stored pair from the content-keyed result cache.

### 3. Nothing in this release touches a proven hot path

v1.62.0's Ada work is the structural manifest readers, the install
classifier, the server info routes, the tldr and man installers, and the
Windows VCS shell family. None of it sits on the prove warm path or the
solver's critical path, which is what both rows show.

## Recommendations for v1.63.0

1. Collate the prove-timing phases as `plan.md` P3 sets out: close the
   1.57.0- phase, open the next one seeded with a complete metric set, and
   pick one representative for it. This record and `perf-analysis.md` are
   the two candidate seeds.
2. Keep reading every cold figure with its load: the two cold samples here
   were taken at load 1.30 and 0.78 and straddle the same mean.

## Conclusion

v1.62.0 moves neither proof row. Prove cold is 64.5 s at 1054 VCs and prove
warm is 54.1 ms, both inside the open phase's recorded band on a shared box.
The numbers are here for the 1.63.0 collation, not promoted into the phase
table.