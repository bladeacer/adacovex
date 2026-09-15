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
hash.  They are multi-thousand-line string constants (base85 gzip chunks and
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

### C3: The bundled offline manual is 20.6% smaller

The manual is the largest single payload in the binary, so 1.50.0 shrank it
on two axes and re-measured the whole bundle through the generator's own
pipeline.  Together the two changes take
`src/adacovex-docs_template.ads` from 2,339,756 to 1,857,143 bytes, **20.6%
smaller**, and the stripped binary from about 5.7 MiB to about 5.3 MiB.

The asset bodies moved from base64 to **base85** on the quote-free Z85
alphabet: 4 bytes become 5 characters instead of 5.33, so the encoded
payload fell from 1,648,796 to 1,545,555 characters, about 103 kB or 6.3%.
A small hand-written decoder in `src/adacovex-docs_template.adb` reverses it,
and the browser still inflates the gzip stream, so the binary carries no
inflate routine.

The Furo sidebar no longer repeats.  The global toctree is about 8 kB of
markup and Furo wrote a full copy into all 184 pages.  Each page now keeps a
stub, the tree is stored seven times under `_nav/` (once per branch), and
the deferred `_static/adacovex-nav.js` fills the stub in.  Navigation
therefore needs JavaScript, as the manual's search already did.

The bundled site is now 214 assets over 184 pages (about 5.28 MB of source),
which gzip compresses to about 1.24 MB.  LZ4 was re-measured and rejected:
`lz4 -9` gives about 1.63 MB for the same asset set, about 32% larger than
gzip, and the Ada runtime has no LZ4 decompressor.  A stronger build-time
compressor such as brotli would save more, but it is not in the Python
standard library and its output varies by version, so the committed spec
would stop being byte-reproducible.  The full numbers are on [Benchmarking
-- bundled offline
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

### C6: Dev-tool audit and the paragraph-splitter gate

Every `tools/*.py` script was audited against the tooling conventions: pure
standard library, `typing` annotations, `argparse` for the command line,
and `pathlib` for paths.  The audit found one violation, in
`tools/perf-bench.py`, which had no type annotations and no command
description; both are fixed.  No script imports a third-party package.

The audit also found that the CLI end-to-end harness created its throwaway
git repositories with the developer's own git configuration, so a global
`commit.gpgsign = true` made the setup commit fail and the gate could not run
without a signing agent.  The harness now pins an empty global and system
config, like the tooling suite already did.

The audit also moved the new sidebar injector to `resources/js/book-nav.js`.
The SBOM asset scan reads the `resources/` root as vendored third-party
libraries and `resources/js/` as the project's own modules, so at the root
the file appeared as a bogus `pkg:generic/book-nav` vendored component.

The paragraph splitter now runs as its own gate, `make para-split-check`,
inside `make check`.  `docs-check` already enforces the 4-sentence rule;
running the splitter too keeps the tool a maintainer reaches for on a
failure provably in step with the gate, so a drift fails the gate instead of
rewriting a page wrongly.

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

### H6: The Playwright manual check asserted a page that moved

The `manual subpages are served at /docs/...` browser check requested
`/docs/architecture.html`, but the 1.49.0 documentation restructure moved
that page to `contributing/architecture.html`.  The request returned 404, so
`make e2e` was red on an unchanged tree.  The check now tracks the page's
real path, and a new check loads four pages at different directory depths
and follows the injected sidebar's links.

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

The native suite grows from 1599 to 1614 checks across 25 categories, all
passing.  The Prove runner category grows from 12 to 20 checks: eight new
checks pin the proof-input rule (`Is_Proof_Input`), covering the two
generated bundle specs, an ordinary spec and body, the hand-written manual
decoder body, the exact-name match, the case-sensitive match, and the empty
name.  The Server routing category grows from 41 to 48 checks: they walk
every bundled asset, assert the base85 body decodes to a gzip stream of the
packed length, and assert the shared sidebar variants and the injector are
bundled (C3).

The stdlib suite for the dev tools (`tools/tests.py`) grows from 59 to 79
tests.  It covers the derived test gate, it adds four doc-bundling guards
(the source fingerprint ignores build output, a stale build page forces a
clean rebuild, the spec is written only on a change, and `--check` never
rewrites the committed spec), it pins the paragraph splitter against the
`docs-check` gate (H5), and it pins the base85 packing, the alphabet, three
known vectors, the single-rebase sidebar normalisation, and the stub depth
rule (C3).

## Proof Results

Platinum, 0 unproved, 0 justified, 880 VCs (880 proved) across 66 analyzed
units under gnatprove 16.1.0.  The release changes no proof surface: the
regenerated documentation template carries data only, and the tooling
changes live outside `src/`.  No proof metric regressed.

## Traceability

- No new HLRs.  The release removes the spurious proof-cache invalidation,
  documents the global configuration, and refreshes the compliance reports.
- `HLR-ARCH` -- C1 the deterministic doc bundling and the clean-build stamp,
  C2 the global-configuration page, C3 the base85 encoding and the shared
  sidebar, C5 the new timing phase, C6 the splitter gate, and H5 the
  gate-aligned, construct-safe paragraph splitter.
- `HLR-SERVER` -- C3's shared sidebar and H6's corrected manual check both
  cover the `--serve` manual under `/docs`.
- `HLR-CACHE` -- C1 keeps the proof result cache warm across a no-op build
  and across a real docs edit (the generated bundle specs are excluded from
  the proof-input hash).
- `HLR-PROVE` -- the generated-bundle exclusion lives in the `prove`
  subcommand's input-hash walk.
- `HLR-CLI` -- C4's derived test gate and H4's corrected example.
- `HLR-COMPLIANCE` -- C4's `make compliance` target and H3's regenerated
  verification report and traceability matrix.
