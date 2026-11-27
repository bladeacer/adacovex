# Docs bundle size and cost

The offline manual is one generated Ada spec that carries every page, stylesheet, script, and badge. Its size is the bytes the binary must hold. The cost is `tools/gen-docs.py` in two shapes: a tree with no Sphinx build directory (the committed spec's fingerprint already records the sources) and a full rebuild.

<!-- perf-report:begin -->
Measured on adacovex `1.76.0` on 2026-11-27.

| Reading | Value |
|---------|-------|
| spec size | 2.6 MiB (2777328 bytes) |
| bundled assets | 297 |
| source fingerprint | `dfb1228cdcab589456beb0dfc787b2300344c84d2566340915bfcaf220c43f90` |
| docs cold tree | 65.3 ms |
| docs fresh | 11.9 s |
<!-- perf-report:end -->

The rebuild decision tree and the encoder rules are on [The bundled offline manual](../usage/dashboard-docs.md). The build-phase timings that run beside it are on [Timings](timings.md).
