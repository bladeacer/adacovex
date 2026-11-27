# Docs bundle size and cost

The offline manual is one generated Ada spec that carries every page, stylesheet, script, and badge. Its size is the bytes the binary must hold. The cost is `tools/gen-docs.py` in two shapes: a tree with no Sphinx build directory (the committed spec's fingerprint already records the sources) and a full rebuild.

<!-- perf-report:begin -->
Measured on adacovex `1.76.0` on 2026-11-27.

| Reading | Value |
|---------|-------|
| spec size | 2.6 MiB (2762735 bytes) |
| bundled assets | 297 |
| source fingerprint | `b53ce9e58ab59c3cbc975e0726836e55511836050088d5c35507c52b8ae23121` |
| docs cold tree | 158.5 ms |
| docs fresh | 21.8 s |
<!-- perf-report:end -->

The rebuild decision tree and the encoder rules are on [The bundled offline manual](../usage/dashboard-docs.md). The build-phase timings that run beside it are on [Timings](timings.md).
