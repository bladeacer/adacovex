# adacovex 1.40.0

Date: _2026-08-30_

Version bumped 1.39.0 -> 1.40.0.

## Changes

### C1: The manual now builds with Sphinx and the default theme

The user documentation under `docs/` is now a **Sphinx** project, not an
mdBook one. `docs/conf.py` selects the Sphinx **default theme** (alabaster)
and the **MyST Markdown parser** (`myst_parser`), so the docs stay written in
Markdown exactly as they were -- there is no conversion to reStructuredText.
The build dependencies are pinned in a new top-level `requirements.txt`
(`sphinx` + `myst-parser`), and `.readthedocs.yaml` now points at
`docs/conf.py` and installs those deps, so the Read the Docs deploy that broke
under mdBook builds cleanly again.

### C2: Offline manual bundling rebuilt around Sphinx

`tools/gen-docs.py` (wired as `make book`, run inside `make build`) now runs
`sphinx-build` over `docs/` and bundles the built site -- every page,
stylesheet, script, and badge -- into `src/adacovex-docs_template.ads` as a
path-keyed asset table, the bundled offline manual the `--serve` server serves
at `/docs`. The mdBook search/print machinery (`elasticlunr`, `mark`,
`print.html`) is gone; Sphinx's own searchable site is bundled instead.
`tools/check-book-links.py` (`make book-links-check`) verifies every link in
the bundle against a fresh `sphinx-build` from a temp copy of `docs/`, so a
stale local Sphinx build product can never mask a broken link.

### C3: Navigation driven by hidden toctrees

Sphinx sidebar navigation comes from `:toctree:` directives, so `docs/index.md`
now ends with hidden toctrees that pull in `usage/`, `contributing/`,
`api-docs/`, `changelogs/`, `proof/`, `compliance/`, and `badges/`. The retired
mdBook files `docs/book.toml` and `docs/SUMMARY.md` are deleted, and the old
`docs/book/` build output is no longer tracked (its Sphinx replacement builds
into `docs/_build/`, now gitignored). Pages not reachable from a toctree are
not auto-discovered; new doc pages must be linked from one.

### C4: Build and source tooling updated

The Makefile `book` / `book-links-check` targets, the `make help` text, the
`complexity-check` source-walk excludes (`docs/_build/`), the manifest tool
registration (`sphinx-build` replaces `mdbook`), and the SBOM fixture/tests all
reference the Sphinx toolchain. The generated `sbom.json`, `docs/api-docs`,
the modern-dashboard prose, and `tools/agents-tree.map` were regenerated or
updated in step so the tree stays internally consistent.

## Fixes

### H1: Read the Docs deploy becomes reproducible

The 1.39 Read the Docs deploy passed validation but still failed to render.
Migrating the manual to Sphinx fixes the root cause: Read the Docs builds
`docs/conf.py` natively with a pinned Python toolchain and `requirements.txt`
deps, so the site deploys without depending on a separately installed mdBook
binary.

## Test Suite

The native suite is unchanged: 1181 tests across 16 categories still pass.
This release changes documentation, build tooling, and SBOM graph metadata
only, so it adds no native assertions.

## Proof Results

Platinum, 0 unproved, 0 justified, 725 VCs (725 proved) under gnatprove
16.1.0. No analysed Ada changed in this release (the edited Ada files are
comments, strings, and the complexity skip-list only), so the totals are
unchanged.

## Traceability

- No new HLRs. The release touches documentation and build infrastructure
  only.
- `HLR-DOC` -- C1 the Sphinx project, C2 the rebundled offline manual, C3 the
  toctree navigation, C4 the tooling updates, and H1 the Read the Docs fix.