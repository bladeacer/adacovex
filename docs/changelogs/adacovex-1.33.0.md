# adacovex 1.33.0

Date: _2026-08-28_

Version bumped 1.32.0 -> 1.33.0.

## Changes

### C1: Test-scope dependencies (SBOM and dashboard)

A new `test` dependency scope joins `base`, `dev`, `transitive`, `vendored`
and `system`.  A dependency is classified `test` when it is used only by the
project's tests:

- a crate declared under a `[[test-depends-on]]` section of `alire.toml` or
  `alire-dev.toml` (the manifest label the parser picks up); or
- a library with-claused only from a **test project file**: a `.gpr` under a
  `tests/`, `test/` or `t/` directory, or a test-named project such as
  `test_runner.gpr`.  The classification propagates to everything the test
  project pulls in transitively.

The scope is surfaced everywhere the others are: the SBOM
`adacovex:dep_scope` property (`"test"`), the dashboard dependency tree
badge, the scope filter checkbox, the scope-stack legend, and the polar
rings on the Overview and Charts tabs.  `Collect_GPR_Files` now collects
`.gpr` files under `tests/`, which it previously skipped, so test harness
projects resolve as dependencies in the first place.

### C2: Robust version probing (`go version`, flag fallbacks)

The version probe now runs `go version` for the `go` tool (it accepted no
flag before, so `go` always reported an empty version).  Probing is robust
across tools: the probe tries the tool's configured flag first, then falls
back through `--version`, `-v` and `version`, and takes the first successful
run.  `fossil` and `git-lfs` keep their `version` subcommand; the fallbacks
cover any tool whose configured flag fails.  Version tokens are cleaned:
`go version go1.21.5 ...` reports `1.21.5` (leading `go` stripped, local
build tags cut at `:`), and `node --version` reports `26.7.0` instead of
`v26.7.0`.  The probe-file and tool-set cache namespaces were salted (`.v2`
and `|tools-v3|`) so stale 1.32 probe results are never served.

### C3: Alire dependency versions resolved via `alr show`

`alr show` prints the release as `<crate>=<version>: <description>` on the
first line and the licence under `License:` -- not the `Version:` /
`Licenses:` keys the resolver expected, so manifest-declared Alire crates
(gnatprove, gnatdoc_bin, gnatformat_bin, and any other `[[depends-on]]`)
always reported an empty version and licence.  The `alire` ecosystem row now
parses the first-line `<crate>=<version>` form for the version and the
`License:` line for the licence.  The adacovex self-SBOM now records
`gnatprove 16.1.0`, `gnatdoc_bin 26.0.0` and `gnatformat_bin 26.0.0` (all
`dev` scope) instead of empty versions.

### C4: Hard-coded vendored-library table removed from the parser

The parser no longer carries a hard-coded table mapping the bundled
dashboard files to npm package names and versions (flexsearch 0.7.31,
nomnoml 1.7.0, graphre 0.1.3, charts.css 1.2.0).  Vendored components are
now discovered from the data:

- the component name is the file's own base name;
- the version is read from the file's own banner comment when it carries one
  (for example `FlexSearch.js v0.7.31 (Bundle)`);
- the licence and website are resolved live from the package registry under
  that same name when the registry knows it (flexsearch, nomnoml, graphre);
  an asset the registry does not know keeps a `pkg:generic` PURL and no
  guessed metadata.

The authored dashboard modules under `resources/css/` and `resources/js/`
are never componentised: those directories hold the project's own code, not
vendored packages.  The Credits tab keeps its curated table of the bundled
libraries; the SBOM describes what is actually on disk.

### C5: Dashboard search finds page content

The header search index was case-sensitive: queries were lowercased but the
full-text index of each tab's rendered content was not, so page text such as
"Orphan Tags" (or any HLR tag) could not be found.  The index is now folded
to lowercase, so searching `orphan`, a package name, or an HLR tag finds the
tab that holds it.  Dependency names, versions, scopes, licences and PURLs
stay indexed as before.

### C6: Dependency diagram rendered as SVG with real clickable nodes

The nomnoml dependency diagram is now rendered as SVG (`nomnoml.renderSvg`)
instead of a bitmap canvas.  Every node is real geometry: each box (and its
label) is clickable with its exact hitbox -- no manual canvas hit-testing
and no zoom-math drift -- and opens the same split-view detail panel as the
tree.  The diagram scales with its `viewBox`, so boxes are never upside
down or clipped, long labels no longer overflow their boxes, and a wide
graph scrolls horizontally inside the card.  Hovering a node shows a
tooltip with the dependency name and version.  "Download SVG" now
serialises the rendered SVG instead of rasterising the canvas.

### C7: Hand-rolled charts replace the vendored Charts.css

The dashboard's metrics charts no longer depend on the vendored
[Charts.css](https://chartscss.org/) framework (`resources/charts.min.css`
and the `charts-patch.css` overlay are deleted).  The Credits tab and
THIRD_PARTY_NOTICES still credit Charts.css -- as **inspiration** (MIT,
not bundled): the dashboard ships its own patched, hand-rolled charts that
borrow Charts.css's ring-and-segment visual language.  All six chart cards
are now hand-rolled with plain CSS/SVG, which fixes the rendering problems
the framework introduced:

- **Donuts** (SPARK Proof, Tests Pass/Fail, Overview Tests, Overview Doc
  Coverage) are conic-gradient rings with a CSS hole -- the same pattern
  as the polar ring.  The ring colour reflects the covered share: fully
  green at 100% (previously every slice resolved to the same green,
  so partial coverage never showed red), with green + red segments for
  partial coverage.  The centre hole carries the value and caption, and
  because the ring is a fixed-size block (not an absolutely positioned
  table cell) the readout line below never overlaps the chart.
- **Proof Check Types** and **Test Results by Category** are flex rows
  with a fixed, ellipsising label column and a track bar (green proved
  share with a red unproved remainder for proof categories).  The old
  column chart rotated its labels with a custom `rotate-labels` class
  that Charts.css does not define, which produced overlapping label
  boxes and text overflow; the new rows never rotate and long category
  names ellipsise instead of overflowing.

The Overview tab's Tests donut also keeps its readout line
(`N passed, M failed` below the ring), so the pass/fail numbers stay
visible.  The charts remain dependency-free and follow the theme via CSS
variables.

### C8: Dashboard HTML/CSS/JS modularised

The single authored `dashboard.js` and `dashboard.css` are split into
per-concern modules under `resources/js/` (theme, tabs, deps, details,
nomnoml diagram, search) and `resources/css/` (base styles including the
hand-rolled donut/bar chart styles).  The page shell inlines each module
at its own placeholder; `tools/gen-dashboard.py` bundles them in
dependency order (vendored libraries first, then authored modules).

### C9: Test-labelled vendored dependencies across every ecosystem

C1 classifies `test` scope from Alire manifests and test project files.
Vendored components (packages under `node_modules`, `vendor/`, and the
other vendored roots) are now classified `test` the same way, across every
supported ecosystem:

- **Section labels**: `package.json` sections whose key contains `test`
  (for example `testDependencies` or `devTestDependencies`), Cargo's
  `[dev-dependencies]` (Cargo's native test-only section) plus any
  section containing `test`, composer's `require-dev`, Gemfile
  `group :test` blocks, `pom.xml` `<scope>test</scope>` dependencies,
  `pyproject.toml` test extras and Poetry `[tool.poetry.group.test.*]`
  sections, and `Package.swift` dependencies declared inside a
  `.testTarget(...)` block.
- **The name heuristic** (test pre/suffix): a component whose name starts
  or ends with the literal word `test` is test-labelled.  The heuristic
  now works across every ecosystem -- not just npm -- by checking the
  full name and then the last segment after any `/` or `:`, so
  `@playwright/test`, `test-case`, `github.com/stretchr/testify` and
  `org.testng:testng` all match.  Ecosystems without a native test-only
  section (`go.mod`, `requirements*.txt`) rely on this heuristic.
- **Lockfiles**: the name heuristic also applies to lockfile-resolved
  names -- `pnpm-lock.yaml` / `package-lock.json` / `yarn.lock` next to
  an owner `package.json`, `Cargo.lock` crate names, and `alire.lock`
  crates that the manifest sets leave transitive.

The e2e fixture's `@playwright/test` is the canonical case: it stays a
`devDependencies` entry of `tests/e2e/package.json` (and a
`pnpm-lock.yaml` entry) and is classified `test` by name.

### C10: Overview pairing, hoverable scope ring, scaled proof bars, wider diagram

Four dashboard layout improvements:

- **Overview row pairing**: the **Doc Coverage** donut and the
  **Dependency Scope** ring now share one row (`chart-pair`), so the
  Overview uses its width better instead of stacking two full-width cards.
- **Hoverable scope ring**: every coloured segment of the dependency-scope
  rings (Overview and Charts) is a real SVG arc carrying a native tooltip
  with the scope name and its component count (for example `test: 3`), and
  the segment's opacity rises on hover.
- **Proof Check Types scaling**: the proof-category bars now scale with
  the category's magnitude exactly like the test-category bars -- the
  track width is the category's share of the largest category, so a
  407-VC category reads as a longer bar than a 56-VC one (the green/red
  proved/unproved split stays inside the track).
- **Wider nomnoml diagram**: the SVG now fills the width allocated to the
  diagram card (the space the dependency tree would use) instead of
  shrinking to the graph's natural size, and centres horizontally inside
  the card; deep graphs still scroll.

## Test Suite

Native suite grows to 1063 tests (14 categories).  The HTML/Markdown
renderer suite adds checks that the dashboard charts are hand-rolled:
full and partial donut gradients (green at 100%, green+red split for
partial proof), the bar-row label/track markup, proof-bar magnitude
scaling (a smaller category's track is a percentage of the largest), the
`chart-pair` Overview row, the hoverable SVG scope ring with its
per-segment `scope: count` tooltips, and that no `charts-css` markup
remains in the served page.

989 tests (was 973).  The SBOM generator suite gained 16 tests:

- `[[test-depends-on]]` crates in the publishing and dev manifests are
  classified `Scope_Test` (base deps stay base);
- a library with-claused only from a `tests/` harness project is
  `Scope_Test` with a `pkg:gpr/libt` PURL;
- `Scope_Property` maps every scope including `test`.

It then grew by a further 44 tests for the vendored test labels:

- `@playwright/test` (test-named npm package) and a `testDependencies`
  section package are `Scope_Test`; a `devDependencies`-only package
  stays vendored;
- Cargo `[dev-dependencies]`, Gemfile `group :test`, Maven
  `<scope>test</scope>`, pyproject `test` extra, composer `require-dev`,
  and Package.swift `.testTarget` dependencies are `Scope_Test`;
- the name heuristic across ecosystems: `github.com/stretchr/testify`
  (go.mod module path) and `test-case` (Cargo.lock crate) are
  `Scope_Test`;
- lockfile-resolved names: `@playwright/test` via `pnpm-lock.yaml` and
  `test_utils` via `alire.lock` are `Scope_Test` (an unlabelled
  `alire.lock` crate stays transitive).

The dashboard e2e suite (22 tests) gained layout tests: the Overview
Tests readout, page-content search (`orphan`), clickable SVG diagram
nodes, the test-scope filter checkbox, and the credits-table rows
(Playwright as a test dependency, Charts.css credited for inspiration).

## Proof Results

Platinum, 723/723 VCs proved across 50 analysed units (unchanged at 1.33.0
-- the parser, cache and renderer changes are in default-off or
SPARK-Mode-On-ensuring units; the new `test`-scope branches in the
manifest parser and the renderer prove without new VCs).  Invocation:
`adacovex prove` (`--steps=10000`, gnatprove 16.1.0).  0 unproved, 0
justified.

## Traceability

No new HLRs.  The manifest-scope work reuses `HLR-MANIFEST` /
`HLR-SBOM` (`src/parsers/adacovex-parsers-manifest.ads` /
`src/core/adacovex-types.ads`), the version probing reuses the
system-tool discovery under `HLR-SBOM`, and the dashboard changes reuse
`HLR-RENDER-HTML` / `HLR-DASH` (`src/renderers/adacovex-renderers-html.ads`).
