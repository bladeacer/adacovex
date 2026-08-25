# adacovex 1.28.0

Date: _2026-08-25_

Version bumped 1.27.0 -> 1.28.0.

## Changes

### C1: perf.md updated with measured numbers and optimisation history

`docs/perf.md` now records the 1.28.0 benchmark figures (cold ~0.6 s, warm
~40 ms on the self-assessment, 9.0 MiB binary / 3.6 MiB stripped), the new
"when the numbers regress" workflow, and the full optimisation history in
reverse-chronological order so each future round can see which assumption
drove the previous change.

### C2: Stamp fast-path hashing for the scan cache

The warm-path CPU profile showed GNAT.SHA256 at ~48%: every `.ads` file was
fully re-read and re-hashed on every run just to compute its cache key,
even when the content was unchanged. `Adacovex.Cache.Hash_File` now keeps
an in-memory path -> (size, digest) stamp map and serves the recorded
digest without opening the file when the size still matches. The fast path
is per-process (the map is not persisted), so an edited file always
re-hashes: its size differs or the map is empty. The same map means the SBOM
tree-walk hashing reuses the digests the source scan computed in the same
run, collapsing two hash passes into one read plus one size check. Warm
user time dropped by roughly a third on the self-target.

### C3: SBOM system-tool referenced-set cache

`Discover_System_Dev_Deps` walked the whole project tree and word-scanned
every dev-facing file on every run to collect the system-tool dev
dependencies for the SBOM. A profile showed that word scan at ~62% of warm
CPU. The referenced-tool set is now cached on disk under a key that covers
every input the scan reads: the content hash of exactly the files the scan
reads (same `Should_Scan` predicate and directory exclusions as the main
walk), the curated tool-table names (in case the table changes within a
release), and a namespace salt. An unchanged project serves the set from one
small cache blob and skips the tree walk and every file read; any edit to a
scanned file changes the key and forces a re-scan. Cold runs pay one extra
tree walk (about 8% of cold); warm runs skip the entire SBOM scan, taking
the warm self-assessment from ~58 ms to ~39 ms. A unit test round-trips the
cache: a second discovery on the same fixture and cache dir agrees exactly
with the first, including tools that are absent from PATH.

### C4: Formal-containers experiment confirms the two SPARK_Mode Off exceptions

The `Adacovex.Complexity` package was probed as a candidate for moving to
SPARK-approved (formal) containers so its `SPARK_Mode (Off)` could be
removed. Scratch units under gnatprove 16.1.0 show this is not viable:

- The GNAT 16.2.1 runtime formal containers
  (`Ada.Containers.Formal_Vectors` and friends) are
  `pragma Compile_Time_Error` stubs; the implementations moved to the SPARK
  library shipped inside the gnatprove toolchain (`SPARK.Containers.Formal.*`).
- Adopting them would make the crate depend at build time on the SPARK
  library, breaking the zero-dependency contract: gnatprove is resolved at
  run time by the `prove` subcommand, but the containers would be a
  compile-time dependency.
- The `Complexity` aggregates embed vector components; the formal
  containers' limited private `Vector` cannot be a record component, so a
  cursor-iteration data-flow rewrite would be required on top of the
  library change.

Verdict recorded in `docs/proof/16.1.0-ledger.md`: `Adacovex.Complexity`
and `Adacovex.Types.Implementation` remain the only two `SPARK_Mode (Off)`
packages, both for the same reason (non-formal `Ada.Containers`
instantiations), and `spark-off-check` allows exactly these two.

### C5: Makefile parsing moved to pure-Python tools

Several `make` targets formatted or parsed text with shell one-liners that
broke under some shells (`awk`'s "backslash not last character on line"
inside the `bench` size report) and used GNU-only filters (`grep -P`,
`sed -i`, `sort -V`) that do not exist on BSD/macOS. The parsing and
formatting moved to pure-stdlib Python scripts so the targets behave the
same on every platform:

- `tools/bench-size.py` -- `make bench`'s binary-size report (stats the
  files itself; no more `stat -c` + awk quoting).
- `tools/ascii-check.py` -- the ASCII gate (no `grep -P`; tab and LF are
  allowed, CR still fails, so CRLF line endings are caught).
- `tools/spark-off-check.py` -- the `SPARK_Mode (Off)` gate.
- `tools/versions.py` -- version read / `set-version` / version-aware
  filter (replaces `sed`/`sort -V` in `release`, `test-publish`,
  `coverage-gate`).
- `tools/bump-version.py` -- the whole `make bump-version` recipe
  (manifest rewrites, release-file/index scaffolding, changelog
  scaffolding, description sync).
- `tools/filter-sframe.py` -- the build-log SFrame-notice filter
  (`make build`).
- `tools/rst2md.py --prune-test-pages` -- drops test-page links from the
  API-docs index (replaces two `sed -i` calls in `make doc`).

The recipes that remain in the Makefile are plain POSIX pipelines
(`head`, `tail`, `grep -E`, `cmp`, `ls`); there is no GNU-only filter or
inline awk left.

### C6: system-tool probes moved to a stable machine-level store

The cold-path profile showed the SBOM system-tool version probes (each a
subprocess; node/hg/mandb boot an interpreter) dominating cold runs. They
were cached under the result cache, so wiping the cache or pointing
`--cache-dir` elsewhere re-probed every tool. They now live in
`~/.adacovex/probes/` (7-day TTL) outside the result cache, and the
referenced-tools cache blob stores each tool's probe result so a cache hit
rebuilds the SBOM tool edges without PATH lookups, probe reads, or spawns.
Cold on a warm-probe machine dropped from ~658 ms to ~86 ms (7.7x); warm
from ~39.8 ms to ~34.6 ms. The blob layout is names-`|`-version-pairs and
`Cache_Schema` was bumped to s6 so names-only blobs from the earlier
layout are never served as complete.

### C7: Dashboard dependency graph: versions, direct links, real packages

The dashboard dependency graph (and the SBOM that shares it) no longer
lists things that are not packages, and every listed package carries a
version and a direct registry link:

- The four vendored dashboard libraries (FlexSearch, nomnoml, graphre,
  Charts.css) are now versioned (`0.7.31` / `1.7.0` / `0.1.3` / `1.2.0`)
  with `pkg:npm` PURLs.  adacovex's own dashboard sources
  (`resources/dashboard.*`) are not a package and never become
  components.
- `node_modules` scanning resolves scoped packages
  (`node_modules/@scope/pkg` becomes `@scope/pkg@<version>` from its
  `package.json`, so the e2e fixture yields `@playwright/test@1.62.1`)
  and skips pnpm's virtual store and shim dirs (`.pnpm`, `.bin`)
  entirely.  `.pnpm` is not a dependency; the `pnpm` binary is, and stays
  the dev tool.  The SBOM and the dashboard now render the same list.
- The dep-details Link row builds direct GitHub / GitLab / Bitbucket /
  npm / crates.io / PyPI / pkg.go.dev / Alire links from the PURL
  (scoped npm names included) and no longer falls back to a GitHub
  search URL for unknown ecosystems.

### C8: Proof categories match gnatprove's summary table

gnatprove 16 reports flow analysis as "Data Dependencies" (checked) plus
"Flow Dependencies" (proved implicitly), and the dashboard's Flow row
read only the Flow Dependencies row -- showing 0/0 on the self-target
while gnatprove showed 56 checked data-dependency VCs.  The parser now
sums both rows into the Flow category and computes every category's
proved count as Total - Justified - Unproved (Termination previously
showed 73/94 instead of 94/94).  The Proof tab table and the Charts
"Proof Check Types" column gained a Termination row, so the per-category
numbers sum exactly to gnatprove's Total (56 + 5 + 407 + 107 + 55 +
94 = 724).  `Cache_Schema` bumped `s6` -> `s7` (parser semantics).

### C9: Dashboard chart, filter, diagram and credits fixes

- Pie/donut data numbers are upright: Charts.css rotates each slice's
  value by its midpoint angle, so a full proved ring (0..1 turn)
  rendered the "724 VCs" number rotated 180 degrees.  Overridden to
  `transform: none`.
- The test-category bar chart is sized to its category count (`--rows`),
  so a 14-category suite no longer clips its last rows; column charts
  with more than eight categories rotate their labels vertically instead
  of overlapping.  The Overview tests donut no longer overflows its card.
- The dep name filter and scope checkboxes actually work: the filter
  used `Map` bracket access (`info[n]`), which threw on every keystroke
  and aborted the run, so typing a name or unchecking a scope changed
  nothing.  Fixed to `info.get(n)`.
- The nomnoml diagram now derives every colour (fill, background,
  stroke, line, font, note) from the active theme's CSS custom
  properties and re-renders when the theme changes, so light and dark
  no longer produce identical (default-yellow) diagrams.
- The Credits tab fills the Playwright version from the resolved graph
  (`@playwright/test@1.62.1`) instead of showing a static "dev".

## Fixes

### H1: Cold-cache runs no longer re-probe the whole toolchain

Before 1.28.0-era cache wipes, a wiped `--cache-dir` re-probed every
referenced tool. After these changes a fresh result cache on a machine
with warm probes skips every spawn. First-run-on-machine cost unchanged.

### H2: `make e2e` runs the dashboard suite again

The Playwright web-server wiring referenced a script that does not
exist (`tools/start-dashboard-server.py`), and the launcher computed the
repository root one level too deep -- both fixed.  The suite now runs
serially (a single-process dashboard server cannot serve a fully
parallel browser swarm), and the stale layout expectations were updated
for the current dashboard (card counts, scope badges, chart count,
credits links), plus new coverage for the dep name filter and the scope
checkboxes fixed in C9.  15 e2e tests pass.

## Test Suite

973 tests passing across 14 categories (5 new: the tools-set cache
round-trip in the SBOM suite; the probe-store change keeps the same
count).  The GNATprove parser tests cover both summary layouts (legacy
3-column and modern 6-column rows).  15 Playwright dashboard layout
tests pass via `make e2e`.

## Proof Results

Platinum, 724/724 VCs proved under gnatprove 16.1.0. 0 unproved, 0
justified. `CPUs.Get_Temp_Directory` carries six `[assumed-global-null]`
warnings (GNAT runtime has no Global contracts for
`Ada.Environment_Variables`); warnings are not VCs, and the gate stays
0 / 0.

## Traceability

No new HLRs. Coverage:

  - `HLR-CACHE` -- C2 stamp fast-path hashing, C3 tools-set cache,
    C6 probe-store change, C8 Cache_Schema s7 bump.
  - `HLR-SBOM` -- C3 tools-set cache keyed on the scanned file set
    storing probe results (C6), C7 dependency-graph package fixes.
  - `HLR-ARCH` -- C1 perf.md documentation, C4 formal-containers
    verdict, C5 Python-tooling port.
  - `RENDER-HTML` -- C8 proof-category consistency, C9 dashboard
    chart/filter/diagram/credits fixes, H2 e2e suite.

See `docs/perf.md`, `docs/proof/16.1.0-ledger.md`.