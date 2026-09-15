# Web dashboard and JSON API

`adacovex --target=. --serve --port=8080` runs the full assessment and then
starts a built-in HTTP/1.1 server (no external web stack) serving a
**viewable HTML dashboard**, a machine-readable JSON API, and the SVG
badges. The server blocks until interrupted -- run it in its own terminal
(or as a background process when scripting).

```bash
adacovex --target=. --serve --port=8080
# in another terminal:
curl http://localhost:8080/api/metrics
```

The dashboard guide is split across four pages. This page covers using
the served dashboard, its endpoint table, and the bundled offline manual.
The dashboard document itself (tabs, dependency views, split-view detail
panel, search) is on
[The dashboard document and its dependency views](dashboard-html.md); the
JSON API, the API playground, and the themes are on
[The dashboard JSON API, playground, and themes](dashboard-api.md); the
chart cards and the robustness tier are on
[Dashboard metric charts](dashboard-charts.md).

## How to use the dashboard

Open `http://localhost:8080` in a browser. The page is a single self-contained
document (no external assets) with hash-routed tabs; the theme dropdown and
**Save settings** persist your choice.

### Overview tab

![Preview of Overview tab](../media/dashboard_preview_overview.png)

Start here. The **Robustness tier** (S / A / B / C / D) is a single letter
summarising five quality axes: Docs, Proof, Tests, Compliance, and Deps.
**S** means healthy across the board; **D** means an axis is below 50%.
Below that:

- **SPARK radar** -- proved verification conditions per check category (flow,
  initialization, runtime, assertions, functional). A balanced polygon means
  every category has strong coverage; a spike in one corner and a flat line
  in another means the proof effort is uneven.
- **Tests donut** -- passed vs failed tests. A full green arc means 100%
  passing. Any red slice means the test suite has failures that must be fixed
  before the project can be assessed as `Achieved`.
- **Doc coverage donut** -- documented subprograms as a percentage of
  total. Strict mode requires 100%. A shortfall here shows exactly how many
  subprograms are missing `--` docstrings.
- **Dependency scope ring** -- the resolved graph broken down by scope
  (base / dev / transitive / vendored / system / test), hoverable per
  segment (hover shows the scope name and its component count, for
  example `test: 3`).

Proof check bars scale with the category's magnitude, the same way as the
test-category bars: a 407-VC category reads as a longer bar than a 56-VC
one, so relative proof effort is visible at a glance.

### Proof tab

![Preview of Proof tab](../media/dashboard_preview_proof.png)

Shows the SPARK level (Stone .. Platinum) and per-category VC counts. The
mini **VCs proved / total** at the top is the headline number; a low category
is where the proof effort must focus.

### Tests tab

![Preview of Tests tab](../media/dashboard_preview_tests.png)

Every test category with its count and Pass / Fail. A single failing category
is enough to fail the compliance gate (`Tests passing` must be `Yes` for
every tier except QM / DAL-E).

### Compliance tab

![Preview of Compliance tab](../media/dashboard_preview_compliance.png)

Shows the target integrity level, overall `Achieved` / `Unmet`, HLRs traced,
orphan-tag state, and every unmet criterion. Use this to verify that every HLR
is tagged in source and that no tags are orphaned (tagged but not defined in
`compliance/HLR.md`).

### Dependencies tab

![Preview of Dependencies tab](../media/dashboard_preview_dependencies.png)

An interactive dependency tree (or diagram) of every component in the graph.
Use the filter input and scope checkboxes to focus on a scope; click a node
to see its licence, PURL, parent, and a registry link. Use this tab to audit
your supply chain: confirm every vendored licence is compatible, see which
system tools the build needs (the `system` scope), and trace each component
back to its source.

The diagram view (toggle **Tree / Diagram**) renders the same graph as a directed diagram.

### Charts tab

![Preview of Charts tab](../media/dashboard_preview_charts.png)

Eight CSS-only cards show the same data as the Overview tab in a different
format. See [Dashboard metric charts](dashboard-charts.md#metrics-charts) for
the full card-by-card breakdown.

### API tab

![Preview of API tab](../media/dashboard_preview_api.png)

An interactive REST API playground: every endpoint the server dispatches on
as a searchable, clickable button, with a pretty-printed, syntax-highlighted
JSON preview. The first endpoint (`/api/metrics`) runs automatically. See
[The API playground](dashboard-api.md#api-playground) for the full detail.

## Interpreting the charts

- **Green / full arcs** -- the metric is at 100% or close to it.
- **Red slices or flat corners** -- there is a regression or missing data.
- **Scope rings** -- a large vendored wedge means strict-mode docstrings are
  being suppressed by patches.
- **Tier letter drops** -- the average across the five axes fell; check the
  axis table to see which one regressed.

The same data is headlessly available at `/api/metrics` and via
`--emit-metrics=PATH` (`{"metrics":..., "dependencies":...}`).

| Path | Content |
|------|---------|
| `GET /` | HTML dashboard (tabbed) |
| `GET /api/metrics` | JSON object with the key assessment metrics |
| `GET /api/deps` | JSON dependency graph (same data as the Dependencies tab) |
| `GET /api/endpoints` | JSON endpoint catalog (the list the API playground builds its UI from) |
| `GET /docs` | The bundled offline manual (the Sphinx manual, built into the binary) |
| `GET /badge/spark.svg` | SPARK assurance level badge |
| `GET /badge/tests.svg` | Test pass/fail badge |
| `GET /badge/do178c.svg` | DO-178C compliance badge (Achieved / Unmet) |
| `GET /badge/iso26262.svg` | ISO 26262 compliance badge |
| `GET /badge/iec62304.svg` | IEC 62304 compliance badge |
| anything else | `404 Not Found` |

The server runs a small HTTP/1.1 implementation with a task pool that
scales to the host's logical CPU count within `2`..`8` workers (configurable
with [`--serve-workers=N`](cli-reference-options.md#--serve-workersn) or its
`--workers=N` alias) and serves
requests until the process is interrupted (Ctrl-C).  Query strings and URL
fragments are stripped before routing, so `/?theme=light`,
`/api/metrics?x=1` and `/api/deps#top` reach the same handlers as `/`,
`/api/metrics` and `/api/deps` instead of 404ing.

## Bundled offline manual

The `--serve` server also serves the **bundled offline manual** at `/docs`
(both spellings, with and without the trailing slash, reach the same page).
The manual is the same Markdown source that powers the Read the Docs site
(`docs/`, a Sphinx project with `docs/conf.py` + MyST); at build
time `tools/gen-docs.py` runs `sphinx-build` and bundles the resulting site
into the binary (`src/adacovex-docs_template.ads`) as a lookup table plus
static string constants: every page, stylesheet, script, and badge, keyed
by site-relative path (each constant stays small -- a single multi-megabyte
blob would overflow the gnatprove frontend stack, so the search index is
split into chunks and the server streams them).

Sphinx's own search machinery (searchindex.js, searchtools.js, the
stemmers) is bundled and the search box works exactly as on the online
site. The PNG screenshots are dropped (they show as notes), the
`_sources/` page-source links are stripped, and the bundled HTML stays pure
ASCII (non-ASCII glyphs are encoded as UTF-8 byte values in the Ada
source). The header **Documentation (offline manual)** link and the API
playground's `/docs` endpoint both open it.

The manual is served **pre-compressed**: every asset is gzip-compressed at
build time (in `tools/gen-docs.py`, base64-encoded into the generated spec)
and goes out with `Content-Encoding: gzip`, so the browser inflates it and
the binary carries no inflate routine.

LZ4 was measured again and rejected. On the self tree the bundled site is
about 6.66 MB of source; gzip compresses it to about 1.47 MB (ratio 0.22)
and `lz4 -9` to about 1.93 MB (ratio 0.29). LZ4 is therefore **31% larger**
than gzip here, which would add about 0.6 MB to the embedded base64 blob.

Two further points settle it: the Ada runtime has no LZ4 decompressor (a
roll-your-own decoder would add code and SPARK proof surface), and gzip
needs no decoder at all in the binary because the browser inflates the
stream. gzip stays.

The result cache also stays uncompressed -- its blobs are tiny per-unit
records where compression costs more than it saves.

The full composition of the bundled site, and the other size options
measured, are on [Benchmarking adacovex -- bundled offline
manual](../contributing/perf/benchmarks.md#bundled-offline-manual).

## Charts

The eight chart cards and the robustness tier are documented on
[Dashboard metric charts](dashboard-charts.md).
