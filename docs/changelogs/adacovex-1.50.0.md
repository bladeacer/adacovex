# adacovex 1.50.0

Date: _2026-09-15_

Version bumped 1.49.0 -> 1.50.0.

## Changes

### C1: Deterministic, incremental doc bundling (the `make prove` bottleneck)

`make prove` on an unchanged tree re-proved far too often, and a cache-miss
run paid a full gnatprove session (tens of seconds).  The cause was the
bundled offline manual: `tools/gen-docs.py` collected every page from an
*incremental* Sphinx build directory, so old pages that a doc move had left
behind stayed in the bundle.  A developer tree and a fresh clone therefore
produced **different** `src/adacovex-docs_template.ads` content (217 assets
against 204), and any change to that generated spec invalidates the cached
SPARK proof because the spec is a proof input.

`tools/gen-docs.py` now builds the Sphinx output **clean** whenever the docs
sources change.  A SHA-256 fingerprint of `docs/` plus the built file list is
stamped beside the build, so an unchanged tree reuses the build and a stale
or renamed page can never survive into the bundle.  Both generators
(`gen-docs.py` and `gen-dashboard.py`) now write their Ada spec **only when
the content changed**, so a no-op run keeps the file's mtime and `alr build`
does not recompile the generated 28k-line unit (nor relink) on every run.
The committed spec is regenerated without the 13 dead pages.

Effect on this machine: `make prove` on an unchanged tree falls from seconds
(the recompile and relink) to **~1.0 s**, and the result cache stays warm
(42 hits, 0 misses) instead of flipping to a miss.  `--check` is now
read-only and never rewrites the committed spec.

A stable spec is not enough on its own: a real documentation edit still
changes the bundled manual, and that spec is a proof input.  The two
generated bundle specs (`adacovex-docs_template.ads` and
`adacovex-dashboard_template.ads`) are now excluded from the proof-input
hash.  They are multi-thousand-line string constants (base64 gzip chunks and
inlined HTML/CSS/JS) with no subprogram and no check, so their content
cannot change a proof result.  Editing a docs page and re-running `make
prove` now regenerates the spec and still reports `gnatprove inputs
unchanged`.

### C2: Global configuration documented

The optional global configuration file `~/.adacovex/adacovex.toml` had only
scattered mentions.  The new [Global configuration and
state](../usage/configuration.md) page documents the `[prove]
gnatprove-version` pin (its exact resolution precedence and never-fall-back
rule), every environment variable adacovex reads, the `~/.adacovex/` state
directories (result cache, toolchain, probes, registry metadata, stat-stamp
index), and how to reset each one.  The installation, CLI-options, and docs
index pages link it.

### C3: Bundle size and compression reviewed

The suggestion to compress the offline manual with LZ4 instead of gzip was
re-measured, and the whole bundle was reviewed on the 1.50.0 tree through
the generator's own pipeline.  The bundled site holds 206 assets (about
6.66 MB of source); gzip compresses it to about 1.47 MB (ratio 0.22) and
`lz4 -9` to about 1.93 MB, so LZ4 is about 31% larger.  The Ada runtime also
has no LZ4 decompressor, while the browser inflates the gzip stream with no
runtime code in the binary.  gzip stays.

The base64 Ada source carries about 1.96 MB, about 33% of the 5.68 MiB
stripped binary, and no two assets share their content.  The changelog
history (30.6%) and the generated API reference (29.0%) dominate the
bundle.  Three shrink options were measured and rejected: base85 instead of
base64 (about 2% of the binary, for a new decoder and encoding), a stronger
build-time compressor such as brotli (which breaks the stdlib-only tools
rule), and dropping a page family (Sphinx's search index covers every page,
so a removed page leaves a dead offline search result).  The full numbers
are on [Benchmarking -- bundled offline
manual](../contributing/perf/benchmarks.md#bundled-offline-manual), and the
LZ4 comparison is on the [dashboard page](../usage/dashboard.md).

### C4: A `make compliance` target and a derived test gate

The committed verification report had no owner and drifted for many
releases.  A new `make compliance` target regenerates
`docs/compliance/VERIFICATION.md` and `docs/compliance/TRACE.md` for the
self tree in one command.  The target is deliberately not part of `make
prove`: the reports live under `docs/` and are bundled into the offline
manual, so emitting them inside a prove run would change the bundled
template and invalidate the cached proof on the next run.

`tools/run.py` now derives its `--require-tests` acceptance gate from
`docs/test_result.md`, the single source of truth for the native test count,
instead of pinning a stale literal.  The gate can no longer drift from the
suite.

### C5: New benchmark phase 1.48.0-1.50.0

The per-phase timing table gains a `1.48.0-1.50.0` column with 1.50.0 as the
representative version.  The phase covers the doc-bundling methodology shift
(C1) and folds 1.48.0 and 1.49.0 into it.  The figures are on [Prove timing
and the optimisation review](../contributing/perf/prove-timing.md); the work
behind them is on [Performance optimisation
history](../contributing/perf/optimisation-history.md).

## Fixes

### H1: The bundled offline manual shipped 13 dead pages

`src/adacovex-docs_template.ads` still bundled pages from the pre-1.49.0
layout (`contributing/perf.html`, `contributing/ste100-*.html`, `HLR.html`,
`LLR.html`, and others) because the incremental Sphinx output never removed
them.  A fresh clone (no `docs/_build/`) produced a different spec, so
`python3 tools/gen-docs.py --check` failed there.  The clean build (C1)
drops every stale page; the committed spec now matches a fresh clone.

### H2: The self-assessment test gate pinned a stale count

`tools/run.py` required 1287 passing tests while the suite had reached 1599,
so the acceptance gate tested a bound the suite had long passed.  The gate
now reads the count from `docs/test_result.md` (C4).

### H3: The committed verification report was years out of date

`docs/compliance/VERIFICATION.md` reported 295 tests and 500 VCs.  It now
reports the current tree: 1599 tests, 880 VCs, 179 documented subprograms,
and DO-178C DAL-C Achieved.  `docs/compliance/TRACE.md` is refreshed in the
same pass and now covers every package.

### H4: A stale test-count example in the CLI reference

The CI-gate example on the [serving and CI options
page](../usage/cli-reference-options.md) still used the alias form with the
superseded count of 1287.  It now uses the canonical `--require-tests`
spelling with the current count, which the test-count sync keeps up to date.
The `--require-tests` gate in `tools/run.py` is derived from
`docs/test_result.md` rather than a literal (C4).

### H5: `tools/para-split.py` mangled prose

The paragraph splitter read the `!` of a badge and the `?` of a link query as
sentence ends, and it rewrapped a split paragraph into one long line.  A
`--fix` run therefore rewrote `README.md` as `! [covex ...` and `? url=...`,
and it turned `Adacovex.Target_Profiles` into `Adacovex. Target_Profiles`.  It
also disagreed with the gate: it reported 13 files that `make docs-check`
accepts.

The splitter now applies the sentence rule and the paragraph segmentation of
`tools/check-docs.py`, so the two agree on every file.  It inserts blank lines
only, it keeps the existing line wrapping at every line a break does not fall
between, and it never cuts inside an inline construct (a code span, a link,
or a badge).  A paragraph whose four sentences all lie inside one such
construct is reported rather than cut.

## Test Suite

The native suite grows from 1599 to 1607 checks across 25 categories, all
passing.  The Prove runner category grows from 12 to 20 checks: eight new
checks pin the proof-input rule (`Is_Proof_Input`), covering the two
generated bundle specs, an ordinary spec and body, the hand-written manual
decoder body, the exact-name match, the case-sensitive match, and the empty
name.  The stdlib suite for the dev tools (`tools/tests.py`) grows from 59
to 70 tests: it covers the derived test gate, it adds four doc-bundling
guards (the source fingerprint ignores build output, a stale build page
forces a clean rebuild, the spec is written only on a change, and `--check`
never rewrites the committed spec), and it pins the paragraph splitter
against the `docs-check` gate (H5).

## Proof Results

Platinum, 0 unproved, 0 justified, 880 VCs (880 proved) across 66 analyzed
units under gnatprove 16.1.0.  The release changes no proof surface: the
regenerated documentation template carries data only, and the tooling
changes live outside `src/`.  No proof metric regressed.

## Traceability

- No new HLRs.  The release removes the spurious proof-cache invalidation,
  documents the global configuration, and refreshes the compliance reports.
- `HLR-ARCH` -- C1 the deterministic doc bundling and the clean-build stamp,
  C2 the global-configuration page, C5 the new timing phase, and H5 the
gate-aligned, construct-safe paragraph splitter.
- `HLR-CACHE` -- C1 keeps the proof result cache warm across a no-op build
  and across a real docs edit (the generated bundle specs are excluded from
  the proof-input hash).
- `HLR-PROVE` -- the generated-bundle exclusion lives in the `prove`
  subcommand's input-hash walk.
- `HLR-CLI` -- C4's derived test gate and H4's corrected example.
- `HLR-COMPLIANCE` -- C4's `make compliance` target and H3's regenerated
  verification report and traceability matrix.
