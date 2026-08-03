# adacovex 1.4.0

Date: _2026-08-03_

Version bumped 1.3.0 -> 1.4.0.

## Changes

### C1: Proof-aware SBOM generation (`adacovex sbom`)

New `sbom` subcommand generates a software bill of materials for the target
project from its Alire manifest, `alire.lock` solved-crate list, and GNAT
project (.gpr) with clauses:

```
adacovex sbom --format=cyclonedx-json --out=path/to/sbom.json
```

- `--format` selects `cyclonedx-json` (default, writes `<target>/sbom.json`)
  or `spdx-json` (writes `<target>/sbom.spdx.json`).
- `--out` overrides the output path; the containing directory is created
  automatically.
- The dependency graph is resolved by the new `Adacovex.Parsers.Manifest`
  package: the root project is index 1, then alire.lock crates and GPR
  `with`-clause dependencies (including transitives) are appended, with
  cross-source deduplication.
- The new `Adacovex.Renderers.SBOM` package emits CycloneDX 1.5 JSON and
  SPDX 2.3 JSON documents. Every component carries the proof-aware properties
  `adacovex:proof_level` (`Gold` or `Platinum` from the assessed GNATprove
  result) and `adacovex:dal_target` (`DAL-A` through `DAL-D`; empty for
  `DAL-E`), which in SPDX are encoded as `attributionTexts` entries.
- Both formats validate against the official CycloneDX 1.5 and SPDX 2.3 JSON
  schemas.
- The SBOM mode scans sources, parses proof/tests, and assesses DAL first so
  the emitted properties reflect the real assessment state.
- Mutually exclusive with `--compare-base` and `--coverage-delta`.

### C2: GitHub Action moved to the repository root

The composite action moved from `.github/actions/adacovex/action.yml` to
`./action.yml`, so it is consumed directly as `uses: bladeacer/adacovex@v1.4.0`
(no nested path) and is auto-discovered at the repo root for the marketplace.
All workflows (`ci.yml`, `pr-check.yml`, `release.yml`) now reference
`uses: ./`, and the release tarball packages the root `action.yml`.

### C3: Action SBOM inputs

The action gained two inputs:

- `generate-sbom` (default `true`) -- after the assessment, generate a
  proof-aware SBOM and upload it as an `adacovex-sbom` artifact, with a row in
  the Markdown step summary. Set `false` to skip.
- `sbom-format` (default `cyclonedx-json`) -- SBOM format, passed to
  `adacovex sbom --format=...`.

SBOM generation is skipped automatically in differential and coverage-gate
modes (the two modes are mutually exclusive with `sbom`), and a failed SBOM
(no Alire manifest, for example) is reported as a warning without failing the
job.

## Fixes

### H1: SBOM proof level read before the proof parse

`Run_SBOM` computed the `adacovex:proof_level` property from the proof summary
before calling `Parse_Prove_From_Project`, so the emitted level was always
`Gold` (the default empty-summary mapping). The property is now computed after
the parse, so a verified target emits `Platinum`.

## Notes

- Test suite extended with a new `Adacovex_SBOM_Tests` category (53 checks)
  covering the proof/DAL property mapping, the Alire manifest + GPR dependency
  graph fixture, and CycloneDX/SPDX rendering with quote-escaping and JSON
  structural balance. The suite is now **222 tests**.
- Self-assessment metrics: 22 packages, 46 subprograms, 100% docstrings,
  Platinum (28/28 VCs), 222 tests, DAL-C Achieved.
- New `-- HLR-MANIFEST` and `-- HLR-SBOM` tags are defined in
  `docs/HLR.md` and `docs/compliance/HLR.md`.

## Proof Results

Self-assessment: **Platinum** (28/28 VCs proved, AoRTE-free).

## Traceability

New `-- HLR-MANIFEST` (manifest and dependency-graph parsing) and `-- HLR-SBOM`
(SBOM generation) tags on `Adacovex.Parsers.Manifest` and
`Adacovex.Renderers.SBOM` are defined in `docs/HLR.md` and
`docs/compliance/HLR.md` and traced by the new SBOM feature.
