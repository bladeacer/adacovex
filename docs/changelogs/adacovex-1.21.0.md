# adacovex 1.21.0

Date: _2026-08-23_

Version bumped 1.20.0 -> 1.21.0.

## Changes

### C1: Fix raw CSS rendered as text in `--serve` dashboard

The dashboard page shell (`resources/dashboard.html`) had a duplicated
`</style>` tag: the custom dashboard CSS was closed, the vendored
`charts.min.css` was then inlined *outside* any `<style>` block, and a
second `</style>` closed the head.  Browsers rendered the entire vendored
CSS as literal text at the top of the page.  The template is now a single
`<style>` block (custom CSS + vendored Charts.css + a single `</style>`)
regenerated via `tools/gen-dashboard.py`, so the page is self-contained and
valid HTML again.  No visual change beyond the bug being gone.

### C2: Dependency tree text spacing and scope filtering

The tree's typography is tightened: `line-height` 1.5 -> 1.65, node margins
4px -> 6px, leaf padding 6x8 -> 8x12, gaps 8px -> 10px, and a hover
`border-color: var(--accent)` transition.  Every `<li class="dep-node">` now
carries `data-scope` (`base` / `dev` / `transitive` / `vendored`) and
`data-name`, and the toolbar gains four scope checkboxes (base, dev,
transitive, vendored -- all checked by default) plus `Expand all` /
`Collapse all`.  A new `filterByScope()` JS function composes the name filter
and the scope filters so `dev` and `vendored` deps can be hidden without
losing the hierarchy.  The same `data-scope` attribute drives the scope pie
in C3.

### C3: Charts -- pie, bar, and scope-aware extras where suitable

`Renderers.HTML.Render_Charts` now has a graph-aware overload
`(Doc, Proof, Tests, Graph)` (the old 3-arg form remains as a wrapper) and
emits two new pies in the **Charts** tab:

   - **Tests Pass/Fail** pie -- passed vs failed slice (previously only the
     per-category bar existed, so a single failing test was easy to miss);
   - **Dependencies by Scope** pie -- counts of base / dev / transitive /
     vendored components from the resolved graph (skipped when the graph is
     empty).

Existing charts are kept (SPARK donut now proved vs unproved, proof
categories column, test categories bar normalised to the max, doc coverage
bar) and now correctly use `0..1` `--size` fractions.  The chart grid stays
`repeat(auto-fit, minmax(280px, 1fr))` inside the tab panel.  See
`docs/dashboard.md#metrics-charts`.

### C4: Dependency hierarchy alternative view with vendored nomnoml

The **Dependencies** tab gains a second view: **Tree** (default) vs
**Diagram (nomnoml)**.  The diagram is rendered with vendored
[nomnoml 1.7.0](https://github.com/skanaar/nomnoml) (MIT, `resources/nomnoml.js`,
71 KB) in a `<canvas id="nomnoml-canvas">` inside a `nomnoml-wrap` card.
`ADACOVEX_GRAPH` (injected as `__GRAPH_JSON__` by the Ada renderer) is
converted to nomnoml source (`[parent]-->[child]` edges, `#direction: right`,
plus a legend note) and drawn via `nomnoml.draw(canvas, src)`.  The view
switch is persisted in `localStorage` (`adacovex-dep-view`) and hash-routed,
with **Re-render** and **Download PNG** buttons.  Scope checkboxes filter
both views (tree hides nodes, diagram re-renders from the filtered set).
Credits and license updated in `docs/THIRD_PARTY_NOTICES.md`.

### C5: Vendor FlexSearch for dashboard search indexing

The dashboard header gains a global search box (packages, HLRs, deps) powered
by vendored [FlexSearch 0.7.31](https://github.com/nextapps-de/flexsearch)
(Apache-2.0, `resources/flexsearch.js`, 16 KB).  At page load a
`FlexSearch.Index({tokenize:'forward'})` is hydrated from
`ADACOVEX_GRAPH.dependencies` and from the rendered `data-name` attributes;
queries are served from the index with a DOM fallback, and hits are shown in
a `search-hits` dropdown that jumps to the Dependencies tab and seeds the
`dep-filter`.  Both vendored bundles are inlined into the single-file
dashboard template (`resources/dashboard.html` contains two `<script>`
blocks for nomnoml and flexsearch before the theme/tab script), so the
dashboard stays offline-capable.  See `docs/THIRD_PARTY_NOTICES.md`.

### C6: Man pages are now single source of truth from source

`Adacovex.Renderers.Man` no longer hard-codes the `.SH OPTIONS` list.
`Render_Page` now derives the option list at runtime from
`Adacovex.Config.Flag_List` (the same `Known_Flags` that drives `--help`
and shell completion), iterating the space-separated flag table and emitting
a `.TP` entry per flag via a central `Desc_For` map.  Adding a flag to
`Known_Flags` automatically adds a man entry (with a fallback generic line)
even before a bespoke description is added, so the man page, `--help`, and
completion can never drift.  A future `tools/gen-man.py` generator (parity
with `gen-dashboard.py` / `gen-version.py`) is documented as the next step,
but the runtime derivation already makes `Flag_List` the single source.
The `man --check` / `man --dir` / `man --force` flow and the installed page
header (`adacovex vX.Y.Z`) are unchanged.

## Fixes

### H1: Dashboard served valid HTML again

Covered by C1: the duplicated `</style>` that caused the vendored CSS to be
rendered as text is removed.  `make ascii-check` and `tools/gen-dashboard.py
--check` both pass; the served page at `http://127.0.0.1:8080/` now shows
styled cards, not raw CSS.

## Test Suite

886 tests passing (unchanged) across 14 categories.  No new test categories
added in this release; the existing HTML rendering, man page, and server
routing expectations continue to pin the dashboard shell and the `/api/deps`
route.  A follow-up will add renderer tests for the new chart pies and the
`data-scope` attribute.

## Proof Results

Platinum, 720/720 VCs proved across 49 analyzed units (unchanged from
1.20.0): the chart pies, dep-tree scope attributes, nomnoml/flexsearch
inlining (tooling-bundled JS), and the dynamic man page all live in
default-off bodies or are Python/JS tooling -- no new SPARK obligations.  0
unproved, 0 justified.  Re-verified with `adacovex prove --target=.
--force` under gnatprove 16.1.0 (`--steps=10000`).

## Traceability

No new HLRs.  Coverage:

   - `HLR-DASH` -- C1 raw-CSS fix, C2 tree spacing, C3 scope/test pies, C4
     nomnoml diagram, C5 FlexSearch indexing (renderer, dashboard docs,
     third-party notices);
   - `HLR-CLI` / `HLR-DOC` -- C6 man page single source (man renderer,
     config flag list);
   - `HLR-SBOM` -- dependency graph already covers scope filtering (no new
     SBOM surface).

See `docs/dashboard.md`, `docs/cli-reference.md`, `docs/THIRD_PARTY_NOTICES.md`.
