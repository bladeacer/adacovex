# Docs bundle size and cost

The offline manual is one generated Ada spec that carries every page, stylesheet, script, and badge. Its size is the bytes the binary must hold. The cost is `tools/gen-docs.py` in two shapes: a tree with no Sphinx build directory (the committed spec's fingerprint already records the sources) and a full rebuild.

<!-- perf-report:begin -->
Measured on adacovex `1.75.0` on 2026-11-25.

| Reading | Value |
|---------|-------|
| spec size | 2.6 MiB (2733237 bytes) |
| bundled assets | 294 |
| source fingerprint | `8da559610755100fdf786171ad0f429252e0bd0fc315cb65da387dfd691ea85d` |
| docs cold tree | 69.0 ms |
| docs fresh | 11.9 s |
<!-- perf-report:end -->

The rebuild decision tree and the encoder rules are on [The bundled offline manual](../usage/dashboard-docs.md). The build-phase timings that run beside it are on [Timings](timings.md).
