# adacovex 1.15.0

Date: _2026-08-18_
Version bumped 1.14.0 -> 1.15.0.

## Changes

### C1: docs cross-linking audit and generator-owned API-doc links

The docs were audited for misplaced and missing cross-links. The README's
compliance bullet now leads with the general standards page instead of the
DO-178C-only DAL page, and its ISO 26262 / IEC 62304 links point at the
dedicated ASIL / Class level pages; the "Compliance levels" section links
all three per-level pages. `docs/target-projects.md`'s HLR-format reference
now points at the docstring spec's HLR-tags section instead of the DAL
criteria page, and the plain-text doc references in CONTRIBUTING.md,
llm-usage.md, installation.md, platforms.md, and standards.md became real
links (dashboard.md and sbom.md gained standards links too, and llm-usage.md
carried a stale 653/653 test count, now corrected to 666/666).

The six hand-written reference pages (docstring spec, test formats, SPARK
levels, DAL/ASIL/Class levels) gained reciprocal "See also" sections. The
generated api-docs cross-links live in `tools/rst2md.py` so they survive
`make doc` regeneration: `GUIDE_PAGES` adds a "Guides" section to the API
index, and `PACKAGE_GUIDES` renders a "See also" line on 13 package pages
(parsers, compliance, types, prove, cache, diff, vcs, cpus, renderers,
server) pointing at their reference pages -- gnatdoc drops markdown link
URLs from `.ads` comments, so the links cannot live in source docstrings.
AGENTS.md's Documentation block (via `tools/doc-links.map`) and the
developer-guide now document the pattern.

## Fixes

### H1: release changelog list now newest-first instead of glob order

The `Create GitHub Release` step in `.github/workflows/release.yml` iterated
`docs/changelogs/adacovex-*.md` with a shell glob, so the release body's
**Changelogs** list came out in lexicographic file-name order -- `0.1.0`,
`1.0.0`, `1.1.0`, `1.10.0`..`1.14.0`, then `1.3.0`..`1.9.0` -- instead of
newest-first. The step now collects the in-range versions and pipes them
through `sort -V -r`, so the list reads `1.14.0` down to `1.10.0` (and down
to `0.1.0` when no previous release tag is found). The `make release` target
prints the same list in the same order, and `docs/ci-cd.md` documents the
newest-first contract.

### H2: bump deprecated Node-20 actions to Node-24 runtimes

GitHub deprecated the Node.js 20 runtime on Actions runners: actions that
target Node 20 are now forced to run on Node 24, and every such step emits
a deprecation warning. The composite action's `actions/cache` restore/save
steps (`@v4`, Node 20) and `actions/upload-artifact` steps (`@v4`, Node 20)
are bumped to `@v5` and `@v7` respectively, which run on the Node 24
runtime (minimum Actions Runner 2.327.1). `actions/checkout@v7` and
`actions/attest@v4` already run on Node 24 and are unchanged. All action
inputs and outputs are unchanged, and consumers of the action (e.g.
Ada_CRDT via `bladeacer/adacovex@v1`) pick up the fix with the next
release.

## Test Suite

666 tests (unchanged from 1.14.0), across 12 categories: the
changelog-listing and action-version fixes are release-workflow, Makefile,
and composite-action shell/YAML code, and the docs change is documentation
plus `tools/rst2md.py` Python tooling (covered by `make doc` and
`make link-check`), so no unit tests changed.

## Proof Results

Platinum, 408/408 VCs proved across 45 analyzed units (unchanged from
1.14.0): no Ada source changed, so no new proof obligations. Proven with
`make prove` under gnatprove 16.1.0 (`--steps=10000`).

## Traceability

No new HLRs. Both fixes live in release-workflow shell code, the `make
release` target, the composite action, and docs; the docs change touches
documentation and `tools/rst2md.py` / `tools/doc-links.map`. None of these
carry HLR traceability tags.
