# adacovex 1.15.0

Date: _2026-08-18_
Version bumped 1.14.0 -> 1.15.0.

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

## Test Suite

666 tests (unchanged from 1.14.0), across 12 categories: the changelog-listing
fix is release-workflow and Makefile shell code, so no unit tests changed.

## Proof Results

Platinum, 408/408 VCs proved across 45 analyzed units (unchanged from
1.14.0): no Ada source changed, so no new proof obligations. Proven with
`make prove` under gnatprove 16.1.0 (`--steps=10000`).

## Traceability

No new HLRs. The changelog-ordering fix lives in release-workflow shell code,
the `make release` target, and docs, none of which carry HLR traceability
tags.
