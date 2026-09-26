# adacovex 1.53.0

Date: _2026-09-22_

Version bumped 1.52.0 -> 1.53.0.

<!-- no-covex-docs-loc: historical release record, line cap does not apply -->

## Changes

### C1: GitHub release links in versioned changelogs

Each versioned changelog now carries a `GitHub:` line linking to the matching
release tag on GitHub. Only versions with a valid release (and Alire crate)
receive the link: 20 of 53 changelog files were updated. The URL uses the
`vX.Y.Z` tag form, matching the existing GitHub Releases URLs in the codebase.

### C2: README link aliases

Every `[https://...](https://...)` link in `README.md` was rewritten to use
concise alias text with `[]()` syntax. A dozen full-URL link texts were
replaced with descriptive labels like `[platforms]`, `[CLI reference]`,
`[CI/CD]`, and `[target projects]` so the prose reads without raw URLs.

### C3: Readable badge links in README

The SVG badges at the top of `README.md` are now clickable. Each links to the
[badges documentation](https://adacovex.readthedocs.io/en/latest/badges/index.html).
A short `## Badges` section was added explaining what the badges report and
pointing at the full page.

### C4: CODE_OF_CONDUCT link aliases

The full-URL markdown links in `CODE_OF_CONDUCT.md` were rewritten to concise
alias text: `[Contributor Covenant, version 3.0]`, `[CC BY-SA 4.0]`, `[FAQ]`,
`[translations]`, and `[resources]`.

### C5: Read the Docs link previews follow the active theme

`docs/_static/rtd-linkpreviews.css` re-points the Read the Docs "link previews"
hover popup at Furo's own colour variables, and `docs/conf.py` loads it through
`html_css_files`. The addon appends the popup to `document.body` and paints it
with hard-coded light colours, so on a Furo page in dark mode the excerpt
rendered dark-theme text on a white box and could not be read. The popup now
uses `--color-background-primary` and `--color-content-foreground`, so it
follows the light, dark, and auto toggle. Every selector carries a `body`
prefix, because the addon installs its stylesheet through
`document.adoptedStyleSheets` and adopted stylesheets apply after all author
stylesheets.

The defect is in the Read the Docs addon rather than in Furo or Sphinx, and
the same popup is affected on every theme that has a dark mode.

## Test Suite

1637/1637 native tests pass across 25 categories. No test code changed -- this
release changes Markdown, one stylesheet, and `docs/conf.py` only, never an Ada
source, so the suite is untouched.

## Proof Results

Platinum, 0 unproved, 0 justified, 878 VCs (878 proved) across 66 analyzed
units under gnatprove 16.1.0. No proof surface changed; the only edits are
to Markdown and documentation, never to Ada sources, so the proof cache is
unaffected.

## Traceability

- No new HLRs. The release improves documentation link readability, badge
  discoverability, and dark-mode legibility of the hosted documentation.
- `HLR-ARCH` -- C1 through C5 are documentation-only changes to changelogs,
  README, CODE_OF_CONDUCT, and the Sphinx project under `docs/`.
- `HLR-RENDER-SVG` -- C3's badge links point to the badges docs page that
  describes the SVG renderer output.
