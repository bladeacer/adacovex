# adacovex 1.8.0

Date: _2026-08-13_

Version bumped 1.7.0 -> 1.8.0.

## Changes

### C1: On-disk result caching

Analysis results are cached on disk under `~/.adacovex/cache/<version>/`,
keyed by the SHA-256 of each input artifact. Unchanged source files serve
their parsed `Package_Info` from the cache instead of being re-scanned;
unchanged `gnatprove.out` and test-result files likewise serve their parsed
summaries. Cache effectiveness (`X hit(s), Y miss(es), Z evicted`) is
reported in the ANSI report. Controlled by `--cache` (default on),
`--no-cache`, `--cache-dir=PATH`, and `--cache-max=N` (default 4096);
`--no-cache` forces every run to re-scan / re-parse / re-prove, which is
useful when artifacts change but keep the same content hash.

### C2: Cache-schema namespace and overflow-safe serialization

The default cache root is `~/.adacovex/cache/<version>/<Cache_Schema>`;
bumping `Cache_Schema` (in `src/core/adacovex-cache.ads`) invalidates blobs
written by incompatible builds instead of serving them as if valid.
`Serialize` returns an empty blob when a payload would exceed `Max_Cache_Blob`
(callers refuse to store it) and `Deserialize` rejects empty/oversized input,
so truncated data can never be served as a cache hit.

### C3: `--target` path normalization

`--target` is normalised to a canonical absolute path (`.`/`..` collapsed)
before scanning, so the `File_Path` values stored in cached `Package_Info` no
longer depend on how the target was spelled (e.g. `--target=../Ada_CRDT` vs
`--target=.`). Docstring patches are matched by the package path relative to
the target root, so a cached path spelled through a different relative form
silently left those patches unapplied; normalization makes the cache
consistent across invocations.

### C4: Alire manifest compatibility

`auto-gpr-with` is expressed in its boolean form (`true`); the string form
`auto-gpr-with = "adacovex.gpr"` is rejected by the released `alr` 2.1.1
(`Cannot read valid property`), which blocked `alr build` and therefore
`make build` / `make test` / `make run-self`.

### C5: HLR completeness

`HLR-CACHE` (Result caching) and `HLR-CPU` (Cross-platform CPU core detection)
are now defined in `docs/compliance/HLR.md`, removing the orphan source tags
and restoring **DAL-C Achieved** in strict mode.

### C6: Ada_CRDT make targets

The `covex`/`prove`/`badges`/`sbom`/`coverage-gate` targets resolve the sibling
`../adacovex` binary when present and fall back to `alr exec -- adacovex`
otherwise, so `make prove` / `make badges` / `make sbom` work both in the
workspace and on CI.

### C7: CI result-cache persistence

The composite action gains a `result-cache` input (default on) that persists
`~/.adacovex/cache` between workflow runs with `actions/cache`;
content-addressed entries make restoring a stale cache always safe, so
incremental branches get mostly cache hits.

### C8: Toolchain-aware proof cache and standalone gnatprove deployment

The GNATprove result-cache key now folds in the resolved prover identity (the
manifest-pinned version for alire-managed deployments, else the resolved
executable/toolchain path), so a proof produced by one gnatprove is never reused
after an upgrade or a different on-PATH / cached / downloaded toolchain -- stale
entries simply miss and are transparently re-proved, with no explicit
invalidation. The `prove` subcommand also stops composing the target's entire
dev-manifest dependency set: instead of `alr exec -- gnatprove` (which could
pull covex / gnatdoc_bin / gnatformat_bin and, for dev-only gnatprove, swap
manifests for the run), it deploys only the self-contained gnatprove binary
crate into `~/.adacovex/toolchain` via `alr -n get gnatprove=<version>` and
runs the deployed binary directly. The manifest version set expression
(`^15.1.0`, `~15.1.0`, ...) is reduced to the bare version alr accepts.
CI proof runs now depend on a single crate download instead of the full
dev-manifest dependency closure, and the dev-manifest swap machinery is gone.

## Fixes

### H1: Cache eviction

The cache root is stored without a trailing separator, and the eviction
helpers (`Count_Files`, `Oldest_File`) guard on `Ada.Directories.Kind` instead
of `Exists`, which returns False for a bare directory on some GNAT versions.
Together these make `--cache-max` eviction actually enforce the entry cap
(previously all entries were retained).

## Test Suite

336/336 native tests passing; counts unchanged (no test files modified in this
release).

## Proof Results

Self-assessment remains **Platinum** (all VCs proved, 0 unproved, AoRTE-free).
`make prove` re-ran gnatprove 15.1.0 against the current tree: **503/503** VCs
proved across 38 analysed units. The cache, CLI, main-flow, and prove-resolution
changes live in non-SPARK units (`Adacovex.Cache`, `Adacovex.CPUs`,
`Adacovex.Config`, `Adacovex.Prove`, `adacovex_main`), so no SPARK proof metrics
regress. Ada_CRDT re-proved clean too: 584/584 VCs (44 justified) across 34
analysed units, Platinum. Proof runs
now deploy gnatprove standalone via `alr -n get gnatprove=15.1.0` into
`~/.adacovex/toolchain` and execute that binary directly; identical inputs hit
the newly toolchain-aware result cache (verified: 30 hit(s), 0 miss(es) on
re-run).

## Traceability

New HLRs: `-- HLR-CACHE` on `Adacovex.Cache` (Result caching) and
`-- HLR-CPU` on `Adacovex.CPUs` (Cross-platform CPU core detection). Existing
tags continue to cover the changed packages: `-- HLR-SCAN` on
`Adacovex.Parsers.Source` (scanning + patch application), `-- HLR-CLI` on
`Adacovex.Config` (path normalization, prove options), `-- HLR-PROVE` on
`Adacovex.Prove`, and `-- HLR-PROOF` on `Adacovex.Parsers.GNATprove`.
