# The dashboard JSON API, playground, and themes

This page covers the JSON API endpoints, the API playground, themes, and the dashboard-related CLI flags. The tabs and charts are on the [Web dashboard home page](dashboard.md); the dashboard internals and dependency views are on [The dashboard document and its dependency views](dashboard-html.md).

## Standard-awareness

The dashboard **defaults to all standards** when no `--standard` / `--asil` /
`--class` flag is given -- the same behaviour as the `sbom` subcommand, which
[Standards](standards.md) documents once for both. The status badges and the
compliance card list every standard's label at the shared tier (DAL-C, ASIL
B, Class A). An explicit standard flag narrows the dashboard to that single
standard (for example `--asil=B` shows only ISO 26262 at ASIL B).

## The JSON API

`/api/metrics` is a plain HTTP GET, so scripts and CI can consume the
assessment without parsing HTML:

The response is pretty-printed (two-space indent, one field per line), so
`curl` output reads the same as the playground preview:

```json
{
  "spark_level": "Platinum",
  "total_vcs": 880,
  "proved_vcs": 880,
  "tests_passed": 1614,
  "tests_failed": 0,
  "test_categories": [
    {
      "name": "ANSI",
      "count": 28,
      "status": "PASS"
    }
  ],
  "doc_coverage": 100,
  "standard": "all",
  "level": "DAL-C",
  "dal_status": "Achieved",
  "standards": {
    "DO-178C": {
      "level": "DAL-C",
      "status": "Achieved"
    },
    "ISO 26262": {
      "level": "ASIL B",
      "status": "Achieved"
    },
    "IEC 62304": {
      "level": "Class A",
      "status": "Achieved"
    }
  }
}
```

The `test_categories` array holds one object per test category; it is a
single entry here for brevity.

| Field | Meaning |
|-------|---------|
| `spark_level` | Assessed SPARK level (`Stone`..`Platinum`) |
| `total_vcs` / `proved_vcs` | GNATprove verification-condition counts |
| `tests_passed` / `tests_failed` | Test-result counts |
| `test_categories` | Per-category test metrics: `name`, `count`, `status` (`PASS` / `FAIL`) |
| `doc_coverage` | Docstring coverage, 0-100 |
| `standard` | `do178c` \| `iso26262` \| `iec62304` \| `all` |
| `level` | Level label for the top-level target (`DAL-C`, `ASIL B`, ...) |
| `dal_status` | `Achieved` or `Unmet` |
| `standards` | Per-standard `level` / `status` object (present when `standard` is `all`) |

A benchmark reference for the endpoints, on the same machine as the
[performance page](../contributing/perf/index.md) figures (hyperfine over curl,
local loopback, 4-worker server): `GET /api/metrics` ~7 ms, `GET /` ~13 ms,
`GET /docs/` ~5 ms per request. The JSON endpoints are two orders of
magnitude under the millisecond-scale of the in-process data they serialise;
the wall time is socket setup (curl spawns, connects, and closes per
request), so keep-alive client libraries see far lower per-request costs.
The dashboard renders the page from the immutable assessment state on each
request, which is microseconds of CPU -- no response cache is needed.

`/api/deps` serves the resolved dependency graph as JSON (the same data the
SBOM embeds, minus the SBOM envelope):

```json
{
  "dependencies": [
    {
      "name": "gnat_arm_elf",
      "version": "13.2.1",
      "scope": "dev",
      "dev": true,
      "system": false,
      "license": "",
      "kind": "dependency",
      "parent": 1,
      "lang": "",
      "purl": "pkg:generic/gnat_arm_elf@13.2.1",
      "website": "",
      "description": "System tool referenced by the project (dev dependency)"
    }
  ]
}
```

| Field | Meaning |
|-------|---------|
| `name` / `version` | Component name and version |
| `scope` | `base` \| `dev` \| `transitive` \| `vendored` \| `system` (a system tool is a `system`-scope dependency with a `pkg:generic/*` PURL) |
| `dev` / `system` | Scope flags for the dev and system scopes |
| `license` | Resolved licence, or empty when none is known |
| `kind` | `root` or `dependency` |
| `parent` | Parent component index in the array (`1` is the root) |
| `purl` | Package URL when derivable |
| `lang` | Primary language when known |
| `website` | Resolved source URL when known |
| `description` | Short description (for example a system-tool note) when present |

On-disk, the same export is available via `--emit-metrics=PATH`
(`{"metrics": {...}, "dependencies": [...]}` after any assessment).

## API playground

The **API** tab turns the dashboard into a small interactive REST client.
Every route the server dispatches on is listed as a clickable button,
grouped by purpose:

- **Metrics** -- `GET /api/metrics` (JSON).
- **Dependencies** -- `GET /api/deps` (JSON).
- **Badges** -- each `GET /badge/*.svg` endpoint (SVG).
- **Documentation** -- `GET /docs`, the bundled offline manual (HTML).
- **API** -- `GET /api/endpoints`, the endpoint catalog the playground is
  built from.

The playground uses a **split-screen layout**: the clickable endpoints,
grouped by purpose, sit in a left-hand nav, and the live response preview
docks on the right -- the same pattern as the Dependencies tab's
tree/diagram + detail panel. On narrow screens the panes stack vertically.
A filter input searches the endpoint nav as you type (matching path,
purpose, and group name), so you can jump straight to `metrics` or `badge`.
Clicking an endpoint issues a live `fetch` against the serving origin and
previews the response:

- JSON endpoints arrive pretty-printed by the server (two-space indent,
  one field per line) and are **syntax-highlighted** with the vendored
  [yace](https://github.com/petersolopov/yace) tokenizer (`window.YaceTok`).
  A JSON-key rule colours object keys separately from string values, so the
  payload reads like an IDE view, and the **Copy** / **Download** actions
  export that same pretty text.
  Endpoint paths that appear inside the JSON payload (for example the
  `/api/...` and `/badge/...` values in `/api/endpoints`) become clickable
  links to the live endpoints, and every endpoint button's path is itself a
  link that opens the raw URL in a new tab.
- SVG badge endpoints show the live image above the raw markup.
- The `/docs` endpoint shows the bundled offline manual (the same page the
  footer **Manual** link opens).

A toolbar on the result offers **Copy** (clipboard) and **Download** (saves
the raw response body to a file) for the JSON API response, so the
playground doubles as a lightweight HTTP client without leaving the browser.
The first endpoint (`/api/metrics`) runs automatically so the tab always
opens with a live preview. The endpoint list is **not hardcoded** in client
JavaScript: the playground fetches it from `GET /api/endpoints`, the single
source of truth the server declares. Each request is made live against the
instance, so what you preview is exactly what `curl` returns.

## Themes

The dashboard supports **light**, **dark**, and **system** themes. Colours are
driven by CSS custom properties, and a header dropdown switches live between
them. **Save settings** persists the current selection in `localStorage`
(no cookies, key `adacovex-theme`).

Theme resolution on page load:

1. a `?theme=light|dark|system` query parameter on the dashboard URL.
   It always wins. This is the supported way to pin the theme when embedding
   the dashboard in an iframe (the server routes the query form correctly,
   see [query strings and fragments](dashboard.md#how-to-use-the-dashboard)).
2. otherwise the explicit CLI theme (`--theme=light` / `--theme=dark`).
3. otherwise the saved `localStorage` choice, if one was saved.
4. otherwise the system theme (`prefers-color-scheme`).

`--theme` only sets the *initial* selection. The dropdown and Save settings
still override it afterwards in the browser.

## Related CLI flags

The dashboard-related flags are documented once in the CLI reference:

- [`--serve`](cli-reference-options.md#--serve) -- start the server (a
  switch; default off).
- [`--port=N`](cli-reference-options.md#--portn) -- server port (default
  `8080`).
- [`--serve-workers=N`](cli-reference-options.md#--serve-workersn) -- HTTP
  server task-pool worker count (alias `--workers=N`; default scales to the
  CPU count within `2`..`8`, capped at 256).
- [`--theme=NAME`](cli-reference-options.md#--themename) -- initial
  dashboard theme: `light` \| `dark` \| `system` (case-insensitive, default
  `system`).

Full detail, the JSON schema, and the theme-resolution order are in
[Web dashboard and JSON API](dashboard.md).
