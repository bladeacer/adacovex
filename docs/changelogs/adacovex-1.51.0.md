# adacovex 1.51.0

Date: _2026-09-16_

Version bumped 1.50.0 -> 1.51.0.

<!-- no-covex-docs-loc: historical release record, line cap does not apply -->

## Changes

### C1: One space after a sentence, and a gate that keeps it

The hand-written docs and the changelogs mixed two writing styles. A count
of the tree found 251 sentence endings followed by two spaces against 623
followed by one: 33 changelogs used only single spacing and 7 used only the
double form, and README.md and CONTRIBUTING.md were single-spaced
throughout. No gate, style page, or tool ever mentioned the gap, so the
drift was neither a rule nor enforced.

The tree now uses one space after a sentence. `tools/check-docs.py` gains
the rule and a `--fix` normaliser that collapses the gap. The rule covers the
same files the page gate covers, plus AGENTS.md and CONTRIBUTING.md, whose
long-form paragraphs stay outside the four-sentence cap, plus the comment
text of every `src/**/*.ads` and `src/**/*.adb` file. Fenced code blocks are
skipped, and the `--  ` Ada comment prefix a code span documents is never
flagged because `--` is not sentence punctuation.

The Ada half is comment-only by construction: a line is read from its `--`
marker on, and the scan tracks string state, so a `--` inside a literal is
not a comment. Code alignment is therefore never flagged and never rewritten;
the fixer copies everything before the marker byte for byte. The generated
units (`adacovex-docs_template`, `adacovex-dashboard_template`,
`adacovex_version_info`) are excluded, as the generated api-docs pages are:
their generators emit single-spaced comments already, and a hand edit there
is overwritten by the next `make build`.

The rule also widens from "two spaces followed by a capital, quote, bracket,
or backtick" to "two spaces followed by any text". The narrower form missed
real gaps before a lowercase word, a flag (`--serve`), a numeral, or bold
markup, so 24 more spots in the docs and the changelogs and 41 more in Ada
comments came into scope.

Two passes normalised the tree: the docs pass rewrote 56 files, and the Ada
pass rewrote 122 more, 98 of them for spacing alone. The Ada comment text
lost 1,187 gaps, and the heaviest single file was
`src/parsers/adacovex-parsers-manifest.adb` with 138. Four lines of a
docstring example that demonstrated the annotation format lost their trailing
comment padding as well; the format's own two-space tag alignment is
untouched. `tools/para-split.py` remains the paragraph fixer, so each fixer
stays in step with its own gate.

### C2: The JSON API pretty-prints its responses

`GET /api/metrics`, `GET /api/deps`, and `GET /api/endpoints` now emit
JSON in the `json.dumps(indent=2)` shape: one field per line, two spaces
per level, and a space after every colon. The three Ada renderers build the
payload with fixed indentation constants, so the layout is a static-part
proof with no loop or overflow obligation.

The change reaches every consumer at once. `curl /api/metrics` is readable
without a formatter, the API playground preview shows exactly what the
server sends, and its **Copy** and **Download** actions export that text
rather than a compact body. `--emit-metrics=PATH` carries the same pretty
payloads.

The user docs were wrong about the served shape even before this change.
The [dashboard API page](../usage/dashboard-api.md) sample for `/api/metrics`
carried a stray `" "` line, the `/api/deps` sample showed a bare array while
the endpoint serves `{"dependencies": [...]}`, and the field tables omitted
`test_categories`, `dev`, `system`, `license`, and the numeric `parent`. The
page now shows the real pretty output and documents every field.

### C3: The offline manual caches and parallelises the encode

`tools/gen-docs.py` re-encoded every asset body (gzip + base85) on every
run. Each body's encoded chunks are now cached by SHA-256 under
`obj/adacovex-docs-encode/`, so a run after a docs edit re-encodes only the
pages it touched, and the uncached bodies are encoded in parallel across
the CPU cores (`concurrent.futures`; `--jobs` caps the worker count at 8).
The cache is pruned to the hashes in the current bundle, so it never grows
without bound, and identical bodies share one entry.

Both changes are pure speed-ups: the emitted spec is byte-identical to the
serial encode. On the dev machine (12 CPUs) a no-op `gen-docs.py --check`
falls from 0.65 s (a full serial encode, the old shape) to 0.30 s, and a
cold parallel encode takes 0.52 s. C7 then takes the Sphinx build off the
common path as well.

### C4: The badges page previews its badges, online and offline

`docs/badges/index.md` gains a **Previews** section that renders all six
badges inline, so a reader can check a badge before downloading the file.
An inline image lives under Sphinx's `_images/` directory, which the
offline bundle dropped. `tools/gen-docs.py` now bundles the SVG images
there (SVG is text, so it compresses like any other asset, and the badge
preview works offline exactly as online), while the PNG screenshots keep
the short-note fallback.

### C5: An Archive section for the dated records

Two pages are pinned to an earlier state and read as current guidance
beside the live pages. They move to a new `docs/archive/` section: the
gnatprove 16.1.0 proof-debt audit and the earlier-releases optimisation
history. Each carries an archived-record banner that names the date and
points at the live page, and `docs/index.md` gains an **Archive** sidebar
category.

`tools/live_files.py` excludes `docs/archive/` from the metric-sync walk,
so an archived page keeps the release-time numbers it records and the
proof/test sync can never rewrite them. Every inbound link, the proof
index, the AGENTS.md documentation block, and the two research-heavy
changelog links were updated in the same pass.

### C6: The manual tells the reader where the dashboard is

The manual and the dashboard share one server. The
[Bundled offline manual](../usage/dashboard-docs.md#what-gets-bundled)
section now says so: when the reader is inside a running `--serve` server,
opening `/` shows the live metrics for the target, and the online manual,
which carries no live data, tells the reader to run adacovex on their
project first and then open the dashboard.

### C7: A docs edit rebuilds the manual incrementally

`make build` was fast only when nothing had changed: a docs edit paid a full
clean Sphinx build every time. Profiling the phases of `make build` on the
dev machine (12 CPUs) gave: version 0.04 s, CSS gate 0.05 s, dashboard
template 0.15 s, the manual bundle 7.7 s, `alr build` 1.5 s. The manual bundle
was 74% of the work, and 6.8 s of it was Sphinx.

Sphinx now runs incrementally and the result is verified. The stamp records a
SHA-256 digest per source file beside the build, so an unchanged tree skips
Sphinx completely, and a changed one re-reads only the pages that changed.
Three guards keep the incremental output a pure function of `docs/`:

- the changed sources' mtimes are refreshed first, because Sphinx decides what
to re-read by mtime, and a source restored with its old timestamp would be
served from a stale doctree;
- the outputs of a removed page (its HTML, its `_sources/` copy, its doctree,
and the `_images/` and `_downloads/` copies of a removed image) are swept,
because Sphinx leaves the output of a page whose source is gone;
- a navigation change -- a page added or removed, or a `{toctree}` edit --
rewrites every page with `sphinx-build -a`, because Sphinx rewrites only the
pages it re-read and every other sidebar would keep the old toctree.

After the build the page set is checked against the sources, and a leftover,
a missing page, or an unjustified image falls back to a clean rebuild.
`tools/gen-docs.py --fresh` forces a clean rebuild outright.

| `make build` shape | before | after |
|--------------------|--------|-------|
| no change | 0.9 s | 0.9 s |
| one docs page edited | 9.2 s | 2.7 s |
| docs page added or removed | 9.2 s | 7.0 s |

The emitted spec is byte-identical to a clean build of the same sources. Every
shape above was checked with a `--fresh` build against the incremental one.

## Fixes

### H1: Bare URLs in THIRD_PARTY_NOTICES were not clickable

The Read the Docs row, the CycloneDX and SPDX specification rows, the
second column of the performance-tool and language-server tables, and the
licence-text list held plain URLs that rendered as text. Every one is now a
link, so the notices page has no unclickable reference left.

### H2: The proof-status sync would have stopped updating the JSON sample

`tools/update-proof-status.py` rewrites the `"total_vcs"` and `"proved_vcs"`
values in the docs sample with a compact pattern that required no space
after the colon. The pretty payload writes that space, so the patterns
would have silently stopped matching and the sample would have gone stale.
The patterns now accept the space and keep it.

## Test Suite

The native suite stays at 1614 checks across 25 categories, all passing.
The JSON assertions in the HTML/renderer category were updated for the
pretty payload (a colon-space now separates each key from its value).

The stdlib suite for the dev tools grows from 87 to 115 tests. Twenty-eight
are new, in five groups:

- five cover the docs gate's sentence-spacing rule (a double space is
  flagged, a single space passes, a markdown hard break and the Ada `--  `
  prefix are clean, the fixer collapses the gap and agrees with the gate, and
  the pure normaliser leaves indentation, a hard break, and a fenced code
  block untouched);
- one covers the bundled badge SVGs;
- five cover the encode cache and the parallel encoder (the cached chunks
  round-trip, an unchanged body is never re-encoded, a changed body
  re-encodes and prunes the old entry, the parallel encode matches the serial
  one, and the worker count stays bounded);
- eight cover the incremental build decisions (an unchanged tree skips
  Sphinx, an edited page rebuilds without `-a`, an added page and a toctree
  edit do use it, a removed page is swept, a stray page falls back to a
  clean build, `--fresh` forces one, and the stamp round-trips);
- nine cover the pure helpers behind them (changed and removed sources, page
  output names, the sweep list and the `_downloads/` copies, the leftover
  check, and toctree detection, which must not fire on prose that mentions
  `{toctree}`).

## Proof Results

Platinum, 0 unproved, 0 justified, 880 VCs (880 proved) across 66 analyzed
units under gnatprove 16.1.0. The pretty-print rewrite of the three JSON
renderers is fully proved and adds no verification condition; no proof
metric moved. The Ada comment-text change is comment-only, so it adds none
either. The regenerated documentation template carries data only.

## Traceability

- No new HLRs. The release enforces the sentence-spacing style, pretty-prints
  the JSON API, speeds up the docs bundle, and archives the dated records.
- `HLR-SERVER` -- C2's pretty `/api/metrics`, `/api/deps`, and `/api/endpoints`
  responses and the playground that previews them.
- `HLR-CLI` -- C1's spacing gate and fixer, and H2's corrected proof-status
  pattern for the documented JSON sample.
- `HLR-CACHE` -- C3's content-hash encode cache and parallel encoder, and
  C7's per-source digests, incremental Sphinx build, and verified fallback.
- `HLR-ARCH` -- C5's Archive section, the archived-record banners, and the
  `docs/archive/` exclusion from the metric-sync walk.
- `HLR-COMPLIANCE` -- C1's normalised hand-written docs, changelogs, and Ada
  comment text, and H1's clickable third-party references.
