# adacovex 1.30.0

Date: _2026-08-26_

Version bumped 1.29.0 -> 1.30.0.

## Changes

### C1: System dependencies get a first-class `system` scope

The dependency graph now models system tools (`python3`, `git`, `gnatprove`,
and more) as a dedicated `system` scope, distinct from `base`, `dev`,
`transitive`, and `vendored`. The dashboard gives the scope its own filter
checkbox, badge colour, and legend entry; the SBOM lists it under `system`
scope; and the `/api/deps` JSON reports `scope: "system"`. A system
dependency's detail panel still notes that no external link or licence is
provisioned -- only the resolved version is shown. Both the dashboard and the
SBOM run the same `Discover_System_Dev_Deps` discovery, so they show the same
system dependencies.

### C2: Flexible ecosystem licence resolution

`Read_Vendor_Manifest` reads the `license` field from each vendored package
manifest (`package.json` for npm/pnpm, `Cargo.toml` for cargo,
`pyproject.toml`/`composer.json` for pypi/composer) and carries it onto the
SBOM component and the dashboard detail panel. When the local manifest carries
no licence, the new `Resolve_Ecosystem_Metadata` resolver falls back to the
package registry. The resolver dispatches on the ecosystem (the PURL type)
through a single static table, so adding a language is one row rather than a
new code path:

- **npm** -- `npm view <pkg> license`.
- **pnpm** -- `pnpm show <pkg> license`.
- **cargo** (Rust) -- `cargo search <pkg>`, with the SPDX id read from the
  `(license: ...)` token in the output.
- **go** and other ecosystems with no portable, reliable registry query keep
  an empty licence; the vendored manifest scanner still reads any in-repo
  licence file.

The fallback runs only when the offline read finds nothing, so a vendored
package that ships a licence never touches the network.

The bundled third-party libraries that the dashboard vendors (Charts.css,
FlexSearch, nomnoml, graphre) now report their known upstream licence (MIT or
Apache-2.0) from a built-in table. The Credits tab and the SBOM therefore list
them with a licence rather than a blank.

### C3: Dependency detail panel is the single, richer source (DRY)

The dependency detail panel is now the one place that shows a dependency's
full detail. It adds the `Language` and `Description` fields (already present
in `/api/deps`) and a per-dependency system-tool note, so the Tree and Diagram
views open the same, complete panel instead of each carrying a partial copy.
The `/api/deps` JSON gains a `description` field to support this.

### C4: e2e tooling reorganised

The ad-hoc `repro*.mjs` scripts at the root of `tests/e2e/` moved into
`tests/e2e/repro/` so the suite root holds only the Playwright config, the
spec, and the server bootstrap. The spec gains assertions for the split-view
toggle and the system-dependency badge.

## Fixes

### H1: Dependency split-view detail panel works from Tree and Diagram

1.29.0 claimed the split layout but the activating class was applied to the
wrong element (`#tab-deps` instead of `.dep-split`), so the flex split never
engaged and clicking a dependency showed nothing. The class now toggles on the
`.dep-split` container, so selecting a dependency from either the Tree or the
Diagram view docks the view on the left and opens the detail card on the
right. By default (no selection) the view fills the container; the split
appears only on selection.

### H2: SPARK proof radar "Flow" label no longer clipped

The radar SVGs used a `0 0 220 220` viewBox, which clipped the top axis label
("Flow" on the proof radar, "Docs" on the robustness radar) at the SVG edge.
The viewBox now starts at `y = -14`, giving the top label headroom so all five
axis labels render.

### H3: Doc-coverage caption no longer overlaps the donut

The doc-coverage card built its caption with a split HTML `style` attribute
that dropped `text-align:center;margin:6px 0 0`, so the "X% documented"
caption sat flush against the donut. The attribute is now a single, correct
`style` string; the same malformed-attribute pattern on the Overview badges
caption is fixed likewise.

### H4: nomnoml diagram legend removed and node clicks easier

The diagram's `[<note> Legend: ...]` box is gone (the scope badges and legend
already live in the Tree view). The canvas click hit-test now adds a small
slack around each box and, when boxes overlap, picks the smallest enclosing
box, so the tight text boxes are easy to hit and clicks near a boundary open
the right dependency.

## Test Suite

973 tests passing across 14 categories (unchanged: the dependency enrichment
and the licence resolution integrate with the existing graph builder without
changing the fixture counts).

## Proof Results

Platinum, 724/724 VCs proved under gnatprove 16.1.0 (unchanged). The new
`Resolve_Ecosystem_Metadata` and the dependency enrichment run only at
graph-build time and are outside the proof surface (the manifest parser body
is not in `SPARK_Mode On`).

## Traceability

  - `HLR-SBOM` -- C1 system dependencies in the dashboard, C2 ecosystem and
    bundled-asset licence resolution; the SBOM spec carries the resolved
    licence for vendored packages.
  - `RENDER-HTML` -- C3 detail panel DRY, C4 e2e assertions, H1 split view,
    H2 radar label, H3 doc-coverage caption, H4 nomnoml legend/clicks.
  - `HLR-ARCH` -- C4 e2e tooling reorganisation.

See `docs/dashboard.md`, `docs/sbom.md`.
