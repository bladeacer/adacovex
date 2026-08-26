# The `sbom` subcommand

## When and why to generate an SBOM

A Software Bill of Materials (SBOM) is a structured inventory of every
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

Choose the format that matches your toolchain:

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

The `metadata.timestamp` / `creationInfo.created` field honors the
`SOURCE_DATE_EPOCH` environment variable (reproducible-builds convention).
When set to a Unix epoch second count, the timestamp is derived from it in
UTC via pure integer math. As a result, SBOM output is byte-for-byte
deterministic across runs and machines. To tie it to a specific git commit,
run `export SOURCE_DATE_EPOCH=$(git -C <target> log -1 --format=%ct)` before
adacovex. The bundled `make` targets (`run-self`, `run-ada-crdt`, `prove`,
`release`, and Ada_CRDT's `prove`/`badges`) already set it from the target's
git `HEAD` commit time.

## Exclusivity and ordering

`sbom` is mutually exclusive with `--compare-base` and `--coverage-delta`. It
scans sources, parses proof/test results, and assesses DAL first. As a
result, the emitted properties reflect the real assessment state.

Both formats validate against the official
[CycloneDX 1.5](https://github.com/CycloneDX/specification) and
[SPDX 2.3](https://spdx.dev) JSON schemas (see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)).
## Language detection

Every dependency component carries a `language` field (CycloneDX JSON /
`components[].properties` under `"name": "adacovex:language"`, or the
Markdown table's `Language` column) describing the implementation language(s)
of that dependency.  Detection follows the component's origin, most specific
first.

### Manifest-declared ecosystems

A vendored manifest maps directly onto its language and PURL type:

| Manifest file       | PURL type      | Language   |
|---------------------|----------------|------------|
| `package.json`      | `pkg:npm`      | JavaScript |
| `Cargo.toml`        | `pkg:cargo`    | Rust       |
| `go.mod`            | `pkg:golang`   | Go         |
| `pyproject.toml`    | `pkg:pypi`     | Python     |
| `requirements*.txt` | `pkg:pypi`     | Python     |
| `composer.json`     | `pkg:composer` | PHP        |
| `Gemfile`           | `pkg:gem`      | Ruby       |
| `pom.xml`           | `pkg:maven`    | Java       |
| `Package.swift`     | `pkg:swift`    | Swift      |
| Alire manifest      | `pkg:alire`    | Ada        |
| `.gpr` project file | `pkg:gpr`      | Ada        |

### Extension-based inference

For every other component -- vendored trees, `vendor/`, `node_modules`,
resources, loose source drops, and individual files inside `resources/`,
`assets/`, and `.adacovex/patches/` -- adacovex infers the language from the
**file extensions actually present**.  The extension is the source of truth: a
`.py` file reports Python even when a `Cargo.toml` sits next to it, and the
manifest language only breaks ties.

Supported extensions:

- **Ada**: `.ads`, `.adb`, `.ada`, `.gpr`
- **JavaScript**: `.js`, `.mjs`, `.cjs`
- **TypeScript**: `.ts`, `.tsx`
- **CSS**: `.css`
- **HTML**: `.html`, `.htm`
- **Python**: `.py`
- **Go**: `.go`
- **Rust**: `.rs`
- **C**: `.c`, `.h`
- **C++**: `.cpp`, `.cc`, `.cxx`, `.hpp`, `.hh`, `.hxx`
- **C#**: `.cs`
- **Java**: `.java`
- **Ruby**: `.rb`
- **PHP**: `.php`
- **Swift**: `.swift`
- **Kotlin**: `.kt`, `.kts`
- **Scala**: `.scala`
- **OCaml**: `.ml`, `.mli`
- **Lua**: `.lua`
- **Perl**: `.pl`
- **Haskell**: `.hs`
- **Elixir**: `.ex`, `.exs`
- **Erlang**: `.erl`, `.hrl`
- **Clojure**: `.clj`, `.cljs`
- **Dart**: `.dart`
- **Shell**: `.sh`, `.bash`
- **PowerShell**: `.ps1`
- **SQL**: `.sql`
- **Fortran**: `.f`, `.f90`, `.f95`, `.f03`
- **Assembly**: `.s`, `.asm`
- **R**: `.r`
- **Julia**: `.jl`
- **Zig**: `.zig`
- **VHDL**: `.vhd`, `.vhdl`
- **Tcl**: `.tcl`

A directory that mixes languages reports its **top 3** languages by file count
(for example `"Ada; C; C++"`), so a mixed-language vendored drop is summarised
by what it actually contains rather than by a single guess.

## Licence resolution

Vendored manifest ecosystems report their licence from the local manifest:
`package.json` (`license`) for npm/pnpm, `Cargo.toml` for cargo,
`pyproject.toml` / `composer.json` for pypi / composer. When the local
manifest carries no licence, adacovex resolves it from the package registry
as a best-effort, online fallback. The resolver dispatches on the ecosystem
(the PURL type) through a single static table, so adding a language is one row
rather than a new code path:

- **npm** -- `npm view <pkg> license`.
- **pnpm** -- `pnpm show <pkg> license`.
- **cargo** (Rust) -- `cargo search <pkg>`, with the SPDX id read from the
  `(license: ...)` token in the output.
- **go** and other ecosystems with no portable, reliable registry query keep
  an empty licence; the vendored manifest scanner still reads any in-repo
  licence file for them.

The fallback runs only when the offline read finds nothing, so a vendored
package that ships a licence never touches the network. The resolved licence
flows into every SBOM format (CycloneDX `licenses`, SPDX
`licenseConcluded` / `licenseDeclared`, Markdown `License` column) and the
dashboard detail panel.

Bundled dashboard assets (Charts.css, FlexSearch, nomnoml, graphre) report
their known upstream licence (MIT or Apache-2.0) from a built-in table, so the
Credits tab and the SBOM list them with a licence rather than a blank.

## System dependencies

`Discover_System_Dev_Deps` scans the project's build and dev files (Makefiles,
shell scripts, Python tools, CI workflows, GPR files, Ada sources) for a
curated set of known system binaries, then keeps only the tools that are
installed on `PATH`. Each becomes a `system`-scope component of the root with
a `pkg:generic/<name>` PURL, a resolved `version` (from `<tool> --version`),
and no external link or licence -- by design adacovex provisions only the
version for system tools and never guesses a repository or licence for them.
`system` is a first-class dependency scope, distinct from `base`, `dev`,
`transitive`, and `vendored`; the dashboard gives it its own filter checkbox,
badge colour, and legend entry, and the SBOM lists it under `system` scope.
The dashboard marks these with a `system` scope badge and a note in the
detail panel.

The result shows up in the dashboard Dependency tab (per-dependency detail
popup) and in every SBOM renderer: CycloneDX `components[].language`,
SPDX/JSON `adacovex:language` property, and the Markdown table's
`Language` column.
