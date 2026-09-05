# The dashboard JSON API, playground, and themes

This page covers the JSON API endpoints, the API playground, themes, and the dashboard-related CLI flags.  The tabs and charts are on the [Web dashboard home page](dashboard.md); the dashboard internals and dependency views are on [The dashboard document and its dependency views](dashboard-html.md).

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
{"spark_level":"Platinum","total_vcs":876,"proved_vcs":876,
 " "tests_passed":1235,"tests_failed":0,"doc_coverage":100,
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

- JSON endpoints are pretty-printed (two-space indent) and
  **syntax-highlighted** with the vendored [yace](https://github.com/petersolopov/yace)
  tokenizer (`window.YaceTok`). A JSON-key rule colours object keys
  separately from string values, so the payload reads like an IDE view.
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
   the dashboard in an iframe. The server strips the query string before
   routing, so `http://localhost:8080/?theme=light` (and
   `?theme=dark` / `?theme=system`) serves the themed dashboard instead of
   404ing.
2. otherwise the explicit CLI theme (`--theme=light` / `--theme=dark`).
3. otherwise the saved `localStorage` choice, if one was saved.
4. otherwise the system theme (`prefers-color-scheme`).

`--theme` only sets the *initial* selection. The dropdown and Save settings
still override it afterwards in the browser.

## Related CLI flags

| Flag | Default | Description |
|------|---------|-------------|
| `--serve` | off | Run the pipeline, then spawn the HTTP dashboard server (blocking) on the port. It is a switch: passing `--serve` is the only way to start the server, and omitting it (the default, `off`) renders and exits without serving. There is no `--no-serve`, because a flag already controls it |
| `--port=N` | `8080` | Server port (a valid `Positive` integer) |
| `--serve-workers=N` | `4` | HTTP server task-pool worker count for `--serve` (a valid `Positive` integer, capped at 256). Only relevant with `--serve` |
| `--theme=NAME` | `system` | Initial dashboard theme: `light` \| `dark` \| `system` (case-insensitive) |
