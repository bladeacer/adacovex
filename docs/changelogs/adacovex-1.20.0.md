# adacovex 1.20.0

Date: _2026-08-23_

Version bumped 1.19.0 -> 1.20.0.

## Changes

### C1: Dashboard tabs with dependency tree and Charts.css fixes

The `--serve` dashboard is now organised into clickable tabs
(Overview / Proof / Tests / Compliance / Dependencies / Charts) instead of a
single card stack.  The new **Dependencies** tab renders the resolved
`alire.toml` / `alire.lock` graph as a collapsible `<details>` tree with
scope badges (`base` / `dev` / `transitive` / `vendored`), child counts, and a
client-side name filter.  The same graph is already served at `GET /api/deps`
and via `--emit-metrics`, so the tab is a view, not a new data source.

Charts.css rendering is fixed: bar sizes are now emitted as `0..1` fractions (not `0..100`) so `charts.css` scales correctly, and the SPARK donut now shows proved vs *unproved* slices (previously proved vs total duplicated the proved arc and hid regressions). Test-category bars are normalised to the largest category (previously every bar was `100%`). The template (`resources/dashboard.html`) is now a centered `max-width:1180px` layout with a sticky tab bar, `localStorage`-persisted active tab, and hash-routing (`#deps`, `#proof`, etc. compose with `? theme=`).

The Ada side (`Renderers. HTML`) is split into `Render_Dashboard_Internal` with per-tab builders, a new `Render_Deps_HTML` tree builder, and a `Render_Charts` overload that takes the graph for future scope pies. The bundled template is regenerated via `tools/gen-dashboard.py` as before. See `docs/dashboard.md` (tabs, Dependencies, Charts) and `docs/THIRD_PARTY_NOTICES.md`.

### C2: Make targets grouped and a `sync` alias

`make help` now groups targets (`Core`, `Assessment`, `Docs & sync`,
`Gates`, `Release`) instead of a flat list.  A new `make sync` alias runs
the four doc-sync targets that previously had to be invoked individually:
`agents-tree` + `proof-status` + `test-count` + `doc-links` + `description`.
The grouping mirrors the pipeline order (`check` is still the full gate, now
explicitly listed as `Core`).  No target semantics changed; `make check`
still runs the same cheap-first gates, build+test+prove+doc+sbom, and
count-sync checks.

### C3: CI less brittle with timeouts and clearer debugging output

`ci.yml` now sets `concurrency.cancel-in-progress` and `timeout-minutes`
(25 for self-assessment, 15 for tests/consumer, 10 for coverage-gate),
adds `fetch-tags: true` to the coverage-gate checkout (previously
`fetch-depth: 0` alone could miss tags on shallow clones), and keeps the
existing `actions/cache` for both the toolchain and the result cache.  The
docs (`docs/ci-cd.md`) add a **Debugging guide** table that maps every
`CI GATE:` / `WARNING` / `Skipped_Ct` / `result cache:` line to its meaning
and the action to take, and spells out the three artifacts that are always
available without re-running: `::error`/`::notice` annotations, the
`## adacovex assessment` summary, and the `adacovex-assessment` artifact
(full log + `adacovex-metrics.json` when `emit-metrics` is set).

### C4: Completion exposed as `adacovex completion` command

`adacovex completion [SHELL]` (also `adacovex --completion[=SHELL]`) is
now documented as the primary entry point in `docs/cli-reference.md` and the
man page, with the flag form noted as an alias.  The shell (`bash` / `fish` /
`zsh` / `pwsh`) is auto-detected from `$SHELL` when omitted.  No flag
semantics changed; the parity gate still treats `completion` as CLI-only
(like `status` / `man`).

## Test Suite

886 tests passing (unchanged) across 14 categories.  The HTML/Markdown
renderer category still pins the 38 dashboard and docs expectations (theme
dropdown, badge images, `__THEME__` substitution, and the new tab markers).

## Proof Results

Platinum, 720/720 VCs proved across 48 analysed units (unchanged from
1.19.0): dashboard tabbing, dep-tree rendering, chart fixes, make help
grouping, and CI/doc updates live in default-off or I/O-bound bodies -- no
new proof obligations.  0 unproved, 0 justified.  Re-verified with
`adacovex prove --target=. --force` under gnatprove 16.1.0 (`--steps=10000`).

## Traceability

No new HLRs.  Coverage for the changed surface:

   - `HLR-DASH` -- tabs, dep tree, chart fixes (renderer tests, dashboard docs);
   - `HLR-CLI` -- `completion` command docs and help text (config tests);
   - `HLR-CI` -- `ci.yml` timeouts/concurrency and docs/ci-cd.md debugging guide.

See `docs/cli-reference.md`, `docs/dashboard.md`, `docs/ci-cd.md`,
`docs/THIRD_PARTY_NOTICES.md`.
