# Performance and benchmarks

adacovex is a zero-dependency CLI, and its hot path is the assessment pipeline.
The numbers below are the result a user cares about: how long a run takes and
which cache shape produces it. The method, the benchmark tools, and the
per-phase proof timings live in the contributor guide, so this page reports
results and links to the evidence.

## The shapes that matter

| Shape | Command | What makes it fast or slow |
|-------|---------|----------------------------|
| Pipeline cold | `adacovex --cache-dir=<fresh>` | Scans and renders everything; the current mean is on [timings](../stats/timings.md) |
| Pipeline warm | `adacovex --cache-dir=<populated>` | Serves scan and graph results from the cache |
| Prove warm | `adacovex prove` on an unchanged tree | One content hash, then the stored proof |
| Prove cold | `adacovex prove --no-cache` with `obj/gnatprove/` wiped | The solver dominates; the trend across releases is on [prove timing](../contributing/perf/prove-timing.md) |
| Build no-op | `just build` on a built tree | The generators rewrite only changed specs; the mean is on [timings](../stats/timings.md) |

An entry older than its TTL (7 days by default) is a miss, so a cache
restored long after a project changed cannot serve a stale record. The age
comes from the entry header, not the file mtime, which a CI restore rewrites.

The result cache is content-addressed per file, so an edit costs only the file
it touches. The proof cache also records one entry per unit and reports
`N/M unit(s) hit`; a one-unit edit keeps the other unit entries. gnatprove
still receives one invocation for a partial edit, because the project proof is
assembled from one run, and its session store
(`<target>/obj/gnatprove/`) absorbs the solver cost on a warm tree.
`--no-cache` bypasses the adacovex side; wiping the session store as well gives
the true cold shape.

## Reading a number

A slow first run on a fresh clone is expected: there is no result cache, no
gnatprove session, and no `gnatprove.out`. A slow run on a warm tree is not,
and the `--verbose` step banners show where the time went. A full `just check`
prints a per-gate timing table after its summary, so a slow gate names itself.

Watch mode does not change these figures. The server rescans through the same
result cache every two seconds, so an unchanged tree costs one content hash per
spec file.

## Where the method lives

The current figures, with the host profile and the command behind each one,
are on [Measured figures](../stats/index.md). The benchmark categories and
how to reproduce them are on
[Benchmarking adacovex](../contributing/perf/index.md). The per-phase `just
prove` timing table and its representative-version rule are on [Prove timing
and the optimisation review](../contributing/perf/prove-timing.md). The
reverse-chronological record of the work behind the numbers is on
[Performance optimisation history](../contributing/perf/optimisation-history.md).
