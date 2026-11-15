# SBOM dependency resolution

This page covers language detection, licence resolution (local manifests and the package registry), system dependencies, and test dependency classification. The root project's own manifests, output formats, and usage are on [The `sbom` subcommand](sbom.md#root-project-declarations).

## Language detection

For every other component -- vendored trees, `vendor/`, `node_modules`,
resources, and loose source drops -- adacovex infers the language from the
**file extensions actually present**. The extension is the source of truth: a
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

Vendored manifest ecosystems report their licence from the local manifest
(`license` in `package.json`, `Cargo.toml`, `pyproject.toml`, and
`composer.json`; `license:` in `*.cabal` and `*.opam`; `license =` in a
`.rockspec` and `conanfile.py`; `PackageLicenseExpression` in a `*.csproj`;
`s.license` in a `*.gemspec`). A licence file beside the manifest is
classified into an SPDX identifier when the manifest carries none, and the
package registry answers as the online fallback when both are silent.

CycloneDX writes one SPDX identifier in `license.id` and an SPDX
**expression** in `license.expression`, so a licence that carries a space or
a parenthesis (`Apache-2.0 OR MIT`, `Apache-2.0 WITH LLVM-exception`) takes
the expression form. A single identifier (MIT, Apache-2.0, GPL-2.0+) keeps
the `id` form. SPDX output states either shape in `licenseDeclared` and
`licenseConcluded`, because SPDX accepts an expression there.
[The ecosystem table](sbom.md#manifest-declared-ecosystems) names the two
rows that read no licence key, because their manifest's vocabulary is not
SPDX.

The resolver dispatches on the ecosystem (the PURL type) through one static
table, so adding a language is one row rather than a new code path:

- **npm** -- `npm view <pkg> version license homepage --json`, parsed for the
  three fields from one JSON object.
- **pnpm** -- `pnpm show <pkg> version license homepage --json`, likewise.
- **cargo** (Rust) -- `cargo search <pkg>`, with the SPDX id read from the
  `(license: ...)` token in the output.
- **go** -- `go list -m --json <module>@latest`, with the version read from
  the `Version` field. See [Go modules](#go-modules) below: the Go toolchain
  reports no licence and no website, so both come from files instead.
- An ecosystem with no portable, reliable registry query keeps an empty
  licence, version, and website; nothing is ever guessed.

Set `ADACOVEX_OFFLINE=1` (see [Global configuration and state](configuration.md))
to skip every registry query. The resolver then returns only the
offline-known fields, and the native suite runs with it, so the
assessment gates never touch the network.

### Go modules

A vendored Go component resolves its version and licence **offline**, from
files, and only falls back to the registry for the version. Nothing in this
path names a forge, so the same code serves a module on GitHub, GitLab,
Gitea, Codeberg, or a private mirror.

- **Version, offline.** A vendored module's own `require` block lists only
  its *dependencies*, so the module's version cannot come from its own
  `go.mod`. It comes from the vendor root's `modules.txt`, the manifest
  `go mod vendor` writes for every vendored module, as a `# <module>
  <version>` line -- the only offline source of it.
- **Version, fallback.** When `modules.txt` is absent, `go list -m --json
  <module>@latest` supplies the latest published version. The query goes
  through whatever module proxy `GOPROXY` names, so the Go toolchain decides
  which source answers and adacovex never constructs a host name.
- **Licence.** The Go toolchain reports no licence in any form, so the
  licence is read from the licence file beside the manifest (`LICENSE`,
  `LICENCE`, or `COPYING`, each with an optional `.md` or `.txt` suffix) and
  classified into an SPDX identifier by matching marker phrases from the
  licence text: Apache-2.0, MIT, MPL-2.0, ISC, Unlicense, and the two- and
  three-clause BSD variants. A row matches only when every marker it
  requires is present and none it excludes is present, so a four-clause BSD
  or an ambiguous GPL text reports **no** licence. **A licence is never
  guessed.**
- **Website.** Always empty. `go list -m` has no website field, and its
  `Origin.URL` names a forge-specific VCS endpoint, not a project home
  page, so adacovex does not surface it.

A vanity import path (one whose first element is not a forge host, such as
`golang.org/x/text`, `gopkg.in/yaml.v3`, or `k8s.io/api`) resolves the same
way as a forge-hosted path: the version and the licence come from files, and
no URL is ever constructed from the import path.

The PURL type stays `pkg:golang` and the PURL is
`pkg:golang/<module path>@<version>`. The registry ecosystem token is `go`,
not `golang`, so the vendored-manifest reader carries both: the PURL type
follows the package-url specification while the resolver dispatches on the
name of the CLI it spawns.

The npm and pnpm rows answer for all three fields with one `--json` call,
so each component boots node once instead of once per field. The fallback
runs only when the offline read finds nothing, so a vendored package that
ships a licence never touches the network -- and the same holds for a Go
tree that carries a `modules.txt` and a licence file. The
resolved licence flows into every SBOM format (CycloneDX `licenses`, SPDX
`licenseConcluded` / `licenseDeclared`, Markdown `License` column) and the
dashboard detail panel; the resolved version and website appear in the
dashboard detail panel and the `/api/deps` JSON.

The resolver caches each answer in a per-project store under the project's
result cache (the same `--cache-dir` the scan uses), keyed by the target
directory as well as the ecosystem and package name, with a 7-day TTL -- the
same scheme as the system-tool version probes. The content-addressed result
cache does not cover these registry calls, so without this layer a warm run
still re-paid them; the meta cache serves every repeat from disk with no
subprocess spawn, and two projects that share a cache directory never serve
each other's resolved licence or version.

Bundled dashboard assets (FlexSearch, nomnoml, graphre) resolve
their licence and website live from the package registry when a loose vendored
copy is scanned, preferring `pnpm show <pkg> license` and falling back to
`npm`, `yarn`, then `bun` -- the same preference chain as every JavaScript
component (see [Licence resolution](#licence-resolution)). The SBOM and the
Credits tab therefore track the real upstream licence instead of a hard-coded
copy.

## Transitive lockfile resolution

A declaration bounds a dependency set; a lockfile states it. adacovex reads
the lockfile beside a manifest, so the SBOM carries the packages the project
really installs and not only the ones it declares. The lockfile set, its
PURL types, and the version-fill rule are on
[SBOM transitive dependencies](sbom-transitive.md).

Each dialect has one reader over a table row, so a new lockfile is one row:

- **A TOML package list** (`Cargo.lock`, `poetry.lock`) -- a `[[package]]`
  block, then its `name` and `version` keys. A `[metadata]` key such as
  `lock-version` names no package.
- **An indented gem list** (`Gemfile.lock`) -- `name (version)` at four
  spaces under `specs:`. A requirement line at six spaces belongs to the gem
  above it, and a section header (`PLATFORMS`, `DEPENDENCIES`) is not a
  package.
- **A JSON object map** (`composer.lock`, `package-lock.json`,
  `packages.lock.json`, `Package.resolved`) -- the entry key, or the row's
  name key (`name`, `identity`), then the row's version key (`version`,
  `resolved`). A location key loses its `node_modules/` prefix, so a nested
  entry is its own package, and a section key (`packages`, `dependencies`,
  `description`, `state`) never becomes one.
- **A YAML package map** (`pubspec.lock`) -- a package key at two spaces,
  then its `version` key at four spaces. A section key that carries a value
  (`dart: ">=3.0.0"`) never ends with the colon, so it is never a package.
- **An Elixir term map** (`mix.lock`) -- `"name": {:hex, :name, "version"}`.
  A git or path source states no hex version, so it registers nothing.

A package the graph already holds keeps its scope: a base dependency stays
base, and the lockfile only fills a version the declaration could not state.
A licence is never read from a lockfile, because a lockfile states a version
and not a licence, so a lockfile-only component reports none until a licence
file or the registry answers.

## System dependencies

The build tools a project's files reference and that are installed on
`PATH` become `system`-scope components. The qualification rule, the
version probes, and the cache identity are on
[SBOM system dependencies](sbom-system.md).

## Test dependencies

A dependency used only by the project's tests is classified `test` (the
`adacovex:dep_scope` property value `"test"`). adacovex recognises
test-only declarations in every supported ecosystem's manifest, in addition
to the Alire `[[test-depends-on]]` sections and test project files:

| Manifest file       | Test label |
|---------------------|------------|
| `package.json`      | a dependency section whose key contains `test` (for example `testDependencies` or `devTestDependencies`); a name whose last segment starts or ends with `test` (for example `@playwright/test`, `vitest`) |
| `Cargo.toml`        | the `[dev-dependencies]` section (Cargo's test-only section); any section whose name contains `test` (for example `[target.'cfg(test)'.dependencies]`) |
| `go.mod`            | no native test-only section: the name heuristic is the signal (a module path whose last path segment starts or ends with `test`, for example `github.com/stretchr/testify`) |
| `composer.json`     | the `require-dev` section |
| `Gemfile`           | gems inside a `group :test` block (any group name containing `test`) |
| `pom.xml`           | `<dependency>` blocks whose `<scope>` is `test` |
| `pyproject.toml`    | optional-dependencies extras whose name contains `test` (for example the `test` extra); Poetry sections such as `[tool.poetry.group.test.dependencies]` |
| `Package.swift`     | dependencies declared inside a `.testTarget(...)` block |
| `requirements*.txt` | no native test section: the name heuristic is the signal |

A vendored component (for example a package under `node_modules` or
`vendor/`) is classified `test` when the project manifest that owns the
vendor directory declares it under one of these test labels, or when its
name carries the test label. The name heuristic checks the full name and
then the last segment after any `/` or `:`, so `@playwright/test`,
`test-case`, `github.com/stretchr/testify`, and `org.testng:testng` all
qualify, and it applies to lockfile-resolved names as well:
`pnpm-lock.yaml` / `package-lock.json` / `yarn.lock` entries next to an
owner `package.json`, `Cargo.lock` crate names, and `alire.lock` crates
that the manifest sets leave transitive. The e2e fixture's
`@playwright/test` is the canonical example: it stays a `devDependencies`
entry of `tests/e2e/package.json` (and a `pnpm-lock.yaml` entry) and is
classified `test` by name.

## Comparison and dogfood

The parser is measured against Anchore's syft and regression-checked against
the sibling projects on the developer machine: the comparison table, the
differences, and the sibling-project checks are on
[SBOM comparison with syft](sbom-syft.md).
