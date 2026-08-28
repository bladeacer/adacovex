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

## How to use the dashboard

Open `http://localhost:8080` in a browser. The page is a single self-contained
document (no external assets) with hash-routed tabs. Use the header dropdown to
switch themes (light / dark / system) and **Save settings** to persist your
choice.

### Overview tab

Start here. The **Robustness tier** (S / A / B / C / D) is a single letter that
summarises five quality axes: Docs, Proof, Tests, Compliance, and Deps. An **S**
means the project is healthy across the board. A **D** means one or more axes
are below 50%. Below that:

- **SPARK radar** -- proved verification conditions per check category (flow,
  initialization, runtime, assertions, functional). A balanced polygon means
  every category has strong coverage. A spike in one corner and a flat line in
  another means the proof effort is uneven.
- **Tests donut** -- passed vs failed tests. A full green arc means 100%
  passing. Any red slice means the test suite has failures that must be fixed
  before the project can be assessed as `Achieved`.
- **Doc coverage radial gauge** -- documented subprograms as a percentage of
  total. Strict mode requires 100%. A shortfall here shows exactly how many
  subprograms are missing `--` docstrings.

### Proof tab

Shows the SPARK level (Stone .. Platinum) and per-category VC counts. The
mini **VCs proved / total** at the top is the headline number. Click into a
category to see the breakdown. If a category is low, that is where the proof
effort must focus.

### Tests tab

Every test category with its count and Pass / Fail. A single failing category
is enough to fail the compliance gate (`Tests passing` must be `Yes` for every
tier except QM / DAL-E).

### Compliance tab

Shows the target integrity level, overall `Achieved` / `Unmet`, HLRs traced,
orphan-tag state, and every unmet criterion. Use this to verify that every HLR
is tagged in source and that no tags are orphaned (tagged but not defined in
`HLR.md`).

### Dependencies tab

An interactive dependency tree (or diagram) of every component in the graph.
Use the filter input and scope checkboxes to focus on base, dev, transitive,
vendored, or system dependencies. Click a node to see its licence, PURL,
parent, and a registry link. Use this tab to audit your supply chain: confirm
every vendored licence is compatible, see which system tools the build needs
(the `system` scope), and trace each component back to its source. The diagram
view (toggle **Tree / Diagram**) renders the same graph as a directed diagram.

### Charts tab

Six CSS-only cards (donut, column, bar, radial gauge, pie, polar ring) that
show the same data as the Overview tab in a different format. Use this to
compare SPARK proof, test results, doc coverage, and dependency scope at a
glance.

## Interpreting the charts

- **Green / full arcs** -- the metric is at 100% or close to it.
- **Red slices or flat corners** -- there is a regression or missing data.
- **Scope rings** -- a large vendored wedge means strict-mode docstrings are
  being suppressed by patches. If you see no wedge, vendored code can be
  uncovered.
- **Tier letter drops** -- a drop from `A` to `C` means the average across all
  five axes fell. Check the axis table to see which one regressed.

The same data is available headlessly at `/api/metrics` and via
`--emit-metrics=PATH` (`{"metrics":..., "dependencies":...}`).

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

The page is a single self-contained document (no external assets), bundled
into the binary from **modular resources** -- `resources/dashboard.html` is
just the page skeleton. Author styles and scripts are split into focused
modules under `resources/css/` (`dashboard.css`, which also styles the
hand-rolled donut rings and bar charts) and `resources/js/` (`theme.js`,
`tabs.js`, `deps.js`, `details.js`, `nomnoml.js`, `search.js`).  The
vendored `graphre.js` / `nomnoml.js` / `flexsearch.js` sit at `resources/`
and are inlined into the template at build time by
`tools/gen-dashboard.py`, which also **minifies** the author CSS/JS
(comments and whitespace stripped, vendored files are already minified and
inlined byte-for-byte).  Edit the individual `resources/` files, never the
generated `src/adacovex-dashboard_template.ads`. `make build` regenerates it
and `gen-dashboard.py --check` (wired into `make check`) fails when it
drifts.  Content is organised into **clickable tabs** (hash-routed,
keyboard-accessible, persisted in `localStorage`):

- **Overview** -- status badges (live `/badge/*.svg` preview), source overview
  (packages scanned, subprograms, docstring %), and quick stats (SPARK level,
  VCs proved, tests, compliance, dependency count), plus the at-a-glance
  collation charts below the stats: a **Robustness radar with a tier rating**
  (S/A/B/C/D from the average of five quality axes), the per-check-type
  **SPARK radar**, a tests **donut** and a doc-coverage **radial gauge**. The
  badge row doubles as a preview for the generated `docs/badges/*.svg` files.
  See [Robustness tier](#robustness-tier) for how the rating is derived.
- **Proof** -- the SPARK level (Stone..Platinum) and, per check category
  (flow, initialization, runtime, assertions, functional), total and proved
  counts plus a mini **VCs proved/total** column at the top of the tab.
- **Tests** -- every test category with count and Pass/Fail plus a mini
  **pass/fail donut** at the top of the tab.
- **Compliance** -- a mini **achievement radial gauge** at the top, then the
  target integrity level and overall `Achieved` / `Unmet`
  status, HLRs traced, orphan-tag state, whether tests pass, each unmet
  criterion, and the HLR traceability table (package -> tags).
- **Dependencies** -- a scope-distribution **stacked bar** at the top, then
  an interactive dependency tree/graph (see below).
- **Charts** -- hand-rolled metrics charts (see below).
- **Credits** -- third-party libraries used by the dashboard (nomnoml,
  graphre, FlexSearch) with versions, licences, links and the
  THIRD_PARTY_NOTICES pointer.  The Playwright row (e2e test tooling) fills
  its version from the resolved dependency graph when the target declares a
  playwright package (e.g. `@playwright/test@1.62.1`).

Tabs are linkable: `http://localhost:8080/#deps` opens the Dependencies tab
directly (also `?theme=light#proof` composes with the theme pin). The active
tab is saved as `adacovex-tab` in `localStorage`.

The page **footer** carries the copyright line (`(c) 2026 bladeacer`,
Apache-2.0), the **repository link** (`github.com/bladeacer/adacovex`), the
binary **version** (`v__VERSION__`, injected from `Adacovex.Version`) and
short links to the third-party credits and the `/api/*` endpoints.

### Dependencies tab and alternative diagram

The **Dependencies** tab visualises the resolved `alire.toml` / `alire.lock`
graph that also powers the SBOM (`/api/deps` JSON, `sbom.json`). The server
resolves the graph at `--serve` start (best-effort, an unresolvable graph
shows an empty state with a link to `/api/deps`).

**Tree view** (default):

- Collapsible tree via `<details>` (root open, children closed) with improved
  text spacing (`line-height: 1.65`, `padding: 8px 12px`, `gap: 10px`,
   `margin: 6px 0`). **Expand all / Collapse all** buttons.
- **Filter** input (client-side, case-insensitive by name) hides non-matching
  nodes. Six **scope checkboxes** (`base`, `dev`, `transitive`, `vendored`,
  `system`, `test` -- all checked by default) hide whole scopes, so vendored,
  dev, system, and test deps can be distinguished and filtered where required.
- Scope badges: `base` (alire.toml), `dev` (alire-dev.toml only),
  `transitive`, `vendored`, `system` (a tool on `PATH` the project
  references, for example `git` or `python3`), and `test` (declared under a
  `[[test-depends-on]]` section or with-claused only from test project
  files). `root` badge for the project itself. Child count badge.
  `data-scope` attribute on each `<li>` for JS filtering.  Scope badge
  colours come from `--scope-base/-dev/-trans/-vend/-system/-test` CSS
  variables so they stay readable in both themes.
- Each node shows `name`, `version`, `license`, `purl` when available. The
  licence and PURL text are colour-coded (`--lic` amber, `--purl` muted
  monospace) so vendored/uncommon licences stand out at a glance.
- **Click a dependency name** to open a **detail panel** in a split view: the
  tree or diagram stays on the left and the panel docks on the right (it stacks
  below on narrow screens). The panel is the single source of detail for every
  dependency and serves both the Tree and the Diagram views. It shows the name,
  version, scope, licence, language, PURL, parent, and a **registry link**
  derived from the PURL (`pkg:github` -> GitHub, `pkg:gitlab` -> GitLab,
  `pkg:bitbucket` -> Bitbucket, `pkg:npm` -> npmjs, `pkg:cargo` -> crates.io,
  `pkg:pypi` -> PyPI, `pkg:golang` -> pkg.go.dev, `pkg:alire` -> alire.ada.dev).
  Ecosystems without a reliable registry get no link rather than a search URL.
  A **system** scope badge marks system-tool dependencies (`pkg:generic/*`
  with `scope: "system"`); their panel adds a note that no external link or
  licence is provisioned and only the resolved version is shown. Vendored
  npm/pnpm/cargo packages resolve their licence from the local manifest, or
  from the package registry (`npm view <pkg> license`, `pnpm show <pkg>
  license`, `cargo search <pkg>`) when the manifest is silent. Close the panel via
  the `close` chip or by clicking another dependency; closing returns the view
  to full width.

**Diagram view** (alternative, toggle **Tree / Diagram**):

-  Rendered with vendored [nomnoml 1.7.0](https://github.com/skanaa/nomnoml)
  (MIT, `resources/nomnoml.js`, 71 KB, inlined) inside a `nomnoml-wrap`
  card.  `ADACOVEX_GRAPH` (`__GRAPH_JSON__` injected by the Ada renderer) is
  converted to nomnoml source (`[parent]-->[child]` edges,
  `#direction: down` top-to-bottom so deep graphs stay within the page
  width) and laid out with nomnoml's internal layout engine, then the graph
  is serialised to an **SVG** (`<svg id="nomnoml-svg">`).  Every node is a
  real `<g data-name=...>` group with a matching `<rect>` hitbox, so boxes
  are clickable with exact hit areas (no canvas hit-testing, nothing
  upside down, no text overflow: node text is clipped to the box width and
  long labels ellipsise).  Diagram colours (fill, background, stroke, line,
  font) are derived from the page's CSS custom properties at render time,
  and the theme select re-renders the diagram, so box/arrow colours always
  match the active theme. The SVG scales to the container width and deep
  graphs scroll inside `.nomnoml-wrap`.
   Scope checkboxes filter the diagram too (re-render on change).  Buttons
   **Re-render** and **Download SVG** are provided. The view choice is
   persisted in `localStorage` (`adacovex-dep-view`).  **Click a box** to open
   the same split-view detail panel as the Tree view.

**Two separate searches, similar styling**:

- **Global search** (header, `#global-search`) is the site-wide index: it is
  powered by vendored [FlexSearch 0.7.31](https://github.com/nextapps-de/flexsearch)
  (Apache-2.0, `resources/flexsearch.js`, 16 KB, inlined).  At page load a
  `FlexSearch.Index({tokenize:'forward'})` is hydrated from
  `ADACOVEX_GRAPH.dependencies` and from rendered `data-name` attributes,
  lowercased so page content (dependency names, scope badges, even orphan
  tags in the compliance table) is searchable regardless of case.  Queries
  are served from the index with a DOM fallback, and hits are shown in a
  `search-hits` dropdown that jumps to the tree and seeds `dep-filter`.
- **Tree filter** (`#dep-filter`, inside the Dependencies tab) is a plain
  client-side name filter over the rendered tree only -- it never touches the
  global index.  The two inputs share the same styling class so they look
  consistent, but they are functionally independent (typing in one does not
  affect the other until a global hit is clicked).

The same data is available headlessly at `/api/deps` and via
`--emit-metrics=PATH` (`{"metrics":..., "dependencies":...}`).

### Metrics charts

The **Charts** tab renders six cards. The charts are hand-rolled (no
vendored chart library): donut rings are a conic gradient with a CSS hole
(the same pattern as the polar ring) and bars are flex rows with a fixed
label column, so labels never rotate or overflow and the ring colour
reflects the covered share (fully green at 100%):

- **SPARK Proof** -- *donut* of proved vs unproved VCs (`720/720` shows a
  full green ring. `680/720` shows `94%` green + `6%` red unproved).
- **Proof Check Types** -- *bars* of proved checks per category (flow,
  init, runtime, assertions, functional, termination), each bar normalised
  to its category total, green proved share with a red unproved remainder.
  The numbers mirror gnatprove's own summary table: on gnatprove 16 the
  Flow category sums the "Data Dependencies" and "Flow Dependencies" rows,
  and every category's proved count is Total - Justified - Unproved, so the
  rows sum exactly to the Total.
- **Test Results by Category** -- *bars* of per-category test counts
  (normalised to the largest category; long category names ellipsise in
  the fixed label column instead of overflowing).
- **Docstring Coverage** -- *radial gauge* (half-circle SVG arc) of
  documented vs total subprograms.
- **Tests Pass/Fail** -- *donut* of passed vs failed tests (fully green
  when every test passes).
- **Dependencies by Scope** -- *polar ring* of base / dev / transitive /
  vendored / system / test components (conic-gradient + CSS hole,
  `--scope-*` theme variables) with a legend. Skipped when the graph is
  empty.

Each of the six cards is a different type (donut / bars / bars / radial /
donut / polar) so the tab reads at a glance without duplicating a data
story.  The per-check-category SPARK radar lives on the **Overview** tab
instead (see below).  No JavaScript is required for the charts (pure
CSS/SVG). The radial gauge and the scope ring follow the light/dark theme
automatically via CSS variables.  The surrounding grid (`chart-grid`) is
responsive and the page container is `max-width:1180px` so large monitors
do not stretch cards.  Rings are used where a part-to-whole distribution
is the point. Bars are used where a max-normalised comparison across
categories is the point.

### Robustness tier

The Overview tab leads with a **Robustness** radar spider and a tier rating
(S / A / B / C / D) so the health of the whole project can be read at a
glance.  Five quality axes, each a `0..100` percentage:

| Axis | Meaning |
|------|---------|
| **Docs**   | Docstring coverage: documented subprograms / total |
| **Proof**  | SPARK VCs proved / total |
| **Tests**  | Test pass rate: passed / (passed + failed) |
| **Comp**   | Compliance gate: `100` when the target standard is Achieved, `0` when Unmet |
| **Deps**   | Dependency hygiene: (graph components - vendored) / total |

The average of the five axes maps to the tier letter:

| Tier | Average | Colour |
|------|---------|--------|
| S | >= 90 | green |
| A | >= 80 | blue |
| B | >= 65 | purple |
| C | >= 50 | orange |
| D | < 50  | red |

The radar polygon, the per-axis legend with percentages, and the tier chip
are rendered as inline SVG/CSS with integer math (no floating point in the
renderer) and use `var(--accent)` plus per-tier CSS variables, so they follow
the light/dark theme.  Next to it, a small **SPARK radar** shows the proved
count per check type, also as an inline-SVG spider, and the **Tests** donut
and **Doc Coverage** radial gauge give the same pass/fail and coverage
numbers as the full-size charts.

## Standard-awareness

Like the `sbom` subcommand, the dashboard **defaults to all standards** when
no `--standard` / `--asil` / `--class` flag is given. The status badges and
the compliance card list every standard's label at the shared tier (DAL-C,
ASIL B, Class A). An explicit standard flag narrows the dashboard to that
single standard (for example `--asil=B` shows only ISO 26262 at ASIL B). See
[Standards](standards.md) for the cross-standard tier mapping.

## The JSON API

`/api/metrics` is a plain HTTP GET, so scripts and CI can consume the
assessment without parsing HTML:

```json
{"spark_level":"Platinum","total_vcs":723,"proved_vcs":723,
 "tests_passed":998,"tests_failed":0,"doc_coverage":100,
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
[{"name":"gnat_arm_elf","version":"13.2.1","scope":"dev",
  "parent":"adacovex","kind":"dependency","purl":"pkg:generic/gnat_arm_elf@13.2.1",
  "lang":"","website":"","description":"System tool referenced by the project (dev dependency)"},
 ...]
```

| Field | Meaning |
|-------|---------|
| `name` / `version` | Component name and version |
| `scope` | `base` \| `dev` \| `transitive` \| `vendored` \| `system` (a system tool is a `system`-scope dependency with a `pkg:generic/*` PURL) |
| `parent` | Parent component name (`(root)` for the root, or the index as `0`) |
| `kind` | `root` or `dependency` |
| `purl` | Package URL when derivable |
| `lang` | Primary language when known |
| `website` | Resolved source URL when known |
| `description` | Short description (for example a system-tool note) when present |

On-disk, the same export is available via `--emit-metrics=PATH`
(`{"metrics": {...}, "dependencies": [...]}` after any assessment).

## Themes

The dashboard supports **light**, **dark**, and **system** themes. Colours are
driven by CSS custom properties, and a header dropdown switches live between
them. **Save settings** persists the current selection in `localStorage`
(no cookies, key `adacovex-theme`).

Theme resolution on page load:

1. a `?theme=light|dark|system` query parameter on the dashboard URL.
   It always wins. This is the supported way to pin the theme when embedding
   the dashboard in an iframe.
2. otherwise the explicit CLI theme (`--theme=light` / `--theme=dark`).
3. otherwise the saved `localStorage` choice, if one was saved.
4. otherwise the system theme (`prefers-color-scheme`).

`--theme` only sets the *initial* selection. The dropdown and Save settings
still override it afterwards in the browser.

## Related CLI flags

| Flag | Default | Description |
|------|---------|-------------|
| `--serve` | off | Start the HTTP dashboard server after the assessment |
| `--port=N` | `8080` | Server port (a valid `Positive` integer) |
| `--theme=NAME` | `system` | Initial dashboard theme: `light` \| `dark` \| `system` (case-insensitive) |
