# adacovex 1.37.0

Date: _2026-08-30_

Version bumped 1.36.0 -> 1.37.0.

## Changes

### C1: API playground tab

The dashboard now has an **API** tab that works as an interactive REST
client. Every endpoint the `--serve` server dispatches on is listed as a
clickable button, grouped by purpose (Metrics, Dependencies, Badges,
Documentation). A filter input searches the endpoints as you type, matching
the path, description, and group name.

Clicking an endpoint issues a live `fetch` against the serving origin and
previews the response. JSON endpoints are pretty-printed and syntax
highlighted with the vendored yace tokenizer, with object keys coloured
separately from string values. SVG badge endpoints show the live image above
the raw markup. A toolbar offers **Copy** and **Download** for the raw
response body, so the playground doubles as a lightweight HTTP client without
leaving the browser.

The first endpoint (`/api/metrics`) runs automatically, so the tab always
opens with a live preview.

The endpoint list is static because the server surface is fixed. Each request
is made live against the instance, so what you preview is exactly what `curl`
returns.

### C2: Charts tab is a strict superset of the Overview charts

The **Charts** tab now leads with the same two radars that headline the
Overview: the **Robustness** five-axis radar with its S/A/B/C/D tier rating,
and the **SPARK proof-by-check-type** radar. Both are shared with the Overview
(one source of truth in the renderer), so every Overview chart appears on the
Charts tab and the two tabs cannot drift apart. The Charts tab now renders
eight cards.

### C3: Vendored yace for JSON syntax highlighting

adacovex vendors the `code()` tokenizer highlighter from
[petersolopov/yace](https://github.com/petersolopov/yace) (MIT, v1.1.0) as
`resources/js/yace.js`, exposed as `window.YaceTok`. The API playground uses
it to syntax-highlight the prettified JSON responses of the `/api/*`
endpoints. The tokenizer is adapted from ESM/TypeScript to a single
plain-script binding so the dashboard needs no build step; the tokenizer
logic is unchanged. The dashboard supplies the token colours via theme-aware
CSS. yace is credited on the Credits tab and in THIRD_PARTY_NOTICES.md.

### C4: `--serve` semantics clarified and `--serve-workers` documented as a related flag

The `--serve` flag description now states clearly that it is a switch: passing
`--serve` is the only way to start the HTTP dashboard server, and omitting it
(the default, `off`) renders and exits without serving. There is no
`--no-serve`, because the flag already controls it. The man page and the
Related CLI flags table in `docs/dashboard.md` now list `--serve-workers`
alongside `--port` and `--theme` as a related `--serve` flag, with its own
description (default 4, capped at 256, only meaningful with `--serve`). The
dashboard docs also note that the server strips query strings and fragments
before routing, so `/?theme=light` works.

### C5: More actionable information

The API playground gives users an actionable way to inspect the live
assessment data: preview every endpoint, copy the exact JSON for scripting,
and download the raw response. Combined with the strict-superset Charts tab,
the dashboard now surfaces the same health data in more explorable and
machine-consumable forms.

## Fixes

### H1: `?theme=light|dark|system` on the dashboard URL returned 404

The HTTP server routed on the raw request path, including the query string
and fragment. A browser requesting `http://localhost:8080/?theme=light`
produced a path of `/?theme=light`, which did not match any route and served
`404 Not Found` instead of the themed dashboard. The server now strips the
query string and fragment before routing (`Strip_Query`), so `/?theme=light`,
`/api/metrics?x=1` and `/api/deps#top` reach the same handlers as `/`,
`/api/metrics` and `/api/deps`. The `?theme=` value is applied client-side as
before; the fix makes the request reach the dashboard in the first place.

### H2: Footer no longer lists a redundant tabs hint

The dashboard footer carried a `Tabs: #proof/#deps` hint. Every tab is already
hash-addressable, so the hint only named two of seven tabs and added nothing.
The footer now shows the embed query hint and the JSON API links, and adds a
link to the new API playground. External docs stopped referencing the removed
`#proof`/`#deps` convenience.

## Test Suite

The native suite grows from 1157 to 1167 tests (16 categories). The server
routing category adds 10 checks covering `Strip_Query`: the themed root URL,
query strings and fragments on the JSON API and badge endpoints, the empty
path, and unchanged paths with no query. All 1167 tests pass.

## Proof Results

Platinum, 0 unproved, 0 justified, 723 VCs unchanged under gnatprove 16.1.0.
The dashboard, serve-path, and manifest scanner changes are build-time or
I/O-bound code that adds no analysed Ada, so the VC total stays at the
Platinum bar. The `Strip_Query` server helper is a new spec-declared SPARK
subprogram and is proved alongside the rest of the server spec.

## Traceability

- `HLR-DASH` / `HLR-SERVER` -- C1 API playground tab, C2 Charts superset, C3
  vendored yace, H1 query-string/fragment route stripping, H2 footer cleanup.
- `HLR-CLI` / `HLR-DOC` -- C4 `--serve` semantics and the `--serve-workers`
  related-flag documentation in the man page and dashboard docs.
- `HLR-SBOM` -- C5 actionable information surfaces reusing the existing JSON
  API that also feeds the SBOM.

See `docs/dashboard.md`, `docs/cli-reference.md`, and `docs/THIRD_PARTY_NOTICES.md`.