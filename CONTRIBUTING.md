# Contributing to adacovex

## Changelog format

Each release gets one file at `docs/changelogs/adacovex-<version>.md`, linked
from `docs/changelogs/index.md` under the `<!-- CHANGELOG_LIST -->` marker
(newest first):

```
# adacovex <version>
Date: _YYYY-MM-DD_
Version bumped <old> -> <new>.

## Changes          -- `### C#:` numbered subsections, one per change
## Fixes            -- `### H#:` numbered subsections (omit if none)
## Test Suite       -- suite size + what changed
## Proof Results    -- SPARK level, VC totals, invocation
## Traceability     -- new HLRs + tags covering changes
```

Rules:

- `## Changes` and `## Fixes` use numbered subsections (`### C#:` / `### H#:`)
  with a short bold-worthy title, then prose -- no bare bullet lists.
- `## Proof Results` states the SPARK level (Stone..Platinum), the exact VC
  totals (e.g. `398/398 VCs proved across 39 analyzed units`), and calls out
  whether any proof metrics changed.
- `## Traceability` lists any new HLRs by tag name and package, then the
  existing `-- HLR-*` tags covering the changed packages.
- `make bump-version` (`VERSION=x.y.z`) creates/updates the changelog; keep the
  section headings and numbering style identical across releases.

## Unit tests

Native (zero-dependency) framework (`Adacovex.Test_Support`, no AUnit). Source:
`src/tests/`; entry point `test_runner.adb` (builds as `bin/test_runner`).
`make test` builds and runs the suite and writes results to
`docs/test_result.md` in a Markdown table format adacovex itself parses.

| Category | Tests |
|----------|-------|
| Types conversions | 67 |
| DAL compliance | 11 |
| Source scanner | 83 |
| GNATprove parser | 64 |
| Test-result parser | 43 |
| CLI config | 34 |
| SVG renderer | 36 |
| HTML/Markdown renderers | 17 |
| SBOM generator | 78 |
| IR synthesis | 27 |
| **Total** | **460** |
