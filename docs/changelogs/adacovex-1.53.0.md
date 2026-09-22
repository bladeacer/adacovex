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

## Test Suite

1637/1637 native tests pass across 25 categories. No test code changed -- this
release is documentation only.

## Proof Results

Platinum, 0 unproved, 0 justified, 878 VCs (878 proved) across 66 analyzed
units under gnatprove 16.1.0. No proof surface changed; the only edits are
to Markdown and documentation, never to Ada sources, so the proof cache is
unaffected.

## Traceability

- No new HLRs. The release improves documentation link readability and
  badge discoverability.
- `HLR-ARCH` -- C1 through C4 are documentation-only changes to changelogs,
  README, and CODE_OF_CONDUCT.
- `HLR-RENDER-SVG` -- C3's badge links point to the badges docs page that
  describes the SVG renderer output.
