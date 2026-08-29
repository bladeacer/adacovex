# adacovex 1.34.0

Date: _2026-08-29_

Version bumped 1.33.0 -> 1.34.0.

## Changes

### C1: Overview paired cards now fill 50-50

The **Doc Coverage** and **Dependency Scope** cards on the Overview tab sit in
a `.chart-pair` grid, but that pair was itself a single item inside the
overview `.chart-grid` (auto-fit, min 280px per cell), so the two cards were
squeezed into one narrow column instead of each taking half the content width.
The pair now spans every grid track (`grid-column: 1 / -1`), so the two cards
fill 50-50 of the Overview content container exactly like **Source Overview**
and **Quick Stats** do, and still stack on narrow screens.

### C2: Search finds page sections, not just tabs

The header search indexed each tab as one blob of words, so a query only ever
jumped to a whole tab and multi-word page text such as "orphan tags" or a
section heading rarely matched.  The index is now built from the rendered DOM
at the granularity of a section:

- every `.card` / `.chart-card` (labelled by its heading);
- every compliance-table row, so "orphan tags" lands on the exact row;
- every dependency node and every HLR-tagged element;
- plus one catch-all entry per tab.

Queries are tokenised and every token must match (AND semantics), so multi-word
page content and section headings resolve.  Selecting a hit switches to the tab
**and** scrolls to the matched section, briefly flashing it to show where the
match is, instead of only switching tabs.  Dependency names, versions, scopes,
licences and PURLs stay indexed, so the box still filters the dependency tree.

### C3: System-tool probe cache self-invalidates

The referenced-tools cache key now folds in every curated tool's
version-probe flag and the probe fallback chain.  Editing how a tool's version
is read (for example the `go` subcommand or the `--version, -v, version`
fallbacks) busts the cache automatically.  The 1.33-era control relied on a
manually bumped `|tools-v3|` salt; forgetting the bump silently served stale
probe results within a release.  No hand-maintained salt is needed now.

### C4: gnatdoc and gnatformat documented as Alire dev dependencies

`gnatdoc_bin` and `gnatformat_bin` were already dev dependencies declared in
`alire-dev.toml` (run via `alr exec` for the `make doc` and `make fmt`
targets), but the README's *Requirements* list only mentioned `gnatpp` /
`gnatdoc` as optional tools.  The list now states that **gnatdoc_bin** and
**gnatformat_bin** are managed by Alire as dev dependencies, so the published
crate still installs and builds with no toolchain beyond the GNAT compiler.

## Fixes

### H1: Proof Check Types bars now scale with value

1.33 rolled out proof-category bars with a per-row track-width style, but the
CSS `.hbar-track { flex: 1 }` overrode that inline width, so every proof bar
stretched to the full row and showed only the proved *rate* (100% green),
never the magnitude -- unlike the test-category bars, which scale because their
fill is measured against the largest category.  The proof fills are now also
measured against the largest category: the green fill is Proved/Max and the red
remainder is (Checks-Proved)/Max inside a full-width track, with the grey track
showing the scale gap -- so a 407-VC category reads as a longer bar than a
56-VC one, precisely like the test chart.

### H2: Links render in the accent colour

Links outside the Credits and footer areas -- the dependency-detail source
link, the `/api/deps` / `/api/metrics` references, and the nomnoml note -- fell
back to the browser's default blue/purple, while the Credits and footer links
used `--accent`.  A global `a { color: var(--accent) }` rule now styles every
link uniformly (the Credits/footer rules become redundant but harmless), so the
detail panel, dependency views and search results match the rest of the
dashboard in both themes.

## Test Suite

Native suite grows to 1066 tests (14 categories).  The HTML/Markdown renderer
suite gains two assertions: the proof-check-type bar scales against the largest
category (Flow's green fill is a quarter of the full-width track when Flow is 2
of 8 runtime checks, and the largest category fills it), and the partial-proof
red remainder is sized by the maximum category.  The existing donut,
chart-pair and hoverable scope-ring checks still pass unchanged.

## Proof Results

Platinum, 723/723 VCs proved across 50 analysed units (unchanged at 1.34.0 --
the renderer and manifest-parser bodies are not in SPARK_Mode On, so the bar
scaling and cache-key changes add no new VCs).  Invocation: `adacovex prove`
(`--steps=10000`, gnatprove 16.1.0).  0 unproved, 0 justified.

## Traceability

No new HLRs.  Coverage:

- `RENDER-HTML` / `HLR-DASH` -- C1 paired-card width, C2 section search,
  H1 proof-bar scaling, H2 uniform link colour.
- `MANIFEST` / `HLR-SBOM` -- C3 self-invalidating system-tool probe cache.
- `HLR-ARCH` -- C4 doc changes (gnatdoc_bin / gnatformat_bin declared as Alire
  dev dependencies in `alire-dev.toml` and run via `alr exec` for `make doc` /
  `make fmt`).

See `docs/dashboard.md`.