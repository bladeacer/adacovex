# The `sbom` subcommand

`adacovex sbom` resolves the target project's dependency graph from its Alire
manifest (`alire.toml` / `alire-dev.toml`), the solved-crate list in
`alire/alire.lock`, and the root `.gpr` `with` clauses, then writes a
proof-aware software bill of materials in CycloneDX 1.5 JSON, SPDX 2.3 JSON,
or Markdown.

## Usage

```
adacovex sbom [--format=cyclonedx-json|spdx-json|md] [--out=PATH]
           [--standard=NAME|--dal=LEVEL|--asil=LEVEL|--class=LEVEL]
```

- **Default output**: `<target>/sbom.json` for `cyclonedx-json`,
  `<target>/sbom.spdx.json` for `spdx-json`, and
  `<target>/docs/compliance/SBOM.md` for `md`. The containing directory is
  created automatically.
- **Exit code**: `0` when the SBOM was written, `1` otherwise. If the target
  has no Alire manifest the SBOM cannot be generated (the GitHub Action
  reports this as a warning without failing the job).

## Standard-awareness

The `sbom` subcommand accepts the same standard flags as the assessment
(`--standard`, `--dal`, `--asil`, `--class`) and **defaults to all
standards**: without an explicit standard flag the SBOM carries the joined
DO-178C / ISO 26262 / IEC 62304 properties at the shared DAL tier;
`--standard=iso26262` / `--asil=B` narrows it to ISO 26262 at ASIL B, and
`--class=A` to IEC 62304 at Class A. See [Standards](standards.md) for the
cross-standard tier mapping.

## Properties

Only the root component -- the project adacovex actually assessed -- carries:

- `adacovex:proof_level` -- `Stone`..`Platinum`, the honest assessed level;
- `adacovex:standard` -- `DO-178C` / `ISO 26262` / `IEC 62304`;
- `adacovex:dal_target` -- `DAL-A`..`DAL-D` (omitted for `DAL-E`);
- `adacovex:level` -- the standard-specific label (`DAL-C` / `ASIL B` /
  `Class A`; omitted for `DAL-E`).

Dependency components report `adacovex:proof_level = "Not proved"` (adacovex
only proves the target itself, never third-party dependencies). Properties are
encoded as `attributionTexts` in SPDX.

## Determinism

The `metadata.timestamp` / `creationInfo.created` field honors the
`SOURCE_DATE_EPOCH` environment variable (reproducible-builds convention);
when set to a Unix epoch second count the timestamp is derived from it in UTC
via pure integer math, so SBOM output is byte-for-byte deterministic across
runs and machines. To tie it to a specific git commit, run
`export SOURCE_DATE_EPOCH=$(git -C <target> log -1 --format=%ct)` before
adacovex. The bundled `make` targets (`run-self`, `run-ada-crdt`, `prove`,
`release`, and Ada_CRDT's `prove`/`badges`) already set it from the target's
git `HEAD` commit time.

## Exclusivity and ordering

`sbom` is mutually exclusive with `--compare-base` and `--coverage-delta`. It
scans sources, parses proof/test results, and assesses DAL first, so the
emitted properties reflect the real assessment state.

Both formats validate against the official
[CycloneDX 1.5](https://github.com/CycloneDX/specification) and
[SPDX 2.3](https://spdx.dev) JSON schemas (see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)).
