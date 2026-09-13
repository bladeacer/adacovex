# adacovex 1.47.0

Date: _2026-09-12_

Version bumped 1.46.0 -> 1.47.0.

## Changes

### C1: `--target` expands a leading `~`

`--target=~/projects/demo` and `--target=~` now expand the tilde to the
user's home directory before the cwd-join resolves the path to an
absolute one. The shell does not expand a tilde inside `--target=...` or
a quoted argument, so the previous behaviour produced `$CWD/~/projects/demo`
and failed with "unknown directory". A `~user` form is left unchanged --
only the shell can resolve another user's home -- and it keeps the old
cwd-join treatment. `HOME` unset falls back to `/tmp`, the same
convention as the cache directory, so a home-less environment still gets
a usable path. The expansion lives in a pure helper in the CLI parser
(`Adacovex.Config`), so every flag that reuses the target path
(`--manifest` detection, the default `--emit-svg` directory, the SBOM
output path) inherits the resolved value.

### C2: `-O2` + cross-module inlining release build

The project file now compiles every unit with `-O2 -gnatn` instead of the
GNAT default `-O0`. This is the release-grade optimisation the perf docs
already described as the speed path, but the built project file never
carried it -- local and CI binaries ran unoptimised (the 1.46.0 perf
review measured a ~41 ms warm self-assessment on such a build). The
switches apply to both executables from the same project file, andthe proof is unaffected (gnatprove analyses source, not object code).
Benchmarked (hyperfine, same-session A/B on the Ada_CRDT dogfood target):
the pipeline cold path drops from ~39 ms to ~33 ms and the stripped binary
shrinks from 6.49 MiB to 5.39 MiB; the warm path is unchanged within noise
and the solver-dominated prove-cold shape does not move.

### C3: Dashboard guide de-duplicated across its three pages

The three dashboard pages repeated whole blocks of each other. The
"Related CLI flags" table in the API page duplicated the flag rows in the
CLI reference nearly verbatim; the query-string routing note appeared in
both the dashboard home page and the API page; the "defaults to all
standards" paragraph appeared in three places. Each fact now lives once:
the flags table became a cross-linked list into the CLI reference (the
single source the action-parity gate keeps in sync), the routing note
stays in the dashboard home page's server paragraph, and standard
awareness is documented once on the Standards page. Spelling was also
swept to British "rigour" on the affected pages.

### C4: Docs gate clean: line-cap opt-out marker + README trim

`make docs-check` had four standing line-cap overruns (README, the 1.38.0
changelog, the STE100 technical-names dictionary, and the 16.1.0 proof
ledger) plus one paragraph-rule failure carried in this release. The
paragraph failure is fixed in place, the README is trimmed to the budget
by folding its four documentation tables into one and tightening the
patch and standards sections, and the three reference/history pages gain
a `no-covex-docs-loc` opt-out marker -- the same convention the
complexity gate uses -- understood by `tools/check-docs.py` as an HTML
comment near the top of the file. The marker suspends only the 250-line
cap; the paragraph rule stays a hard error everywhere, and the marker is
covered by new unit tests in `tools/tests.py`.

### C5: Buffered request reader on the serve path

The HTTP request reader pulled one byte per `Receive_Socket` call, so a
typical request's request line and headers cost ~300 receive syscalls on
a worker before the handler ran. The reader now fills a 4 KiB
per-connection buffer per receive and hands out complete CRLF-terminated
lines from it, cutting the request-read cost to a couple of receives per
request. The buffer lives in one worker task for the life of one
keep-alive connection, so it needs no locking; receive timeouts and
vanished peers surface as an empty line, exactly like the EOF cases the
old reader handled.

End to end (hyperfine over curl on the same server): `/api/metrics` ~7
ms, `/` ~13 ms, `/docs/` ~5 ms per request, with the wall time dominated
by curl's own process cycle. Under sustained concurrent keep-alive load
(a new pure-stdlib load generator, `tools/load_test.py`, 20-second runs),
the JSON and badge endpoints saturate the 4-worker pool at ~94k requests
per second with sub-millisecond tail latency and hold it with 16 clients,
while the dashboard page and the manual index hold flat latency under the
same load. The perf page records the endpoint figures, the syscall split,
and the capacity analysis.

### C6: Compression review of the offline manual and cache

The compression options for the bundled offline manual and the result
cache were re-examined and the current design kept. The manual already
ships pre-compressed: `tools/gen-docs.py` gzip-compresses every asset at
build time, base64-encodes it into the generated spec, and the server
sends it with `Content-Encoding: gzip` -- so the browser inflates it and
the binary carries no inflate routine. LZ4 (or a runtime zstd) would
decompress faster, but only the browser decompresses here, so binary CPU
cost is zero either way, and LZ4's lower ratio would grow the embedded
blob and the shipped binary. The result cache stays uncompressed: its
blobs are tiny per-unit records where a compress/decompress cycle would
cost more than the I/O it saves; the trade-off is documented on the
dashboard page's offline-manual section.

## Test Suite

The native suite grows from 1235 to 1287 tests across 17 categories, all
passing. CLI-config tests pin the tilde contract: `--target=~/x` expands
to `HOME/x`, `--target=~` resolves to the home directory itself, and a
`~user` form passes through unexpanded. The stdlib suite for the dev
tools (`tools/tests.py`) grows to 59 tests with four for the
`no-covex-docs-loc` marker: the cap warns without the marker, is silent
with it, ignores a marker beyond the scan window, and keeps the paragraph
rule a hard error under the marker.

## Proof Results

Platinum, 0 unproved, 0 justified, 876 VCs (876 proved) under gnatprove
16.1.0 across 58 analysed units. The tilde expansion is proved code
(`SPARK_Mode` On, the environment-variable reads scoped with the same
warnings pragma as `Adacovex.CPUs`), so the new surface is covered by
the existing proof with no justified VCs.

## Traceability

- No new HLRs. The release fixes a path-resolution defect, enables the
  documented release optimisation, and de-duplicates the user
  documentation; the existing tags below cover it.
- `HLR-CLI` -- C1 the `--target` tilde expansion in the CLI parser
  (Parse_All path resolution) and its unit tests.
- `HLR-ARCH` -- C2 the `-O2 -gnatn` project switches, C3 the dashboard
  guide de-duplication, C4 the docs-gate opt-out marker and README trim,
  C5 the buffered request reader on the serve path, and C6 the
  compression review documentation.
