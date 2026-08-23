# Web dashboard and JSON API

`adacovex --target=. --serve --port=8080` runs the full assessment and then
starts a built-in HTTP/1.1 server (no external web stack) that serves a
**viewable HTML dashboard** plus a machine-readable JSON API and the SVG
badges. The server blocks until interrupted -- run it in its own terminal, or
as a background process when scripting.

```bash
adacovex --target=. --serve --port=8080
# in another terminal:
curl http://localhost:8080/api/metrics
```

## Endpoints

| Path | Content |
|------|---------|
| `GET /` | HTML dashboard (tabbed) |
| `GET /api/metrics` | JSON object with the key assessment metrics |
| `GET /api/deps` | JSON dependency graph (same data as the Dependencies tab) |
| `GET /badge/spark.svg` | SPARK assurance level badge |
| `GET /badge/tests.svg` | Test pass/fail badge |
| `GET /badge/do178c.svg` | DO-178C compliance badge (Achieved / Unmet) |
| `GET /badge/iso26262.svg` | ISO 26262 compliance badge |
| `GET /badge/iec62304.svg` | IEC 62304 compliance badge |
| anything else | `404 Not Found` |

The server runs a small HTTP/1.1 implementation with a 4-worker task pool and
serves requests until the process is interrupted (Ctrl-C).

## The HTML dashboard

![Dashboard Preview Image](../media/dashboard_preview.png)

The page is a single self-contained document (CSS and the theme/tab script are
inlined; no external assets), rendered from the bundled
`resources/dashboard.html` template. Content is organised into **clickable
tabs** (hash-routed, keyboard-accessible, persisted in `localStorage`):

- **Overview** -- status badges (live `/badge/*.svg` preview), source overview
  (packages scanned, subprograms, docstring %), and quick stats (SPARK level,
  VCs proved, tests, compliance, dependency count). The badge row doubles as a
  preview for the generated `docs/badges/*.svg` files.
- **Proof** -- the SPARK level (Stone..Platinum) and, per check category
  (flow, initialization, runtime, assertions, functional), total and proved
  counts plus total VCs / proved VCs.
- **Tests** -- every test category with count and Pass/Fail plus the total
  (Passed / Failed).
- **Compliance** -- target integrity level and overall `Achieved` / `Unmet`
  status, HLRs traced, orphan-tag state, whether tests pass, each unmet
  criterion, and the HLR traceability table (package -> tags).
- **Dependencies** -- interactive dependency tree/graph (see below).
- **Charts** -- Charts.css metrics (see below).

Tabs are linkable: `http://localhost:8080/#deps` opens the Dependencies tab
directly (also `?theme=light#proof` composes with the theme pin). The active
tab is saved as `adacovex-tab` in `localStorage`.

### Dependencies tab and alternative diagram

The **Dependencies** tab visualises the resolved `alire.toml` / `alire.lock`
graph that also powers the SBOM (`/api/deps` JSON, `sbom.json`). The server
resolves the graph at `--serve` start (best-effort; an unresolvable graph
shows an empty state with a link to `/api/deps`).

**Tree view** (default):

- Collapsible tree via `<details>` (root open, children closed) with improved
  text spacing (`line-height: 1.65`, `padding: 8px 12px`, `gap: 10px`,
  `margin: 6px 0`); **Expand all / Collapse all** buttons.
- **Filter** input (client-side, case-insensitive by name) hides non-matching
  nodes; four **scope checkboxes** (`base`, `dev`, `transitive`, `vendored`
  -- all checked by default) hide whole scopes, so vendored and dev deps can
  be distinguished and filtered where required.
- Scope badges: `base` (alire.toml), `dev` (alire-dev.toml only),
  `transitive`, `vendored`; `root` badge for the project itself; child count
  badge; `data-scope` attribute on each `<li>` for JS filtering.
- Each node shows `name`, `version`, `license`, `purl` when available.

**Diagram view** (alternative, toggle **Tree / Diagram**):

-  Rendered with vendored [nomnoml 1.7.0](https://github.com/skanaa/nomnoml)
  (MIT, `resources/nomnoml.js`, 71 KB, inlined) in a
  `<canvas id="nomnoml-canvas">` inside a `nomnoml-wrap` card.  `ADACOVEX_GRAPH`
  (`__GRAPH_JSON__` injected by the Ada renderer) is converted to nomnoml
  source (`[parent]-->[child]` edges, `#direction: down` top-to-bottom so deep
  graphs stay within the page width, legend note) and drawn via
  `nomnoml.draw(canvas, src)`.  The diagram reads the page's CSS custom
  properties (`--card` / `--border` / `--fg`) at draw time and re-renders
  when the light/dark theme changes, so box/arrow colours always match the
  active theme; the canvas is sized to the container (max-width) and deep
  graphs scroll inside `.nomnoml-wrap`.  Scope checkboxes filter the diagram
  too (re-render on change).  Buttons **Re-render** and **Download PNG** are
  provided; the view choice is persisted in `localStorage`
  (`adacovex-dep-view`).

**Global search** (header):

- A search box in the header is powered by vendored
  [FlexSearch 0.7.31](https://github.com/nextapps-de/flexsearch)
  (Apache-2.0, `resources/flexsearch.js`, 16 KB, inlined).  At page load a
  `FlexSearch.Index({tokenize:'forward'})` is hydrated from
  `ADACOVEX_GRAPH.dependencies` and from rendered `data-name` attributes;
  queries are served from the index with a DOM fallback, and hits are shown
  in a `search-hits` dropdown that jumps to the Dependencies tab and seeds
  the `dep-filter`.  Both bundles are inlined into the single-file dashboard
  template so the dashboard stays offline-capable.

The same data is available headlessly at `/api/deps` and via
`--emit-metrics=PATH` (`{"metrics":..., "dependencies":...}`).

### Metrics charts

The **Charts** tab renders six cards using the vendored
[Charts.css](https://chartscss.org/) framework (v1.2.0, MIT, inlined into the
page shell so the page stays self-contained). All values are unitless `0..1`
`--size` / `--start` / `--end` fractions (previously `0..100` made every pie
slice a full loop) and the donut shows proved vs *unproved* slices
(previously proved vs total duplicated the proved arc):

- **SPARK Proof** -- *donut* of proved vs unproved VCs (`720/720` shows a
  full proved arc; `680/720` shows `94%` proved + `40` unproved).
- **Proof Check Types** -- *column* of proved checks per category (flow,
  init, runtime, assertions, functional), each bar normalised to its category
  total.
- **Test Results by Category** -- *bar* of per-category test counts
  (normalised to the largest category).
- **Proof Radar** -- inline SVG radar (spider) of the five check categories.
  Charts.css 1.2.0 ships no radar drawing rules, so grid rings, axes, the
  data polygon and labels are drawn directly with integer math and
  `var(--accent)` fill/stroke, following the active theme.
- **Tests Pass/Fail** -- *pie* of passed vs failed tests.
- **Dependencies by Scope** -- *polar ring* of base / dev / transitive /
  vendored components (conic-gradient + CSS hole, `--scope-*` theme
  variables) with a legend; skipped when the graph is empty.

No JavaScript is required for the Charts.css cards (pure CSS); the radar and
scope ring are inline SVG/CSS and follow the light/dark theme automatically.
The surrounding grid (`chart-grid`) is responsive and the page container is
`max-width:1180px` so large monitors do not stretch cards.  Pies/rings are
used where a part-to-whole distribution is the point; bars/columns where a
max-normalised comparison across categories is the point.

## Standard-awareness

Like the `sbom` subcommand, the dashboard **defaults to all standards** when
no `--standard` / `--asil` / `--class` flag is given: the status badges and
the compliance card list every standard's label at the shared tier (DAL-C,
ASIL B, Class A). An explicit standard flag narrows the dashboard to that
single standard (e.g. `--asil=B` shows only ISO 26262 at ASIL B). See
[Standards](standards.md) for the cross-standard tier mapping.

## The JSON API

`/api/metrics` is a plain HTTP GET, so scripts and CI can consume the
assessment without parsing HTML:

```json
{"spark_level":"Platinum","total_vcs":720,"proved_vcs":720,
 "tests_passed":900,"tests_failed":0,"doc_coverage":100,
 "standard":"all","level":"DAL-C","dal_status":"Achieved",
 "standards":{"DO-178C":{"level":"DAL-C","status":"Achieved"},
               "ISO 26262":{"level":"ASIL B","status":"Achieved"},
               "IEC 62304":{"level":"Class A","status":"Achieved"}}}
```

| Field | Meaning |
|-------|---------|
| `spark_level` | Assessed SPARK level (`Stone`..`Platinum`) |
| `total_vcs` / `proved_vcs` | GNATprove verification-condition counts |
| `tests_passed` / `tests_failed` | Test-result counts |
| `doc_coverage` | Docstring coverage, 0-100 |
| `standard` | `do178c` \| `iso26262` \| `iec62304` \| `all` |
| `level` | Level label for the top-level target (`DAL-C`, `ASIL B`, ...) |
| `dal_status` | `Achieved` or `Unmet` |
| `standards` | Per-standard `level` / `status` object (present when `standard` is `all`) |

`/api/deps` serves the resolved dependency graph as JSON (the same data the
SBOM embeds, minus the SBOM envelope):

```json
[{"name":"gnat_arm_elf","version":"13.2.1","scope":"build",
  "parent":"adacovex","kind":"(direct)","purl":"pkg:generic/gnat_arm_elf@13.2.1"},
 ...]
```

| Field | Meaning |
|-------|---------|
| `name` / `version` | Component name and version |
| `scope` | `build` \| `dev` \| `runtime` \| `tool` \| `system` |
| `parent` | Depending component (empty for the root) |
| `kind` | Component kind (crate, toolchain tool, system tool, ...) |
| `purl` | Package URL when derivable |

On-disk, the same export is available via `--emit-metrics=PATH`
(`{"metrics": {...}, "dependencies": [...]}` after any assessment).

## Themes

The dashboard supports **light**, **dark**, and **system** themes. Colors are
driven by CSS custom properties, and a header dropdown switches live between
them; **Save settings** persists the current selection in `localStorage`
(no cookies, key `adacovex-theme`).

Theme resolution on page load:

1. a `?theme=light|dark|system` query parameter on the dashboard URL --
   always wins (this is the supported way to pin the theme when embedding
   the dashboard in an iframe);
2. otherwise the explicit CLI theme (`--theme=light` / `--theme=dark`);
3. otherwise the saved `localStorage` choice, if one was saved;
4. otherwise the system theme (`prefers-color-scheme`).

`--theme` only sets the *initial* selection; the dropdown and Save settings
still override it afterwards in the browser.

## Related CLI flags

| Flag | Default | Description |
|------|---------|-------------|
| `--serve` | off | Start the HTTP dashboard server after the assessment |
| `--port=N` | `8080` | Server port (a valid `Positive` integer) |
| `--theme=NAME` | `system` | Initial dashboard theme: `light` \| `dark` \| `system` (case-insensitive) |
