# Pipeline, prove, build, and docs timings

A timing is a mean of the stated number of runs, with the standard deviation beside it. `just perf-report` uses hyperfine when it is installed and a wall-clock loop otherwise, and the tool that measured each row is stated under the table. The cold shapes wipe only a temporary cache, so the tree's own cache and gnatprove session stay intact. The build profile in the host profile decides the absolute values: a development build carries runtime checks and an optimised release build is faster.

<!-- perf-report:begin -->
Measured on adacovex `1.75.0` on 2026-11-24.

| Scenario | Mean | Std. dev. | Runs | Command |
|----------|------|-----------|------|---------|
| pipeline cold | 6.02 s | 811.8 ms | 5 | `./bin/adacovex --cache-dir=/tmp/adacovex-perf-report-yqd4og9l` |
| pipeline warm | 5.93 s | 425.1 ms | 10 | `./bin/adacovex --cache-dir=/tmp/adacovex-perf-report-yqd4og9l` |
| prove warm | 6.01 s | 550.0 ms | 5 | `./bin/adacovex prove --cache-dir=/tmp/adacovex-perf-report-prove-u7k5yuvq` |
| build warm | 5.34 s | 694.5 ms | 3 | `/usr/bin/python3 tools/build.py --release` |
| docs cold tree | 696.0 ms | 117.8 ms | 2 | `/usr/bin/python3 tools/gen-docs.py` |
| docs fresh | 108.6 s | 7.94 s | 2 | `/usr/bin/python3 tools/gen-docs.py --fresh` |

Measured with: hyperfine.
<!-- perf-report:end -->

## Reading a row

Pipeline cold pays the scan, the SBOM walk, and the renderers with an empty result cache. Prove warm serves the stored proof after one content hash, so it measures startup and the hash, not the solver. A long prove cold run is the solver at work, and the proof timing page explains the phases behind it.

The `docs fresh` row is a clean Sphinx build plus the full re-encode. The `docs cold tree` row is the same command on a fresh clone: the committed spec already records the sources, so Sphinx does not run.

The per-phase proof table is on [Prove timing and the optimisation review](../contributing/perf/prove-timing.md).
