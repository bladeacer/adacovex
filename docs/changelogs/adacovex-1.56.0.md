# adacovex 1.56.0

Date: _2026-10-03_

Version bumped 1.55.0 -> 1.56.0.

## Changes

### C1: The sidebar brings the page you are on into view

The manual is a page per section, so the global toctree is far taller than the
drawer that holds it. A reader who clicks a late entry lands on a page whose
own entry sits below the drawer's fold, and the drawer stays where it was, so
the sidebar click looks like it went nowhere.

That reveal existed on the bundled offline manual alone, and only as a
by-product of how that manual is stored. `resources/js/book-nav.js` fills each
page's sidebar stub from the tree under `_nav/`, so the injector is the only
code that ever saw the entries and the only code that could scroll to one. The
online manual, the Sphinx build Read the Docs serves, has the Furo toctree
inline in the page, and nothing moved the drawer there. Measured in Chromium
at 1400x800 before this change: clicking the below-the-fold entry
"The bundled offline manual" left `.sidebar-scroll` at `scrollTop` 0 with the
clicked entry at y=848 in a 668 px drawer.

New `docs/_static/sidebar-reveal.js`, registered through `html_js_files`, moves
the drawer for the online manual, and `tools/gen-docs.py` bundles it with the
rest of `_static/`, so the two manuals cannot drift apart. The rule is the
same on both sides:

- only `.sidebar-scroll` takes a scroll offset. The page itself stays at its
  own top, and the script never scrolls the window or moves an element into
  view by API;
- the write is instant, because Furo sets `scroll-behavior: smooth` on the
  drawer and a smooth reveal from the drawer's top starts seconds late on a
  heavy page, which is the very failure this fixes;
- the entry lands a quarter of the way down the drawer, so its caption and the
  entries after it stay on screen too;
- an entry already comfortably in view leaves the drawer where it is, so the
  drawer never jumps under a reader who has just scrolled it.

The entry is found two ways: Sphinx's `li.current-page > a` first, then by
resolved path, because the manual index is the root document and no toctree
may reference it. A page no toctree names, such as a changelog, an
API-reference package, `genindex`, or the search page, has no entry of its own,
so the drawer stays where it is rather than the script throwing on a null.

On an offline page the tree is injected after this file has run, so it finds no
tree and the injector's own reveal owns the drawer. The file is still bundled
and served, because that is the half of the pair a page with an inline tree
depends on.

### C2: The 1.46.0 SIMD and optimisation-candidate review moves to the history
The SIMD section that closed the 1.46.0 review no longer sits inside the
`make prove` timing table: it was the longest page in the phase and the move
keeps the timing table's column rule (one phase, one representative, a complete
metric set) easy to read. `docs/contributing/perf/optimisation-history.md`
gained the entry `### SIMD and other optimisation candidates (1.46.0)`, which
states the measurements and the conclusion, and `docs/contributing/perf/prove-timing.md`
is now 229 lines, comfortably inside the 250-line gate. The move is a
documentation restructure: no measured figure moved, the conclusion did not
change, and `docs/contributing/perf/prove-timing.md` cites
`docs/contributing/perf/optimisation-history.md` as the section that holds the
1.46.0 review.

### C3: The 1.56.0 release folds into the open performance phase
The open phase is 1.55.0-1.56.0, represented by 1.55.0, because 1.56.0 changed
no measurement methodology and added no Ada unit: the pipeline figures
(41 ms warm, 66 ms cold) and the prove figures (50 ms warm, 72-82 s cold / 878 VCs)
are unchanged from 1.55.0, and every number is still taken with `/proc/loadavg`
recorded beside it. 1.56.0 edits documentation sources, one browser script, and
Python tooling, so the cached proof and the SBOM are unaffected. The release is
also the first one in which the gnatprove pin is checked end to end:
`tools/check-version-consistency.py` now classifies the live gnatprove pins
(^16.1.0 in `alire-dev.toml`, 16.1.0 in the GitHub workflows, in the proof
ledger, and in the docstring example) and refuses to build when any `GATED`
source disagrees, so a version that drifts from the pinned toolchain is a
release blocker.

### C4: The gnatprove pin consistency gate is on
`tools/check-version-consistency.py --check` reads the gnatprove dimension and
verifies that the `GNATPROVE_RANGE` (^16.1.0), the `GNAT_VERSION` (16.1.0), and
the three `GATED` sources (alire-dev.toml, the GitHub workflows, and
docs/proof/16.1.0-ledger.md) all agree on the same version; the docstring
example in `src/core/adacovex-prove.ads` was refreshed from ^15.1.0 to ^16.1.0
and the generated API doc `docs/api-docs/adacovex-prove.md` was regenerated to
match. `make check` runs the gate, and `make prove` deploys the manifest-pinned
gnatprove so the proof runs against the exact version the gate enforces.

## Fixes

### H1: Four manual entries had dropped out of the sidebar

Four lines of the `Maintainer references` toctree in `docs/index.md` carried
two leading spaces:

```
compliance/index
  badges/index
  api-docs/index
  CREDITS
  THIRD_PARTY_NOTICES
```

In a MyST toctree an indented line is a child toctree of the entry above it, so
`badges/index`, `api-docs/index`, `CREDITS`, and `THIRD_PARTY_NOTICES` became
children of `compliance/index`, and the `:maxdepth: 1` on that block then hid
the whole subtree. The sidebar listed 64 entries instead of 68.

The consequence was not only four missing links. Those four pages had no entry
to mark, so `book-nav.js` marked nothing, `reveal` received no entry, and the
drawer never moved on them: the reveal that 1.50.0 added was silently dead for
`/docs/badges/`, `/docs/api-docs/`, `/docs/CREDITS.html`, and
`/docs/THIRD_PARTY_NOTICES.html`.

Two Playwright checks were already failing on `main` because of this, so the
defect was reachable from CI:

- `the injected manual sidebar links resolve at every page depth` visits
  `/docs/api-docs/index.html` and requires a marked entry;
- `the manual sidebar reveals the open entry in the drawer` visits
  `/docs/THIRD_PARTY_NOTICES.html` and requires the drawer to have moved.

The four lines now sit at the left margin, the sidebar lists 68 entries, and
both checks pass. A new check, `every sidebar entry reveals, and the shared
script is bundled`, walks all 68 entries and asserts that each one ends up
inside the drawer, with an explicit assertion that the whole
`Maintainer references` group is present. Reintroducing the indentation fails
it on the group assertion, so the drop cannot come back silently.

### H2: The changelog index skipped three released versions

`docs/changelogs/index.md` is hand-maintained and had fallen behind: 1.35.0,
1.36.0, and 1.55.0 all shipped with a changelog file and none of them was
listed, so the manual's own changelog index stopped at 1.54.0. All four missing
entries, and 1.56.0, are now listed, and the index matches the files in
`docs/changelogs/` again.

### H3: The proof ledger reported the wrong analysed-unit count

`docs/proof/16.1.0-ledger.md` stated 56 analysed units in its status line and
in its reproduction section, while `gnatprove.out` reports `Analyzed 66 units`
and every other record of the campaign reports 66. The metric sync tool
(`make proof-status`) does not police those two prose lines, so the drift was
invisible to the gates. Both now read 66, which is the figure the tool reads
and this release's proof section quotes.

## Test Suite

1657 tests across 25 categories, unchanged from 1.55.0: this release touches no
assessed Ada source. The coverage added is in the tooling and browser layers.

Added:

- Two `tools/tests.py` checks (the suite goes from 139 to 141). One asserts
  that `docs/conf.py` registers `sidebar-reveal.js` through `html_js_files` and
  that the file exists and carries a bundleable `.js` MIME entry; the other
  pins the same contract the injector is held to, that the reveal writes
  `box.scrollTop` on `.sidebar-scroll`, overrides the drawer's smooth
  scrolling, guards a missing entry, and never calls `scrollIntoView`, a
  window scroll, or `documentElement.scrollTop`.
- A Playwright check that walks every sidebar entry and asserts the reveal, and
  that asserts the whole `Maintainer references` group is in the tree.
- A first assertion that `/docs/_static/sidebar-reveal.js` is served from the
  bundled manual, so a future bundling change that drops the file fails rather
  than silently leaving the online manual without it.

Verified by measurement rather than by a fixture: every built page of both
Sphinx builds was loaded in Chromium at 1400x800 and the drawer's scroll
offset and entry position were read. Across 204 adacovex pages and 83
Ada_CRDT pages the sweep reports 0 script errors and 0 entries left off screen,
where before the change the 57 adacovex pages and 13 Ada_CRDT pages whose entry
sits below the fold were not revealed at all.

## Proof Results

Platinum, 0 unproved, 0 justified, 878 VCs across 66 analysed units under
gnatprove 16.1.0 at `--level=4`. The VC count and the unit count are unchanged
from 1.55.0, because the change set is documentation sources, one browser
script, and Python tooling: no Ada unit was added, removed, or edited, so no
verification condition, assertion, contract, or runtime check moved. No
`pragma SPARK_Mode (Off)` was added to any package, and the only two packages
that carry one remain `Types.Implementation` and `Complexity`.

The proof-input hash excludes the bundled manual spec, so the docs edit does
not invalidate the cached proof, and `make proof-status` reports the metrics
still in sync across every live file.

## Traceability

- No new HLRs.
- `HLR-DOCS` -- C1 and H1 change how the manual's sidebar is built and
  served: `docs/conf.py`, `docs/_static/sidebar-reveal.js`, and the
  `Maintainer references` toctree in `docs/index.md`. None of the three is
  assessed Ada source, so no new requirement arises; the manual stays a
  documentation artifact under the existing tags.
- `HLR-RENDER-HTML` -- unchanged. C1 adds a script the served pages load and
  touches no renderer: the dashboard document, the dependency views, the
  charts, and the JSON API are byte-identical.
- H1 adds no requirement either. It restores four documentation pages to the
  sidebar, which is the surface `HLR-DOCS` already covers.
- H2 and H3 are documentation records: the changelog index and the proof
  ledger. H3 changes a stated figure only, and the figure it now states is the
  one `make proof-status` reads from the prover output.
- `tools/gen-docs.py` and `tools/tests.py` are developer tooling, which no HLR
  tag covers, as 1.55.0's H2 and H3 record.