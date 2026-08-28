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

### C7: Overview tests chart readout

The Overview tab's Tests donut chart now carries the same readout line as
the Charts tab (`N passed, M failed` below the ring), so the pass/fail
numbers stay visible when the pie labels have no room.

### C8: Dashboard HTML/CSS/JS modularised

The single authored `dashboard.js` and `dashboard.css` are split into
per-concern modules under `resources/js/` (theme, tabs, deps, details,
nomnoml diagram, search) and `resources/css/` (base styles plus a
`charts-patch.css` layered on top of the vendored Charts.css, giving the
patch an explicit cascade position after the vendored file).  The page
shell inlines each module at its own placeholder; `tools/gen-dashboard.py`
bundles them in dependency order (vendored libraries first, then authored
modules).  The Charts.css patch keeps labels and data chips inside their
columns, upright pie labels, and theme-correct chart colours.

## Test Suite

989 tests (was 973).  The SBOM generator suite gained 16 tests:

- `[[test-depends-on]]` crates in the publishing and dev manifests are
  classified `Scope_Test` (base deps stay base);
- a library with-claused only from a `tests/` harness project is
  `Scope_Test` with a `pkg:gpr/libt` PURL;
- `Scope_Property` maps every scope including `test`.

The dashboard e2e suite (22 tests) gained four layout tests: the Overview
Tests readout, page-content search (`orphan`), clickable SVG diagram nodes,
and the test-scope filter checkbox.

## Proof Results

Platinum, 723/723 VCs proved across 50 analysed units (unchanged at 1.33.0
-- the parser, cache and renderer changes are in default-off or
SPARK-Mode-On-ensuring units, and `Scope_Property`'s added branch proves
without new VCs).  Invocation: `adacovex prove` (`--steps=10000`,
gnatprove 16.1.0).  0 unproved, 0 justified.

## Traceability

No new HLRs.  The manifest-scope work reuses `HLR-MANIFEST` /
`HLR-SBOM` (`src/parsers/adacovex-parsers-manifest.ads` /
`src/core/adacovex-types.ads`), the version probing reuses the
system-tool discovery under `HLR-SBOM`, and the dashboard changes reuse
`HLR-RENDER-HTML` / `HLR-DASH` (`src/renderers/adacovex-renderers-html.ads`).
