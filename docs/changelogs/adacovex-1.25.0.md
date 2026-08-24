# adacovex 1.25.0

Date: _2026-08-24_

Version bumped 1.23.0 -> 1.25.0.

## Changes

### C1: Complexity checker warning hygiene

`adacovex-complexity.adb` now returns `Result` explicitly from the
`Analyze_File` exception handler, eliminating the GNAT missing-return warning,
and the spurious `pragma Unreferenced` on `Print_Report` thresholds has been
removed so the gate parameters are no longer flagged as unreferenced.

### C2: Playwright acknowledged as a development dependency

`docs/THIRD_PARTY_NOTICES.md` and the dashboard Credits tab now list
Playwright (Apache-2.0) as a development dependency used for end-to-end
dashboard layout tests (`make e2e`).

### C3: Dependency tree filter state preservation

The `filterByScope` JavaScript function now uses `Map` instead of a plain
object to snapshot and restore `details` open states, fixing the bug where
DOM-element keys were stringified to `[object HTMLLIElement]` and caused the
tree to collapse irrecoverably after filtering.

### C4: SPARK proof radar on Overview matches Robustness styling

The per-check-type SPARK proof radar on the Overview tab now uses the same
split layout, tier badge, and legend structure as the Robustness radar,
making both charts visually consistent.

### C5: Overview chart types updated

Test categories on the Overview tab now render as a Charts.css column chart
instead of a custom CSS grid, and docstring coverage uses a radial chart
styled consistently with the other quality gauges.

### C6: Charts page theme awareness

All chart colours on the Charts tab now use CSS custom properties (`var(--accent)`,
`var(--fg)`, `var(--border)`, `var(--card)`, `var(--muted)`) so they
adapt automatically to light, dark, and system themes.

## Fixes

### H1: nomnoml diagram inherits dashboard theme colours

The nomnoml renderer now reads `--card` and `--fg` from the dashboard theme
variables, so the dependency diagram background and arrow colours match the
active light/dark/system theme.

### H2: Standards=all badge set includes all three standard families

When `--standard=all` is selected the overview now emits badges for DO-178C,
ISO 26262, and IEC 62304 at their target tiers (DAL-C, ASIL B, Class A),
rather than only the single active standard.

## Test Suite

900 tests passing across 14 categories.

## Proof Results

Platinum, 720/720 VCs proved under gnatprove 16.1.0.  0 unproved, 0 justified.

## Traceability

No new HLRs.  Coverage:

   - `HLR-COMPLEXITY` -- C1 warning hygiene in the complexity checker;
   - `HLR-DASH` -- C2 Playwright credit, C3 filter state preservation,
     C4/H1 nomnoml theme awareness, C5 chart-type alignment, C6 charts
     theme awareness;
   - `HLR-STD` -- H2 standards=all badge completeness.

See `docs/cli-reference.md`, `docs/ci-cd.md`, `docs/architecture.md`.
