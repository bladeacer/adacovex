# Dashboard metric charts and the robustness tier

This page documents the eight chart cards the dashboard renders and the
robustness tier that rates them. Using the dashboard, its tabs, and the
endpoint table are on [Web dashboard and JSON API](dashboard.md).

## Metrics charts

The **Charts** tab renders eight cards and is a **strict superset** of the
Overview charts. The charts are hand-rolled (no vendored chart library):
donut rings are a conic gradient with a CSS hole (the same pattern as the
polar ring) and bars are flex rows with a fixed label column, so labels
never rotate or overflow and the ring colour reflects the covered share
(fully green at 100%):

- **Robustness** -- the five-axis health radar (Docs, Proof, Tests, Comp,
  Deps) with the S/A/B/C/D tier rating, shared with the Overview (one
  source of truth, so the two tabs cannot drift apart).
- **SPARK Proof by Check Type** -- the per-category proof radar (Flow,
  Init, Runtime, Assert, Func), also shared with the Overview.
- **SPARK Proof** -- *donut* of proved vs unproved VCs (`720/720` shows a
  full green ring. `680/720` shows `94%` green + `6%` red unproved).
- **Proof Check Types** -- *bars* of proved checks per category (flow,
  init, runtime, assertions, functional, termination), sized against the
  largest category so bars scale with magnitude exactly like the test
  chart. The numbers mirror gnatprove's own summary table: on gnatprove 16
  the Flow category sums the "Data Dependencies" and "Flow Dependencies"
  rows, and every category's proved count is Total - Justified - Unproved,
  so the rows sum to the Total.
- **Test Results by Category** -- *bars* of per-category test counts
  (normalised to the largest category; long category names ellipsise in
  the fixed label column instead of overflowing).
- **Docstring Coverage** -- *radial gauge* (half-circle SVG arc) of
  documented vs total subprograms.
- **Tests Pass/Fail** -- *donut* of passed vs failed tests (green when
  every test passes).
- **Dependencies by Scope** -- *polar ring* of base / dev / transitive /
  vendored / system / test components (conic-gradient + CSS hole,
  `--scope-*` theme variables) with a legend. Skipped when the graph is
  empty.

Each card is a different type (radar / radar / donut / bars / bars / radial /
donut / polar) so the tab reads at a glance without duplicating a data story.
No JavaScript is required for the charts (pure CSS/SVG), and the radial
gauge, the scope ring, and the radars follow the light/dark theme via CSS
variables.

The surrounding grid (`chart-grid`) is responsive and the page container is
`max-width:1180px` so large monitors do not stretch cards. Rings are used
where a part-to-whole distribution is the point; bars for max-normalised
comparisons across categories.

## Robustness tier

The Overview tab leads with a **Robustness** radar spider and a tier rating
(S / A / B / C / D). Five quality axes, each a `0..100` percentage:

| Axis | Meaning |
|------|---------|
| **Docs**   | Docstring coverage: documented subprograms / total |
| **Proof**  | SPARK VCs proved / total |
| **Tests**  | Test pass rate: passed / (passed + failed) |
| **Comp**   | Compliance gate: `100` when the target standard is Achieved, `0` when Unmet |
| **Deps**   | Dependency hygiene: (graph components - vendored) / total |

The average of the five axes maps to the tier letter:

| Tier | Average | Colour |
|------|---------|--------|
| S | >= 90 | green |
| A | >= 80 | blue |
| B | >= 65 | purple |
| C | >= 50 | orange |
| D | < 50  | red |

The radar polygon, the per-axis legend with percentages, and the tier chip
are rendered as inline SVG/CSS with integer math (no floating point in the
renderer) and use `var(--accent)` plus per-tier CSS variables, so they
follow the light/dark theme. Next to it, a small **SPARK radar** shows the
proved count per check type, and the **Tests** donut and **Doc Coverage**
radial gauge give the same numbers as the full-size charts.
