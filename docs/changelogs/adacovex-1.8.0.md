# adacovex 1.8.0

Date: _2026-08-13_

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
- **Cache eviction fixes.** The cache root is now stored without a trailing
  separator, and the eviction helpers (`Count_Files`, `Oldest_File`) guard on
  `Ada.Directories.Kind` instead of `Exists`, which returns False for a bare
  directory on some GNAT versions. Together these make `--cache-max` eviction
  actually enforce the entry cap (previously all entries were retained).
- **HLR completeness.** `HLR-CACHE` (Result caching) and `HLR-CPU`
  (Cross-platform CPU core detection) are now defined in
  `docs/compliance/HLR.md`, removing the orphan source tags and restoring
  **DAL-C Achieved** in strict mode.
- **Alire manifest compatibility.** `auto-gpr-with` is expressed in its boolean
  form (`true`); the string form `auto-gpr-with = "adacovex.gpr"` is rejected
  by the released `alr` 2.1.1 (`Cannot read valid property`), which blocked
  `alr build` and therefore `make build` / `make test` / `make run-self`.
- **Fresh proof campaign.** `make prove` re-ran gnatprove 15.1.0 against the
  current tree: **Platinum**, 503/503 VCs proved across 38 analyzed units,
  0 unproved checks. Self-assessment claims in the crate manifest updated to
  match (Platinum 503/503, 336/336 native tests, 100% docstrings).
- Version bumped to 1.8.0.