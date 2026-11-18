# Architecture: dependency management and the toolkit

adacovex keeps its publishing manifest dependency-free and resolves its proof
toolkit at run time. This page records the dependency-management
decisions: the Alire manifests, the gnatprove resolution order, and the
system and vendored tools the SBOM records. The companion pages are
[the architecture decisions](architecture.md),
[verification and proof patches](architecture-verification.md), and
[outputs, pipeline, and delivery](architecture-outputs.md).

## Dependency Management: Alire

adacovex uses [Alire](https://alire.ada.dev/) as its packaging and delivery mechanism. The publishing manifest `alire.toml` declares **zero dependencies**. It declares no libraries beyond the GNAT runtime. It declares no tool dependencies.

In particular `gnatprove` is *not* a declared dependency. adacovex analyses `gnatprove.out` files produced externally. The `prove` subcommand resolves a gnatprove executable at run time (per-project manifest, `$PATH`, cached toolchain, or download). Development-only tools (`gnatprove`, `gnatdoc_bin`, `gnatformat_bin`) are declared in `alire-dev.toml`, which is never published to the Alire community index.

### Manifest distinction (`alire.toml` vs `alire-dev.toml`)

- **`alire.toml`**: The clean publishing manifest. Declares no dependencies at
  all, so `alr install covex` (or `alr build` from source) pulls nothing beyond
  the binary and the GNAT compiler. Used for SBOM generation and dependency
  graph scanning.
- **`alire-dev.toml`**: The development manifest. Extends `alire.toml` with
  dev-only tools (`gnatprove`, `gnatdoc_bin`, `gnatformat_bin`) needed for
  `just prove`, `just doc`, and `just fmt`. The `prove` subcommand reads the
  gnatprove pin from it and deploys that exact version into
  `<data>/toolkit/` via `alr -n get` (reused after the first run);
  `just doc`/`just fmt` run their tools through `alr exec`.

When both files exist, `Build_Dependency_Graph` reads **both**: a dependency
declared in `alire.toml` is classified `Scope_Base` (explicit/clean dep) and
one declared only in `alire-dev.toml` is `Scope_Dev`. The scope is surfaced in
the SBOM as the `adacovex:dep_scope` property (`base` / `dev` / `transitive` /
`vendored`), so it is always clear which file a dependency came from.
`alire-dev.toml` is also consulted for gnatprove detection
(`Manifest_Declares_GNATprove` checks both manifests).

### GNATprove toolchain resolution (`prove` subcommand)

adacovex declares `gnatprove` only in its own `alire-dev.toml` (keeping the
publishing `alire.toml` clean). The `prove` subcommand resolves the `gnatprove`
executable in this order:

1. **Per-project manifest (authoritative)**: if `<target>/alire.toml` /
   `<target>/alire-dev.toml` declares a `gnatprove` dependency, the pinned
   gnatprove binary crate is deployed standalone into `<data>/toolkit/`
   via `alr -n get gnatprove=<version>` and executed directly (the version-set
   expression, for example `^16.1.0`, is reduced to the bare version alr
   accepts). This isolates the proof run from the target's other dev-manifest
   tools and never swaps manifests. A manifest pin always wins. When the pinned
   version cannot be deployed, the run fails instead of falling back.
2. **Global version pin**: the `ADACOVEX_GNATPROVE_VERSION` environment
   variable or the `[prove] gnatprove-version` key in
   the global configuration file, deployed standalone via
   `alr -n get gnatprove=<version>`. It uses the same never-fall-back
   semantics. It is folded into the proof result-cache identity.
3. **`$PATH`**: a `gnatprove` already installed (for example `alr install gnatprove`).
4. **Cached toolkit**: `<data>/toolkit/`. The download layout
   (`<toolkit>/bin/gnatprove`) is used. A previously `alr get`-deployed
   `gnatprove_*/` crate is also used.
5. **Download**: last-resort platform toolkit bundle.

Effective order: **manifest pin > global pin (config/env) > PATH > cache >
download**. If a project manifest declares `gnatprove` but `alr` is missing,
install Alire first. The remaining fallbacks then apply.

The `just doc` / `just fmt` targets still swap `alire-dev.toml` over
`alire.toml` for the duration of `gnatdoc` / `gnatformat` (the `_dev_cmd`
Makefile recipe backs up `alire.toml` / `alire.lock` / `alire/`, swaps, runs,
and restores via a `trap`). `prove` does not use that swap. It deploys only
the single gnatprove crate.

The assessment and SBOM pipeline always scans the publishing `alire.toml`, so
dev-only tool declarations never leak into dependency graphs or SBOMs.

### System-tool dev dependencies (SBOM)

Beyond the Alire graph, `Discover_System_Dev_Deps` adds the system binaries a project interacts with at development time (`python3`, `git`, `gnatprove`, `make`, and more) as `Scope_System` SBOM components. It scans the project's dev-facing files (Makefile variants, build manifests, `.sh` / `.gpr` / `.yml` / `.toml`) for a curated toolkit list and registers every referenced tool that is actually installed on `$PATH` under a `pkg:generic/<tool>` purl. Tools referenced nowhere in the project, or referenced but not installed, are skipped. A Makefile at the project root implies `make`.

`Skip_Scan_Dir` owns the directory decision: VCS metadata, test suites, tool configuration, and generated build trees are never descended into. A build tree is recognised by its conventional name (`build`, `builddir`, `target`, `dist`, `out`, `coverage`) or by the build-system state it holds (`build.ninja`, `meson-info`, `CMakeCache.txt`, `compile_commands.json`). `Source_Tree_Hash` uses the same predicate, so the tool-set cache key covers exactly the files the scan reads.

The scan runs after the cached manifest graph is resolved (so cache hits and misses agree). Each registered tool's version is probed by running `--version` (or a tool-specific subcommand such as fossil's `version`) and extracting the version token, so the SBOM records the installed version. A probe that fails or prints no digit token leaves the version empty. The source file declaring the `System_Tools` table is skipped by the scan.

`adacovex` and `covex` are the two table entries that never take the PATH probe: the running binary is the dependency. The word scan records the reference, and a dedicated pass in `Discover_System_Dev_Deps` registers `adacovex` from it, unless the graph is adacovex's own (a project is never a component of its own graph) or a manifest already declared `adacovex` / `covex` and keeps its scope. `Adacovex.Install` owns the classification: `Detect` resolves the method of the running binary (`Self_Path` for the path, `Is_Source_Checkout` for the `src/adacovex.ads` walk, and the `~/.alire` / `~/.local/bin` prefix rules in `Classify`), and `Dependency_Scope` maps a source checkout to `Scope_Dev` and an install outside a project to `Scope_System`. `adacovex status` reports the same method and path.

Otherwise, every installed tool on the list can be registered as a self-reference.

### Root project manifests (SBOM)

`Build_Dependency_Graph` also reads the root project's own manifests, and
it does so after the vendored walk, so an installed tree always wins.
`Register_Root_Npm_Deps` registers the `package.json` dependency sections
when no `node_modules` tree exists, and `Register_Root_Go_Deps`
registers the `go.mod` require directives when no vendor tree resolved
the modules. `Register_Root_Python_Deps` registers `requirements*.txt`
the same way it always has. `Register_Root_Manifest_Deps` covers the
remaining ecosystems through one table: each row names the manifest (a
fixed filename or a package-named suffix), the read dialect, the base
and dev sections, the PURL type, and the language, so a new language is
a row rather than a code path. Every read is structural:
`Collect_Json_Section_Names` tracks brace depth and string state,
`Collect_Go_Requires` tracks require directives and their blocks, and
`Pnpm_Importer_Version` walks the lockfile by indentation. The
`Register_Root_Manifest_Deps` collectors match a TOML key inside its
section header, a YAML key at its block's own indentation (a nested map
is that entry's metadata), and a comma list entry up to its version
constraint, extended by an indented continuation line.

### Vendored components and test-labelled dependencies (SBOM)

`Discover_Generic_Vendored` walks the target tree for vendor roots
(`node_modules`, `vendor`, `third_party`, and the other recognised names).
Each directory inside a vendor root that carries an ecosystem manifest
becomes one component with its ecosystem purl (`pkg:npm/...`,
`pkg:cargo/...`, and more). Its scope defaults to `vendored`.
`Read_Vendor_Manifest` owns the ecosystem table: one row per language
(manifest filename or package-named suffix, PURL type, registry token,
primary language, and the name, version, and licence keys). The table
covers the union of adacovex's own ecosystems and the languages syft
catalogues from a source tree, plus Ada.

Three readers answer for the dialects a row can name: the JSON, TOML,
and XML readers, plus `Expr_Value`, which reads a plain `Key: value` or
`Key = value` line (pubspec, DESCRIPTION, cabal, opam, mix.exs,
rebar.config, Gradle, gemspec, rockspec, conanfile). An ecosystem whose
manifest states its licence in a non-SPDX vocabulary (R's free-form
`License:` field, CPAN's `perl_5`) leaves the field empty, so a licence
file beside the manifest classifies instead: a licence is never guessed.

Only two directory shapes become components. A level-1 child of the
vendor root is one (`node_modules/zod`). A level-2 child is one only
when it carries its own ecosystem manifest and its parent carries none:
the parent is then a container -- an npm scope
(`node_modules/@scope/pkg`), a composer vendor name
(`vendor/phpunit/phpunit`), or a Go import-path host
(`vendor/gopkg.in/yaml.v3`).

Every other level-2 directory is a subpackage or a source tree of the
package above it (`zod/v4`, `zod/src`, `parse5/dist`) and never becomes
a component: a package bundles its own subpackages, and none of them is
a dependency of the project. Hidden directories (`.pnpm`, the `.bin`
shims, and tool caches such as `.vite`) are never descended into.

A component is classified `test` when the project manifest that owns the
vendor root declares it under a test-only label:

- `package.json` sections whose key contains `test` (for example
  `testDependencies`);
- Cargo `[dev-dependencies]` (Cargo's native test-only section) and any
  section containing `test`;
- composer `require-dev`;
- Gemfile `group :test` blocks;
- `pom.xml` dependencies whose `<scope>` is `test`;
- `pyproject.toml` test extras and Poetry `[tool.poetry.group.test.*]`
  sections;
- `Package.swift` dependencies declared inside a `.testTarget(...)` block.

The **name heuristic** is the fallback for every ecosystem. A component
whose name starts or ends with the literal word `test` is test-labelled.
The check covers the full name and then the last segment after any `/` or
`:`, so `@playwright/test`, `test-case`, `github.com/stretchr/testify` and
`org.testng:testng` all match. Ecosystems without a native test-only
section (`go.mod`, `requirements*.txt`) rely on this heuristic.

The heuristic also applies to **lockfile-resolved names**:
`pnpm-lock.yaml` / `package-lock.json` / `yarn.lock` entries next to an
owner `package.json`, `Cargo.lock` crate names, and `alire.lock` crates
that the manifest sets leave transitive.

The scope is surfaced as the SBOM `adacovex:dep_scope` property (`test`)
and in the dashboard dependency badges, scope filter, legend, and rings.
The Alire-side `[[test-depends-on]]` sections and test project files are
the other source of `test` scope; see the
[SBOM reference](../usage/sbom-resolution.md#test-dependencies).
