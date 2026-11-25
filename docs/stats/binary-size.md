# Binary size

The released binary carries the offline manual as generated Ada string constants, so its size is a product decision as much as a build result. The size below is the development profile the task built, and a release build is smaller.

<!-- perf-report:begin -->
Measured on adacovex `1.75.0` on 2026-11-24.

| Shape | Size |
|-------|------|
| `bin/adacovex` | 10.7 MiB (11269352 bytes) |
| after `strip` | 7.1 MiB (7442032 bytes) |
| stripped saving | 34.0% |
<!-- perf-report:end -->

The strip figure is a copy in the temporary directory; `bin/adacovex` itself is never modified. The bundled manual's share of the binary is on [Docs bundle size and cost](bundle.md).
