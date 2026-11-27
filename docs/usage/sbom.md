# The `sbom` subcommand

## When and why to generate an SBOM

A [Software Bill of Materials (SBOM)](../glossary/ste100/tooling-terms.md#technical-name-software-bill-of-materials-sbom) is a structured inventory of every
component in your project, plus its provenance, licence, and (in adacovex's
case) its SPARK proof level and compliance context. Generate one in these
cases:

- **Auditing or certifying** -- an SBOM is a standard artifact for safety
  certification (DO-178C, ISO 26262, IEC 62304). It shows the auditor exactly
  which Ada/Alire components are in scope and which are proved / not proved.
- **Shifting left on supply-chain security** -- the dependency graph exposes
  transitive dependencies, their licences, and their PURLs so you can review
  them before a release.
- **Embedding in CI** -- the proof-aware SBOM carries the assessed standard and
  level, so downstream tooling (policy engines, compliance dashboards) can
  consume it without re-parsing markdown reports.
- **Reproducible builds** -- adacovex honours `SOURCE_DATE_EPOCH`, so the SBOM
  timestamp is deterministic when tied to a git commit.

`adacovex sbom` resolves the target project's dependency graph from its Alire
manifest (`alire.toml` / `alire-dev.toml`), the solved-crate list in
`alire/alire.lock`, and the root `.gpr` `with` clauses, then writes a
proof-aware software bill of materials in CycloneDX 1.5 JSON, SPDX 2.3 JSON,
or Markdown.

## How to read the output

Choose the format that matches your toolkit:

- **CycloneDX 1.5 JSON** (`--format=cyclonedx-json`) -- drop into any CycloneDX
  consumer (Dependency-Track, OWASP Dependency-Check, and more). The root
  component
  carries `adacovex:proof_level`, `adacovex:standard`, `adacovex:dal_target`,
  and `adacovex:level`. Every dependency has a `language` field inferred from
  file extensions or declared ecosystems.
- **SPDX 2.3 JSON** (`--format=spdx-json`) -- compatible with SPDX-aware tools
  (FOSSA, Snyk, ScanCode). The adacovex properties appear as
  `attributionTexts` on the root package.
- **Markdown** (`--format=md`) -- human-readable table, useful for audits and
  reports. Default path is `<target>/docs/compliance/SBOM.md`.

### Key fields

| Field | Where it appears | Meaning |
|-------|-----------------|---------|
| `adacovex:proof_level` | Root component | Assessed SPARK level (`Stone` .. `Platinum`) |
| `adacovex:standard` | Root component | Compliance standard (`DO-178C`, `ISO 26262`, `IEC 62304`) |
| `adacovex:dal_target` | Root component | Shared rigour tier (`DAL-A` .. `DAL-E`) |
| `adacovex:level` | Root component | Standard-specific label (`DAL-C`, `ASIL B`, `Class A`) |
| `language` | Every component | Implementation language(s) inferred from file extensions |
| `purl` | Every component | Package URL for registry linking |

Dependencies report `adacovex:proof_level = "Not proved"` because adacovex only
proves the target itself. The SBOM is mutually exclusive with `--compare-base`
and `--coverage-delta`.

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
DO-178C / ISO 26262 / IEC 62304 properties at the shared DAL tier.
`--standard=iso26262` / `--asil=B` narrows it to ISO 26262 at ASIL B, and
`--class=A` to IEC 62304 at Class A. See [Standards](standards.md) for the
cross-standard tier mapping.

## Properties

Only the root component -- the project adacovex actually assessed -- carries:

- `adacovex:proof_level` -- `Stone`..`Platinum`, the honest assessed level.
- `adacovex:standard` -- `DO-178C` / `ISO 26262` / `IEC 62304`.
- `adacovex:dal_target` -- `DAL-A`..`DAL-D` (omitted for `DAL-E`).
- `adacovex:level` -- the standard-specific label (`DAL-C` / `ASIL B` /
  `Class A`, omitted for `DAL-E`).

Dependency components report `adacovex:proof_level = "Not proved"` (adacovex
only proves the target itself, never third-party dependencies). Properties are
encoded as `attributionTexts` in SPDX.

## Determinism

The `metadata.timestamp` / `creationInfo.created` field honors the `SOURCE_DATE_EPOCH` environment variable (reproducible-builds convention). When set to a Unix epoch second count, the timestamp is derived from it in UTC via pure integer math. As a result, SBOM output is byte-for-byte deterministic across runs and machines. To tie it to a specific git commit, run `export SOURCE_DATE_EPOCH=$(git -C <target> log -1 --format=%ct)` before adacovex.

The bundled `make` targets (`run-self`, `run-ada-crdt`, `prove`, `release`, and Ada_CRDT's `prove`/`badges`) already set it from the target's git `HEAD` commit time.

## Exclusivity and ordering

`sbom` is mutually exclusive with `--compare-base` and `--coverage-delta`. It
scans sources, parses proof/test results, and assesses DAL first. As a
result, the emitted properties reflect the real assessment state.

Both formats validate against the official
[CycloneDX 1.5](https://github.com/CycloneDX/specification) and
[SPDX 2.3](https://spdx.dev) JSON schemas (see
[THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md)).
## Root project declarations

The root project declares dependencies in its own manifests, not only in
its vendored trees. adacovex reads each of them structurally: a JSON key
must belong to the root object, a TOML key to its own section, and a
`go.mod` entry to a require directive. A nested key, a key inside a
string value, a commented line, and a key of another section therefore
never register a component.

- **`package.json`** registers when the install tree is absent. With
  `node_modules` present the installed tree is authoritative, so the
  vendored walk answers for it and this read does nothing. A
  `dependencies` entry is `base` scope and a `devDependencies` entry is
  `dev` scope. The resolved version comes from the root importer blocks
  of `pnpm-lock.yaml` when the lockfile is there, and the package
  registry fills any gap.
- **`go.mod`** registers when no vendor tree resolved the module. A
  direct require is `base` scope and a `// indirect` require is
  `transitive`, each at the version go.mod states. A replace source, a
  replace target, and a commented-out require never register. A
  test-named module such as `github.com/stretchr/testify` takes the
  `test` label.
- **`requirements*.txt`** registers as `dev`-scope `pkg:pypi/*`
  components in Python. A pinned version wins; otherwise the registry
  answers (`pip index versions <pkg>`) when `pip` is installed and online.
  A missing registry keeps the name-only entry: nothing is ever guessed.
- **The other ecosystems' root manifests** register through one table,
  so a language is a row rather than a code path. A base section is
  `base` scope and a dev section is `dev` scope:

  | Manifest | Base section | Dev section |
  |----------|--------------|-------------|
  | `composer.json` | `require` | `require-dev` |
  | `Cargo.toml` | `[dependencies]` | `[dev-dependencies]` |
  | `pubspec.yaml` | `dependencies` | `dev_dependencies` |
  | `DESCRIPTION` (R) | `Imports` | `Suggests` |
  | `*.cabal` | `build-depends` | -- |

  A declaration states a constraint, not a version, so the registry CLI
  resolves it where one exists and it stays empty otherwise. A composer
  platform package (`php`) and an extension (`ext-json`) name the runtime,
  not a distribution, so they never become components. A pubspec entry's
  nested map (`version:`, `sdk:`) is its metadata, so no nested key
  registers, and an R `Imports` continuation line extends the same list.

A vendored package keeps its own manifest authoritative: its subpackages
(`zod/v4`) and its source trees (`zod/src`) are parts of the package, never
components of their own. The package-root rule is on
[the architecture page](../contributing/architecture-dependencies.md#vendored-components-and-test-labelled-dependencies-sbom).

## Language detection

Every dependency component carries a `language` field (CycloneDX JSON /
`components[].properties` under `"name": "adacovex:language"`, or the
Markdown table's `Language` column) describing the implementation language(s)
of that dependency. Detection follows the component's origin, most specific
first.

### Manifest-declared ecosystems

A vendored manifest maps directly onto its language and PURL type:

| Manifest file       | PURL type         | Language   |
|---------------------|-------------------|------------|
| `package.json`      | `pkg:npm`         | JavaScript |
| `Cargo.toml`        | `pkg:cargo`       | Rust       |
| `go.mod`            | `pkg:golang`      | Go         |
| `pyproject.toml`    | `pkg:pypi`        | Python     |
| `setup.cfg`         | `pkg:pypi`        | Python     |
| `requirements*.txt` | `pkg:pypi`        | Python     |
| `composer.json`     | `pkg:composer`    | PHP        |
| `META.json`         | `pkg:cpan`        | Perl       |
| `Gemfile`           | `pkg:gem`         | Ruby       |
| `*.gemspec`         | `pkg:gem`         | Ruby       |
| `pom.xml`           | `pkg:maven`       | Java       |
| `build.gradle`      | `pkg:maven`       | Java       |
| `build.gradle.kts`  | `pkg:maven`       | Kotlin     |
| `Package.swift`     | `pkg:swift`       | Swift      |
| `*.podspec`         | `pkg:cocoapods`   | Swift      |
| `pubspec.yaml`      | `pkg:pub`         | Dart       |
| `*.csproj`          | `pkg:nuget`       | C#         |
| `mix.exs`           | `pkg:hex`         | Elixir     |
| `rebar.config`      | `pkg:hex`         | Erlang     |
| `DESCRIPTION`       | `pkg:cran`        | R          |
| `conanfile.py`      | `pkg:conan`       | C++        |
| `conanfile.txt`     | `pkg:conan`       | C++        |
| `*.rockspec`        | `pkg:luarocks`    | Lua        |
| `*.opam`            | `pkg:opam`        | OCaml      |
| `*.cabal`           | `pkg:hackage`     | Haskell    |
| Alire manifest      | `pkg:alire`       | Ada        |
| `.gpr` project file | `pkg:gpr`         | Ada        |

The set is the union of the ecosystems adacovex reads and the languages
syft catalogues, plus Ada. Six ecosystems name their manifest after the
package rather than the ecosystem (`*.csproj`, `*.gemspec`, `*.podspec`,
`*.rockspec`, `*.opam`, `*.cabal`), so a row may carry a suffix.

> **For contributors:** each row has a committed mini project under
`src/tests/fixtures/ecosystems/`, so the suite checks it against a manifest.

`pkg:maven` covers a Gradle build too. A Gradle build states a group id
rather than an artefact name, so the component keeps the directory name
and the build contributes only its version: a group id is a coordinate
prefix, never a package name.

Two rows read no licence key, because their manifest states one in a
vocabulary that is not SPDX: R's `License:` field is free-form
(`MIT + file LICENSE`) and CPAN's `META.json` uses CPAN's own words
(`perl_5`). The licence file those packages ship classifies instead, so a
licence is never mapped by guess.

The same mapping applies to the root project's own manifests, which
register even when no vendored tree carries them. Their scopes and their
structural read are on
[Root project declarations](#root-project-declarations) above.

### Transitive and workflow dependencies

A lockfile states the set the project resolves, and a workflow states the
actions the pipeline runs: a lockfile-only package is `transitive`, and a
`uses: owner/repo@ref` action is a dev-scope `pkg:github` component. The
lockfile set and the four values that state no dependency are on
[SBOM transitive dependencies](sbom-transitive.md).

### Extension-based inference

A component that carries no manifest -- a vendored tree, a loose source drop,
or a file under `resources/`, `assets/`, or `.adacovex/patches/` -- takes its
language from the extensions that are present, not from a guess. The
extension list and the mixed-language summary are on
[SBOM dependency resolution](sbom-resolution.md#language-detection).

The remaining sections of the original guide -- licence resolution,
test-dependency classification, and the system-tool rules -- are covered on
[SBOM dependency resolution](sbom-resolution.md) and
[SBOM system dependencies](sbom-system.md). Component coverage is measured
against syft on [SBOM comparison with syft](sbom-syft.md).
