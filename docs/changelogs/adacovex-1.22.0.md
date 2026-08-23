# adacovex 1.22.0

Date: _2026-08-24_

Version bumped 1.21.0 -> 1.22.0.

## Changes

### C1: Charts page has six distinct chart types and pies render correctly

The **Charts** tab now shows six cards, each a different type: SPARK proof
donut, proof check types column, test results by category bar, docstring
coverage radial gauge, tests pass/fail pie, and the dependencies-by-scope
polar ring.  The duplicated proof line/area variants are gone and the
docstring coverage visual is back on the Charts tab as a half-circle radial
gauge.

The long-standing "pie <U+2260> pie" bug is fixed at the root: Charts.css
`--start`/`--end` are unitless `0..1` turn fractions, but every pie/donut
slice was fed `0..100` percentages, so each slice rendered as a full circle
(and stacked opaque over the previous one).  All pie values now go through a
`Frac` helper that clamps to `0..1`, and the donut hole is a pure-CSS
`.charts-css.pie.donut::after` circle instead of an invalid `donut` class.

### C2: Overview at a glance - robustness radar with a tier rating

The Overview tab now leads with a **Robustness** radar spider and a tier
rating (S / A / B / C / D) computed as the average of five `0..100` axes:
Docstrings (coverage), Proof (VCs proved), Tests (pass rate), Compliance
(gate achieved), and Deps (non-vendored share of the graph).  The tier chip
is colour-coded per theme, the legend lists each axis with its percentage,
and the thresholds (S >= 90, A >= 80, B >= 65, C >= 50, D < 50) plus axis
definitions are documented in `docs/dashboard.md` and shown in the card.

The per-check-type **SPARK radar** moved from the Charts tab to the Overview
(miniature), the tests visual is now a donut, and the doc-coverage gauge
completes the collation.  All overview visuals are inline SVG/CSS with
integer math (no floating point in the renderer) and follow the active
light/dark theme.

### C3: Dashboard footer with version, licensing and credits

The single-line footer is now a semantic `<footer class="footer">` grid with
three sections: copyright + license + repository + the injected
`v1.22.0` version, the third-party credits summary (Charts.css, nomnoml, graphre, FlexSearch)
linking to `docs/THIRD_PARTY_NOTICES.md`, and
the API endpoints (`/api/metrics`, `/api/deps`, `/badge/*.svg`).  The
version is injected next to `__THEME__`/`__GRAPH_JSON__` by the Ada
renderer from `Adacovex.Version`, so the footer always matches the binary.

### C4: nomnoml diagram top-to-bottom and theme-aware

The dependency diagram now lays out with `#direction: down` (a vertical
tree that stays within the page width on wide dep graphs) and reads the
page's CSS custom properties (`--card`, `--border`, `--fg`) at draw time,
re-rendering on theme change so the box/arrow colours always match.  The
canvas is sized to its container and deep graphs scroll inside
`.nomnoml-wrap` instead of overflowing the layout.

### C5: Dependency tree spacing and theme-aware scope badges

Node text now carries explicit spacing in the markup (no more
`covex1.21.0transitive...` when CSS is slow or copying), and the scope badges
use `--scope-*` CSS variables with `color-mix` backgrounds: dark-theme-safe
purple for `dev`, muted for `transitive`, vendored in the danger colour,
base in the accent colour.

### C6: Scope checkboxes styled with inline SVG pictograms

The four scope checkboxes are custom-styled accessible checkboxes (hidden
native input + styled `.box` with a checkmark SVG) and each has a small
inline SVG pictogram -- info circle for base, wrench for dev, layers for
transitive, warning triangle for vendored -- used sparingly next to the
text labels (`aria-hidden`, focus-visible rings preserved).

### C7: Language-agnostic vendored dependency discovery with SBOM languages

The dependency graph now discovers vendored components beyond Alire/GPR:
`node_modules` (npm, shallow: one component per top-level `package.json`,
`pkg:npm/...@version`), `vendor`, `third_party`, `deps`, `submodules`, etc.
carrying `Cargo.toml`/`Cargo.lock` (pkg:cargo), `go.mod` (pkg:golang),
`pyproject.toml`/`requirements*.txt` (pkg:pypi), `composer.json` (pkg:composer),
`Gemfile` (pkg:gem), and plain source libraries.  A directory without a
manifest becomes ONE component whose language is the top-3 summary of its
source-extension distribution (e.g. `Go; Python; JavaScript`) -- loose files
under a vendor root never become components.

Every SBOM component now carries `language` in CycloneDX (and the Markdown
table), inferred from the file extension or manifest, with mobile
fallbacks.  The graph cache key hashes vendored trees and lockfiles too
(`Vendored_Hash`), so adding/removing vendored code invalidates the cached
graph.

## Fixes

### H1: Pie charts rendered as full circles; "covex1.21.0transitive" spacing

Both reported regressions from 1.21.0 are fixed:

  - pie-type charts (overview collation, Charts tab, dependencies scope)
    were fed 0..100 values into unitless 0..1 properties, drawing each
    slice as a full circle; now correct with a real donut hole.
  - the dependency tree's name/version/scope badges collapsed together
    when CSS copy-paste or slow load lost `gap`; markup now carries
    explicit textual spacing and `line-break` safety.

## Test Suite

900 tests passing (886 -> 900) across 14 categories.  New `SBOM generator`
checks pin the language-agnostic vendored discovery: npm packages under
`node_modules` register as `pkg:npm/...@version` (shallow), a mixed-language
`vendor/` directory becomes one component whose `Language` lists the top-3
source-extension languages, and loose files under a vendor root never become
components.

## Proof Results

Platinum, 720/720 VCs proved (unchanged from 1.21.0): the radar, radial
gauge, tier, and removal digs all live in default-off renderer bodies or are
pure CSS in the inlined dashboard template, and the vendored-discovery code
sits in the parser's I/O/container-heavy default-off body -- not new SPARK
obligations.  0 unproved, 0 justified.  Re-verified with
`adacovex prove --target=. --force` under gnatprove 16.1.0.

## Traceability

No new HLRs.  Coverage:

   - `HLR-DASH` -- C1 chart variety/pie fix, C2 robustness radar + tier
     rating, C3 footer, C4 nomnoml, C5 spacing/badges, C6 checkbox icons;
   - `HLR-MANIFEST` / `HLR-SBOM` -- C7 language-agnostic vendored discovery
     and SBOM language fields.
   - `HLR-DOC` -- `Comp`/tier documentation in `docs/dashboard.md`;
   - `HLR-SERVER` -- `__VERSION__` footer injection.

See `docs/dashboard.md`, `docs/sbom.md`, `docs/THIRD_PARTY_NOTICES.md`.