# Result-cache hit rate

The result cache is content-addressed per file, so a second run on an unchanged tree is a hit for every scanned file. The readings below come from one warm-up run and one captured run, so they describe the steady state and not a cold start.

<!-- perf-report:begin -->
Measured on adacovex `1.75.0` on 2026-11-24.

| Reading | Count |
|---------|-------|
| cache hits | 49 |
| cache misses | 0 |
| evicted entries | 0 |
| hit rate | 100.0% |
<!-- perf-report:end -->

An entry older than its lifetime (7 days by default) is a miss, and the age comes from the entry header rather than the file mtime. `just check`'s own cache line reports the same three counts for the gate run.
