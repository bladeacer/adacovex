# Performance

adacovex is a zero-dependency CLI.  Its hot path is the assessment pipeline
(scan -> patch -> doc metrics -> proof parse -> test parse -> DAL assess ->
render, plus the SBOM).  This page defines the benchmark categories and the
expected numbers on a typical machine.

The benchmark how-to and the raw sample output are on
[Benchmarking](perf-benchmarks.md).  The per-release `make prove` timings,
grouped into phases, are on [Prove timing and the optimisation
review](perf-prove-timing.md); the reverse-chronological record of the work
behind the numbers is on [Performance optimisation
history](perf-optimisation-history.md).

## Benchmark category reference

adacovex has two *caches* and one *build step*; every benchmark category is
defined by which of them are populated:

- the **result cache** (`~/.adacovex/cache/<version>/`, or `--cache-dir`):
  adacovex's own content-addressed store of scan, graph, and prove results;
- the **gnatprove session store** (`<target>/obj/gnatprove/`):
  gnatprove's internal per-unit session, which re-analyses only changed
  units;
- the **build** (`alr build`, run by every `make` recipe that proves): a
  no-op takes ~0.3 s when built; `make clean` forces a full recompile.

| Category | Command | Result cache | gnatprove session | What it measures |
|----------|---------|--------------|-------------------|------------------|
| Pipeline cold | `adacovex --cache-dir=<fresh>` | empty | n/a (not spawned) | Scan, parse, DAL, SBOM, render with no cached results |
| Pipeline warm | `adacovex --cache-dir=<populated>` | hit | n/a | Cache-hit path: startup, walks, blob deserialisation |
| Prove cold | `adacovex prove --no-cache --cache-dir=<fresh>` | empty | **wiped** | Truly cold proving: full solver run + everything in pipeline cold (a first CI invocation on a bare runner) |
| Prove warm | `adacovex prove --cache-dir=<populated>` | hit | n/a | The short-circuit: one content-hash of the inputs, then serve the stored proof (a developer on an unchanged tree) |

Two further shapes exist and are worth recognising (one-time-per-session
states, not steady states, so they are not benchmarked):

- *adacovex-side cold*: `prove --no-cache` with the result cache wiped but
  `obj/gnatprove/` populated.  gnatprove's session absorbs the solver cost;
  the run re-does only the adacovex-side work (~1.3 s here) -- what a
  `--cache-dir` change on a built machine costs.
- *partial session*: `obj/gnatprove/` holds only some units (after a
  targeted `gnatprove -u` run).  A prove miss then re-analyses the missing
  units and lands between the two cold shapes.  A full `make prove` always
  ends with a complete session, so back-to-back runs sit at prove-warm.

## What the numbers mean

Figures are from `make bench`/`perf-bench` on the benchmark machine
(hyperfine, cold + warm per scenario).  They shift with the machine and the
codebase; what matters is the shape:

- **Pipeline cold ~74 ms**: dominated by source scanning (Ada file
  enumeration and SHA-256 of every scanned file), the SBOM tree walk and
  word scan, and the renderers.  Nothing here can be skipped: the result
  cache is empty, so every file must be read and hashed at least once
  (tool-version probes and ecosystem-metadata lookups live per-machine,
  outside the result cache, and survive cache wipes).
- **Pipeline warm ~43 ms**: the on-disk result cache skips re-parsing
  unchanged sources; the stamp fast-path skips the per-file SHA-256
  entirely (a file unchanged in size is not re-hashed); the tools-set
  cache skips the SBOM dev-dependency word scan and the tool probes.  The
  remaining time is process startup, directory walks, and blob
  deserialization.
- **Prove cold ~40-110 s** (load-dependent on this desktop): a from-scratch
  solver run over 876 VCs plus the whole pipeline, dominated by gnatprove
  itself (the ~196 s of user CPU across the proof jobs is the stable part)
  and paid once per gnatprove session, not per run.
- **Prove warm ~53 ms**: the prove result cache serves the stored proof
  after one content-hash of the input tree, and restores the cached
  `gnatprove.out` so the assessment parses it -- the number a developer
  hits on an unchanged tree.  Back-to-back `make prove` runs sit here (the
  adacovex run is ~0.05 s; the rest of the wall is `alr build`).
- System time is the tell: ~22 ms on pipeline cold (file I/O), ~14 ms on
  pipeline warm.

## How the timing table is kept

`docs/contributing/perf-prove-timing.md` keeps one column per **phase**: a
range of versions whose implementation methodology is largely similar.  Each
phase carries one representative version that supplies the phase's complete
metric set.  A new version folds into the open phase while the methodology
holds; a methodology shift closes the phase and opens a new one.

## CI

CI runs the self-assessment with result caching disabled where determinism matters
(`--no-cache`-equivalent fresh dirs).  The `make` gates are timed loosely: timings
are informational only, because a gate that fails on a slow runner helps nobody.
The `bench` target is not part of `make check`; it is run by hand before releases.

## When the numbers regress

Run `make perf-bench` first: it reports the CPU break-down and the strace
syscall counts.  The usual suspects are a new tree walk that re-enumerates
a directory a cache already covers, or a new per-file hash that the stamp
fast path does not cover.  `make run-ada-crdt` is a handy second datapoint
on a smaller tree.
