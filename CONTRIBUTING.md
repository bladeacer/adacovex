# Contributing to adacovex

Welcome! We are excited that you wish to contribute to adacovex. Before you
start, please take a moment to read and understand our
[Code of Conduct](./CODE_OF_CONDUCT.md).

By contributing, you **agree to abide by its terms.**

**New to the codebase?** Read the
[Contributor guide: codebase structure and setup](docs/developer-guide.md)
first -- it tours the source layout, explains how to set up a development
environment, and shows where each kind of change lives.

## Ways to contribute

Code is not the only thing you can contribute. Contributions in the form of
fixing typos, improving docs, triaging issues, reviewing pull requests, and
sharing your opinion on issues are all appreciated.

## Issues

- Before opening a new issue, look for existing issues (even closed ones).
- Do not needlessly bump issues.
- If you are reporting a bug, include as much information as possible:
  the exact `adacovex` command line, the target project layout, the
  OS / Alire / GNAT toolchain versions, and any output. Ideally include a
  minimal test case that reproduces the bug.
- If the bug involves a security issue or sensitive data (PII), do not post
  it in a public issue -- follow the
  [Security Report template](.github/ISSUE_TEMPLATE/security_report.md) and
  contact the maintainer directly.

## Changelog format

Each release gets one file at `docs/changelogs/adacovex-<version>.md`, linked
from [docs/changelogs/index.md](docs/changelogs/index.md) under the
`<!-- CHANGELOG_LIST -->` marker (newest first). The format is enforced by
`make changelog-check` (`tools/check-changelogs.py`) and every release
changelog must pass it:

```
# adacovex <version>
<blank>
Date: _YYYY-MM-DD_
<blank>
Version bumped <old> -> <new>.
<blank>
## Changes          -- `### C#:` numbered subsections, one per change
## Fixes            -- `### H#:` numbered subsections (omit if none)
## Test Suite       -- suite size + what changed
## Proof Results    -- SPARK level, VC totals, invocation
## Traceability     -- new HLRs + tags covering changes
```

Enforced rules:

- Line 1 is exactly `# adacovex X.Y.Z`, line 3 exactly `Date:
  _YYYY-MM-DD_`, and line 5 exactly `Version bumped A.B.C -> X.Y.Z.`; the
  target version in the `Version bumped` line must equal the file's own
  version.
- Only the five sections above are allowed, in this order: `## Test Suite`,
  `## Proof Results`, and `## Traceability` are mandatory, and
  `## Traceability` must be the last section.
- At least one of `## Changes` / `## Fixes` is required.
- `## Changes` and `## Fixes` use sequentially numbered subsections
  (`### C1:`..`### Cn:` / `### H1:`..`### Hn:`), each with a short
  bold-worthy title, then prose -- no bare bullet lists.
- Files are pure ASCII; list items indented under a heading use exactly
  three spaces (never 4+).
- `## Proof Results` states the SPARK level (Stone..Platinum), the exact VC
  totals (e.g. `720/720 VCs proved across 50 analyzed units`), and calls out
  whether any proof metrics changed.
- `## Traceability` lists any new HLRs by tag name and package, then the
  existing `-- HLR-*` tags covering the changed packages.
- `make bump-version` (`VERSION=x.y.z`) scaffolds a new changelog in the
  canonical format (with the previous version detected from the existing
  changelogs); fill in the `### C1:` subsection, keep the section headings
  and numbering style identical across releases, and run
  `make changelog-check` before opening a pull request.

## Pull requests

Pull requests should follow the following conventions.

- Adhere to the existing directory structure under `src/` (see the
  architecture tree in AGENTS.md) and the existing code style.
- Ada 2012 / SPARK 2014 only, and zero-dependency: no library dependencies
  beyond the GNAT runtime.
- Keep the SPARK proof at Platinum: run `make prove` and make sure the VC
  counts match [docs/proof/16.1.0-ledger.md](docs/proof/16.1.0-ledger.md)
  (720 VCs, 0 unproved under gnatprove 16.1.0).
- Keep docstring coverage at 100% (strict mode, cannot be disabled):
  `make run-self` must show Platinum, 100% docs, and DAL-C Achieved.
- If you add or change behavior, extend the native test suite in `src/tests/`
  (900 tests across 14 categories) and run `make test`.
- Keep all source files pure ASCII: `make ascii-check`.
- If a new CLI flag is added, mirror it as a matching GitHub Action input in
  `./action.yml` and document it in `docs/cli-reference.md` and the README
  (see AGENTS.md, "GitHub Action = base-CLI feature parity").
- When adding a release changelog, follow the format above and pass
  `make changelog-check`.
- Only edit the parts of the source code where necessary; do not add
  editor-specific metafiles (put those in your own global `.gitignore`).
- Test if the added features or fixes work as intended, and check for typos.

### Prerequisites

- If the changes are large or breaking, open an issue discussing it first.
- Do not open a pull request if you don't plan to see it through. Maintainers
  waste a lot of time giving feedback on pull requests that eventually go
  stale.
- Do not do unrelated changes.
- Do not be sloppy. I expect you to do your best.
- Double-check your contribution by going over the diff of your changes
  before submitting a pull request. It is a good way to catch bugs/typos and
  find ways to improve the code.

## Submission

- Give the pull request a clear title and description. It is up to you to
  convince the maintainers why your changes should be merged.
- If the pull request fixes an issue, reference it in the pull request
  description using the syntax `Fixes #123`.
- Make sure the "Allow edits from maintainers" checkbox is checked. That way
  I can make certain minor changes myself, allowing your pull request to be
  merged sooner.

## Review

- Push new commits when doing changes to the pull request. Do not squash as
  it makes it hard to see what changed since the last review.
- It is better to present solutions than just asking questions.
- Review the pull request diff after each new commit. It is better that you
  catch mistakes early than the maintainers pointing it out and having to go
  back and forth.
- Be patient. Maintainers often have a lot of pull requests to review. Feel
  free to bump the pull request if you haven't received a reply in a couple
  of weeks. (Hopefully not)
- And most importantly, have fun!

## Unit tests

Native (zero-dependency) framework (`Adacovex.Test_Support`, no AUnit). Source:
`src/tests/`; entry point `test_runner.adb` (builds as `bin/test_runner`).
`make test` builds and runs the suite and writes results to
[docs/test_result.md](docs/test_result.md) in a Markdown table format
adacovex itself parses.

| Category | Tests |
|----------|-------|
| Types conversions | 67 |
| DAL compliance | 16 |
| Source scanner | 86 |
| GNATprove parser | 64 |
| Test-result parser | 50 |
| CLI config | 152 |
| SVG renderer | 161 |
| HTML/Markdown renderers | 38 |
| SBOM generator | 132 |
| IR synthesis | 27 |
| **Total** | **900** |
