# adacovex 1.29.0

Date: _2026-08-26_

Version bumped 1.28.0 -> 1.29.0.

## Changes

### C1: Dev-dependency metadata resolved from `alr show` into the SBOM and dashboard

Manifest-declared dependencies -- dev deps from `alire-dev.toml` and base deps
that no lockfile or GPR with-clause resolved -- previously appeared name-only
with an empty version and licence and no source link. adacovex now invokes the
tool-specific `alr show <crate>` (which answers from Alire's local index, no
network access) and parses the `License:`, `Version:` and `Website:` fields.
The metadata is filled onto the freshly appended entry or, when the crate was
already resolved from the lockfile (so it keeps its solved identity), patched
onto the existing entry when those fields were empty.

The SBOM spec output carries the source reference in all three formats:

- CycloneDX 1.5: `externalReferences` (type `website`) with the source URL.
- SPDX 2.3: the `homepage` field.
- Markdown: a `Source` column in the dependencies table (and a `| Source |`
  row for the root project).

No garbage links are produced: a URL is only ever taken from the release
metadata, never guessed from a PURL. The dashboard's `/api/deps` JSON now also
ships a `website` field per component.

### C2: Dependency source links prefer the resolved repository

The dep-details Link row picks the resolved `website` when it is a genuine
`http(s)` URL, and only falls back to a PURL-derived registry link for the
well-known registries. The old generic GitHub-search fallback for unknown
ecosystems is gone, because a search URL for a system or generic dependency is
noise.

### C3: Dependency split layout

Collapsed (no detail selected) the dependency tree and the nomnoml diagram fill
the full container width. Selecting a dependency activates a split layout: the
tree/diagram docks to the left column and the detail card slides into a right
column (stacked on small screens). The detail panel moved out of the tree card
so it serves both the Tree and the Diagram views alike.

### C4: Diagram contrast and clickable boxes

nomnoml draws node titles in the `stroke` colour, which the previous theme
binding set to the muted border (light grey in light mode, near-black in dark
mode) -- poor reading contrast on the card fill. The stroke/text now follows the
primary text colour in both themes. nomnoml renders to a single `<canvas>`, so
each box is hit-tested against the layout rectangles returned by the draw and a
click on a box opens its dependency detail panel.

### C5: Chart text is upright, bounded and readable

- Pie/donut labels and values no longer rotate with each slice.  Charts.css
  rotates custom properties by the slice midpoint angle, which flipped numbers
  in large or non-half slices upside down.  They now render with no transform.
- Horizontal bar category labels are width-bounded with an ellipsis and the
  rows have a minimum height, so long test-category names no longer clip or
  spill off the left edge of the dashboard.
- The "Dependencies by Scope" polar centre now sits on a card-coloured disc, so
  the centre figure no longer draws directly on the vivid scope gradient (the
  grey `9` that was hard to read in the middle of the ring).

### C6: Compliance tab is standards-aware

The Compliance section now renders one achievement gauge per standard
(DO-178C, ISO 26262, IEC 62304) with that standard's target integrity level,
achieved percentage and status -- whether one standard or all are targeted.
The table lists every standard and its level and status, and highlights the
targeted standard(s) with a chip and outline. The served dashboard targets all
standards by default, and this brings the compliance chart in line with the
badges row (which already listed every standard under `--standard=all`).

### C7: Detailed proof guidance

The Proof tab gains a "How to proceed (Proof Guidance)" card that turns the
gnatprove unproved counts into concrete next steps per category: Global /
Initializes aspects, initialisation at declaration, loop invariants and range
preconditions, strengthened Pre/Post contracts, Postconditions for functional
checks, and Measure / Decreasing clauses for termination.  When every VC is
proved it reads "No unproved VCs -- the proof is complete."  It reminds the
reader that a justified VC (`pragma Assume`) never counts as proved.

### C8: Duplicate charts removed (DRY)

The Charts gallery no longer repeats information shown on the Overview,
Proof and Tests tabs: the SPARK-proof donut (duplicated the Overview radar),
the tests pass/fail donut (duplicated the Overview Tests donut and the Tests
gauge), the scope stacked bar (duplicated the polar ring) and the docstring
radar (duplicated the Overview coverage donut).  Every chart in the dashboard
now displays a distinct view of the data.

### C9: Terminal colour suppressed in CI

ANSI colour was enabled whenever `NO_COLOR` was unset, so colour escapes could
garble logs on CI runners, which set `CI=true` but not `NO_COLOR`. Terminal
colour now additionally requires that `CI` is unset.

### C10: American English in live docs corrected

Prose Americanisms in the user documentation and API reference were corrected
to British English (`behavior` -> `behaviour`, `analyze`/`analyze` ->
`analyse`) in `docs/architecture.md`, `docs/proving.md`,
`docs/compliance/HLR.md` and `docs/api-docs/adacovex-test-format.md`.  Code
identifiers such as `prefers-color-scheme` and `NO_COLOR` are untouched.

## Fixes

### H1: Dev dependencies report a real licence, version and source URL

Before this release a dev dependency such as `gnatdoc_bin` appeared in the SBOM
as `NOASSERTION` licence, no version and no source.  `alr show` now supplies
`GPL-3.0-or-later WITH GCC-exception-3.1`, version `26.0.0` and the
`https://github.com/AdaCore/gnatdoc` repository, so consumers can identify and
licence-scan the exact release.

### H2: The dependency detail popup is reachable from the diagram view

The detail popup previously lived inside the tree card, so it could not show
when the nomnoml diagram was the active view.  It now lives at the
`#tab-deps` level and serves any view; combined with the new clickable boxes an
item can be selected from either view.

## Test Suite

973 tests passing across 14 categories (unchanged: the new dependency
enrichment integrates with the existing graph builder without changing the
fixture counts).

## Proof Results

Platinum, 724/724 VCs proved under gnatprove 16.1.0. 0 unproved, 0 justified.
The new `Alr_Show_Crate` runs only for manifest-declared crates at graph-build
time and is outside the proof surface (the manifest parser body is not in
SPARK_Mode On).

## Traceability

No new HLRs. Coverage:

  - `HLR-SBOM` -- C1 dev-dep metadata via `alr show`, H1 real dev-dep
    licence/version/source; SBOM spec gains `externalReferences` /
    `homepage` / Markdown `Source`.
  - `RENDER-HTML` -- C2 source links, C3 split layout, C4 diagram
    contrast/clicks, C5 chart text, C6 standards-aware compliance,
    C7 proof guidance, C8 DRY charts, H2 detail popup.
  - `HLR-ARCH` -- C9 CI colour suppression, C10 British-English docs.

See `docs/dashboard.md`, `docs/sbom.md`.