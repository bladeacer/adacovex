# adacovex 1.39.0

Date: _2026-08-30_

Version bumped 1.38.0 -> 1.39.0.

## Changes

### C1: README links point to the deployed manual

The README documentation links now point at the deployed **Read the Docs**
site (`https://adacovex.readthedocs.io/en/latest/...`) instead of relative
`docs/...` paths. The changelog entries use the same URL shape that
`make release` publishes in the release notes, so the repo, the deployed
site, and any local checkout reference one shared location.

## Fixes

### H1: Read the Docs deploy fails on configuration validation

The `.readthedocs.yaml` build failed before mdBook ran with
`Missing configuration option`. Read the Docs validation requires
`build.tools` (or `build.commands`) whenever `build.jobs` is used, but the
config declared only `build.os` and the `build.jobs` steps. Recreating the
project on the Read the Docs site could not help, because the validator
reads the config file from the repository on every build. The config now
declares `build.tools`, so validation passes and the manual deploys again.

## Test Suite

The native suite is unchanged: 1181 tests across 16 categories still pass.
This release changes documentation and build configuration only, so it adds
no native assertions.

## Proof Results

Platinum, 0 unproved, 0 justified, 725 VCs (725 proved) under gnatprove
16.1.0. No analysed Ada changed in this release, so the totals are
unchanged.

## Traceability

- No new HLRs. The release touches documentation and build infrastructure
  only.
- `HLR-DOC` -- C1 the README deployed-manual links, H1 the Read the Docs
  config fix, and the `docs/changelogs` index under `make book`.