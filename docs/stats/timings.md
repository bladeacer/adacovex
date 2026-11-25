# Pipeline, prove, build, and docs timings

A timing is a mean of the stated number of runs, with the standard deviation beside it. `just perf-report` uses hyperfine when it is installed and a wall-clock loop otherwise, and the tool that measured each row is stated under the table. The cold shapes wipe only a temporary cache, so the tree's own cache and gnatprove session stay intact. The build profile in the host profile decides the absolute values: a development build carries runtime checks and an optimised release build is faster.

<!-- perf-report:begin -->
Measured on adacovex `1.75.0` on 2026-11-25.

| Scenario | Mean | Std. dev. | Runs | Command |
|----------|------|-----------|------|---------|
| pipeline cold | 412.4 ms | 5.1 ms | 5 | `./bin/adacovex --cache-dir=/tmp/adacovex-perf-report-tswg6hk1` |
| pipeline warm | 377.9 ms | 8.1 ms | 10 | `./bin/adacovex --cache-dir=/tmp/adacovex-perf-report-tswg6hk1` |
| prove warm | 680.3 ms | 3.6 ms | 5 | `./bin/adacovex prove --cache-dir=/tmp/adacovex-perf-report-prove-7nc5n03i` |
| build warm | 313.2 ms | 3.9 ms | 3 | `alr build` |
| docs cold tree | 69.0 ms | 3.0 ms | 2 | `/usr/bin/python3 tools/gen-docs.py` |
| docs fresh | 11.9 s | 880.0 ms | 2 | `/usr/bin/python3 tools/gen-docs.py --fresh` |

Measured with: hyperfine.
<!-- perf-report:end -->

## Reading a row

Pipeline cold pays the scan, the SBOM walk, and the renderers with an empty result cache. Prove warm serves the stored proof after one content hash, so it measures startup and the hash, not the solver. A long prove cold run is the solver at work, and the proof timing page explains the phases behind it.

The `docs fresh` row is a clean Sphinx build plus the full re-encode. The `docs cold tree` row is the same command on a fresh clone: the committed spec already records the sources, so Sphinx does not run.

The per-phase proof table is on [Prove timing and the optimisation review](../contributing/perf/prove-timing.md).
