# SBOM dependency resolution

This page covers language detection, licence resolution (local manifests and the package registry), system dependencies, and test dependency classification. The output formats, usage, standard awareness, and language detection are on [The `sbom` subcommand](sbom.md).

## Language detection

For every other component -- vendored trees, `vendor/`, `node_modules`,
resources, loose source drops, and individual files inside `resources/`,
`assets/`, and `.adacovex/patches/` -- adacovex infers the language from the
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

Vendored manifest ecosystems report their licence from the local manifest:
`package.json` (`license`) for npm/pnpm, `Cargo.toml` for cargo,
`pyproject.toml` / `composer.json` for pypi / composer. A licence file
beside the manifest is also classified into an SPDX identifier when the
manifest itself carries no licence. When the local manifest and licence
file carry no licence, adacovex resolves the version, website, and licence
from the package registry as a best-effort, online fallback. The
resolver dispatches on the ecosystem (the PURL type) through a single static
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

### Go modules

A vendored Go component resolves its version and licence **offline**, from
files, and only falls back to the registry for the version. Nothing in this
path names a forge, so the same code serves a module on GitHub, GitLab,
Gitea, Codeberg, or a private mirror.

- **Version, offline.** The component's own `go.mod` states the module path
  but never the module's own version: its `require` block lists that
  module's *dependencies*, not the module itself. The version therefore
  comes from the vendor root's `modules.txt`, the manifest `go mod vendor`
  writes for every vendored module, as a `# <module> <version>` line. This
  is the only offline source of a vendored module's pinned version.
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
  requires is present and no marker it excludes is present, so a
  four-clause BSD text (which carries the three-clause marker *and* the
  advertising clause) reports **no** licence rather than the wrong one. A
  text that matches nothing -- the GPL family, for example, where the
  only-versus-or-later choice is not visible in the text -- also reports no
  licence. **A licence is never guessed.**
- **Website.** Always empty. `go list -m` has no website field, and its
  `Origin.URL` is a forge-specific VCS endpoint (`go.googlesource.com` for
  `golang.org/x/text`, a forge host for everything else), not a project home
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

The npm and pnpm rows answer for all three fields with a single `--json` call,
so each component boots node once instead of once per field -- a 3x reduction
in subprocess starts that keeps the graph build responsive on vendored
JavaScript trees. The fallback runs only when the offline read finds nothing,
so a vendored package that ships a licence never touches the network. A Go
component likewise never reaches the registry when its vendor tree carries a
`modules.txt` and a licence file, which is the normal shape of a vendored Go
tree. The
resolved licence flows into every SBOM format (CycloneDX `licenses`, SPDX
`licenseConcluded` / `licenseDeclared`, Markdown `License` column) and the
dashboard detail panel; the resolved version and website appear in the
dashboard detail panel and the `/api/deps` JSON.

The resolver caches each answer in a per-project store under the project's
result cache (the same `--cache-dir` the scan uses), keyed by the target
directory as well as the ecosystem and package name, with a 7-day TTL, the
same scheme as the system-tool version probes. The content-addressed result
cache does not cover these registry calls (each one boots node for npm/pnpm),
so without this layer a warm run still re-paid them; the meta cache makes every
repeat run serve the licence, version, and website from disk with no subprocess
spawn, and two projects that share a cache directory never serve each other's
resolved licence or version.

Bundled dashboard assets (FlexSearch, nomnoml, graphre) resolve
their licence and website live from the package registry when a loose vendored
copy is scanned, preferring `pnpm show <pkg> license` and falling back to
`npm`, `yarn`, then `bun` -- the same preference chain as every JavaScript
component (see [Licence resolution](#licence-resolution)). The SBOM and the
Credits tab therefore track the real upstream licence instead of a hard-coded
copy.

## System dependencies

`Discover_System_Dev_Deps` scans the project's build and dev files (Makefiles,
shell scripts, Python tools, CI workflows, GPR files, Ada sources) for a
curated set of known system binaries, then keeps only the tools that are
installed on `PATH`. Each becomes a `system`-scope component of the root with
a `pkg:generic/<name>` PURL, a resolved `version`, and no external link or
licence -- by design adacovex provisions only the version for system tools
and never guesses a repository or licence for them.

The table is deny-by-default and grouped by category (build drivers, language
implementations and package managers, VCS, documentation tooling, CI and
container plumbing, performance engineering). A tool lands in the SBOM only
when (a) its exact lowercase name appears as a whole word in one of the
scanned build files, and (b) it is installed on `PATH`; whole-word matching
keeps "makefile" from registering "make". The table stores only the name and
category: the version-probe flag is inferred at run time by trying
`--version`, then `-v`, then the `version` subcommand, and taking the first
flag that yields a version token -- so a subcommand-only tool (go, fossil,
git-lfs) needs no special-cased column and a misconfigured entry cannot
exist.

Resolved versions are never hardcoded. Each probe result is cached per
machine (outside the result cache) together with the identity of the
binary it was probed from: the PATH-resolved executable path plus its size
and mtime. Before a cached version is served, adacovex re-resolves the
tool on `PATH` and compares the binary identity -- an upgraded, replaced,
or PATH-shadowed binary re-probes on the next run, and an unchanged
toolchain serves from cache with no subprocess spawns. A version in the
SBOM therefore always describes the binary that is installed now, not the
binary that happened to be installed when the cache was filled.

`system` is a first-class dependency scope, distinct from `base`, `dev`,
`transitive`, `vendored`, and `test`; the dashboard gives it its own filter
checkbox, badge colour, and legend entry, and the SBOM lists it under
`system` scope. The dashboard marks these with a `system` scope badge and a
note in the detail panel.

The result shows up in the dashboard Dependency tab (per-dependency detail
popup) and in every SBOM renderer: CycloneDX `components[].language`,
SPDX/JSON `adacovex:language` property, and the Markdown table's
`Language` column.

Tools that are really **language packages** are never registered as system
tools. The root project's Python requirements (`requirements*.txt`, for
example `sphinx` and `myst-parser`) register as `dev`-scope `pkg:pypi/*`
components with the language set to Python. A version pinned in the
requirements line wins; otherwise the package registry answers
(`pip index versions <pkg>`) when `pip` is installed and online. A missing
registry or a failing resolve keeps the name-only entry -- no version or
licence is ever guessed.

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
name carries the test label. The name heuristic works across every
supported ecosystem -- not just npm: it checks the full name and then the
last segment after any `/` or `:`, so `@playwright/test`, `test-case`,
`github.com/stretchr/testify` and `org.testng:testng` are all
test-labelled. The heuristic also applies to **lockfile-resolved names**:
`pnpm-lock.yaml` / `package-lock.json` / `yarn.lock` entries next to an
owner `package.json`, `Cargo.lock` crate names, and `alire.lock` crates
that the manifest sets leave transitive. The e2e fixture's
`@playwright/test` is the canonical example: it stays a `devDependencies`
entry of `tests/e2e/package.json` (and a `pnpm-lock.yaml` entry) and is
classified `test` by name.
