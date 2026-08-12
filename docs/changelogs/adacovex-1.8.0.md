# adacovex 1.8.0

Date: _2026-08-12_

## Changes

- **Result caching.** Analysis results are cached on disk under
  `~/.adacovex/cache/<version>/`, keyed by the SHA-256 of each input artifact.
  Unchanged source files serve their parsed `Package_Info` from the cache
  instead of being re-scanned; unchanged `gnatprove.out` and test-result files
  likewise serve their parsed summaries. Each `Put_Cached` refreshes the
  newest-entry tracking and evicts oldest-first when the entry cap is reached.
  Cache effectiveness (`X hit(s), Y miss(es), Z evicted`) is reported in the
  ANSI report.
- Controlled by `--cache` (default on), `--no-cache`, `--cache-dir=PATH`, and
  `--cache-max=N` (default 4096). `--no-cache` forces every run to re-scan /
  re-parse / re-prove, which is useful when artifacts change but keep the same
  content hash.
- Version bumped to 1.8.0.
