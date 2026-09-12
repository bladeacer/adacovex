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
switches apply to both executables from the same project file, and the
proof is unaffected (gnatprove analyses source, not object code).

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

### C4: Compression review of the offline manual and cache

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
cost more than the I/O it saves. The trade-off is documented on the
dashboard page's offline-manual section.

## Test Suite

The native suite grows from 1235 to 1239 tests across 17 categories, all
passing. CLI-config tests pin the tilde contract: `--target=~/x` expands
to `HOME/x`, `--target=~` resolves to the home directory itself, and a
`~user` form passes through unexpanded.

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
  guide de-duplication, and C4 the compression review documentation.
