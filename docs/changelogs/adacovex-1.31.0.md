# adacovex 1.31.0

Date: _2026-08-28_

Version bumped 1.30.0 -> 1.31.0.

## Changes

### C1: Dashboard dependency views are clearer

The nomnoml dependency diagram now renders from top to bottom. Dependency details distinguish development and system scope badges. System dependencies show only their resolved version and do not show guessed links or licences.

### C2: Dashboard charts and search are more usable

Chart labels stay inside their cards. SVG badge text uses a larger, sharper scale. Header search indexes every dashboard tab, including Credits.

### C3: Documentation checks support concise user guides

The documentation checker reports user-page length and paragraph-size issues. API documentation and changelogs remain outside these limits. The project documentation index now exposes the additional guide pages.

## Fixes

### H1: Overview documentation coverage layout

The documentation coverage caption no longer overlaps the chart. The tests panel keeps its own explanatory text.

### H2: Missing dependency links

A dependency without a reliable link now shows plain text. It does not show an em dash or a guessed URL.

## Test Suite

Native tests and focused dashboard checks were updated for the new rendering behaviour.

## Proof Results

No proof logic changed in this release.

## Traceability

- `RENDER-HTML` -- dashboard layout, charts, dependency details, and search.
- `RENDER-SVG` -- badge readability.
- `HLR-ARCH` -- documentation quality checks and guide navigation.
