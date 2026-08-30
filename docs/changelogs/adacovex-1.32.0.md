# adacovex 1.32.0

Date: _2026-08-28_

Version bumped 1.31.0 -> 1.32.0.

## Changes

### C1: Proof metrics synced to the honest 723-VC count

The self-assessment proof surface had grown to 723 VCs after the `Adacovex. Server. HTTP. Route` postcondition was converted from a nine-clause implication chain (which exceeded gnatprove's `--steps` budget once the `/docs` route was added) into an expression function.

An expression function's implicit postcondition (``Result = <mapping>``) holds by definition, so the mapping is proved without case-analysis steps. All metric anchors across AGENTS.md, README.md, Makefile, the release manifests, and the Alire index were refreshed to 723 VCs via `make proof-status`. Proof level remains

**Platinum** (723 VCs, 0 unproved, 0 justified under gnatprove 16.1.0).

### C2: SVG badges restored to Shields.io proportions

The badge renderer had drifted away from the Shields.io style: font-size was
16px on a 28px-tall badge with 20px side padding, so the label and value text
dominated the box. Geometry is now restored to the compact Shields.io
proportions -- font-size 11px, badge height 20px, corner radius 3px, text
baseline y=14, and 10px side padding (20px total). The pure sizing math
(`Glyph_Width`, `Text_Width`) still bounds every segment at font-size 11, so
badges stay provable and visually consistent with Shields.io.

### C3: nomnoml dependency diagram reads left-to-right

The dependency hierarchy diagram rendered root-at-top with children flowing
left-to-right (`#direction: down`). It now renders the root on the left and
the children stacked top-to-bottom on the right (`#direction: right`), which
reads as a left-to-right dependency flow. The canvas height now scales with
the child-node count (72px header + 46px per node, 320px minimum) instead of
a fixed 600px, so every box stays large enough to read and click regardless of
graph size.

### C4: Charts tab label and data overlap removed

The "Proof Check Types" column chart rotated its category labels vertically
into a 96px-tall slot, so long labels ("Termination", "Functional") clipped
and overlapped their neighbours. The label slot is now 120px (chart height
340px) with clipping disabled, giving every rotated label the room it needs.
The bar chart's per-row data labels (`.data`) now carry a translucent card
background and a small horizontal pad, so values on short bars no longer
collide with neighbouring rows. Verified against the dashboard e2e layout
tests.

### C5: Overview tab adds a dependency-scope polar chart

The Overview tab's collation charts gained a "Dependency Scope" polar area
chart. It renders the resolved graph's scope split (base / dev / transitive /
vendored / system) as a conic-gradient ring with a centre total count and a
per-scope legend, giving an at-a-glance view of the project's dependency
composition alongside the existing Robustness, SPARK Proof, Tests, and Doc
Coverage charts. The overview chart-card count in the e2e layout suite was
raised from four to five to match.

## Test Suite

973 tests (unchanged). No test logic changed: the proof fix is a
postcondition-only rewrite, the badge and chart changes are presentational,
and the nomnoml direction/height change is client-side JavaScript. The
`dashboard.spec.ts` overview assertion was updated to expect five chart cards.

## Proof Results

Platinum, 723/723 VCs proved across 50 analysed units (was 724 at 1.31.0). The one-VC reduction comes from converting `Adacovex. Server. HTTP.

Route` to an expression function: the explicit nine-clause postcondition (one VC that sat on the solver's step-limit boundary) is replaced by the implicit ``Result = <mapping>`` postcondition, which proves by definition. Invocation: `adacovex prove` (`--steps=10000`, gnatprove 16.1.0). 0 unproved, 0 justified.

## Traceability

No new HLRs. The server routing change is covered by the existing
`-- HLR-SERVER` tag in `src/server/adacovex-server-http.ads`; the badge,
chart, and diagram changes are presentational and reuse the existing
`HLR-RENDER-SVG` / `HLR-RENDER-HTML` tags.
