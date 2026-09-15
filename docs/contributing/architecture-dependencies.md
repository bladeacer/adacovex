# Architecture: dependency management and the toolchain

adacovex keeps its publishing manifest dependency-free and resolves its proof
toolchain at run time. This page records the dependency-management
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
  `make prove`, `make doc`, and `make fmt`. The `prove` subcommand reads the
  gnatprove pin from it and deploys that exact version into
  `~/.adacovex/toolchain/` via `alr -n get` (reused after the first run);
  `make doc`/`make fmt` run their tools through `alr exec`.

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
   gnatprove binary crate is deployed standalone into `~/.adacovex/toolchain/`
   via `alr -n get gnatprove=<version>` and executed directly (the version-set
   expression, for example `^16.1.0`, is reduced to the bare version alr
   accepts). This isolates the proof run from the target's other dev-manifest
   tools and never swaps manifests. A manifest pin always wins. When the pinned
   version cannot be deployed, the run fails instead of falling back.
2. **Global version pin**: the `ADACOVEX_GNATPROVE_VERSION` environment
   variable or the `[prove] gnatprove-version` key in
   `~/.adacovex/adacovex.toml`, deployed standalone via
   `alr -n get gnatprove=<version>`. It uses the same never-fall-back
   semantics. It is folded into the proof result-cache identity.
3. **`$PATH`**: a `gnatprove` already installed (for example `alr install gnatprove`).
4. **Cached toolchain**: `~/.adacovex/toolchain/`. The download layout
   (`<toolchain>/bin/gnatprove`) is used. A previously `alr get`-deployed
   `gnatprove_*/` crate is also used.
5. **Download**: last-resort platform toolchain bundle.

Effective order: **manifest pin > global pin (config/env) > PATH > cache >
download**. If a project manifest declares `gnatprove` but `alr` is missing,
install Alire first. The remaining fallbacks then apply.

The `make doc` / `make fmt` targets still swap `alire-dev.toml` over
`alire.toml` for the duration of `gnatdoc` / `gnatformat` (the `_dev_cmd`
Makefile recipe backs up `alire.toml` / `alire.lock` / `alire/`, swaps, runs,
and restores via a `trap`). `prove` does not use that swap. It deploys only
the single gnatprove crate.

The assessment and SBOM pipeline always scans the publishing `alire.toml`, so
dev-only tool declarations never leak into dependency graphs or SBOMs.

### System-tool dev dependencies (SBOM)

Beyond the Alire graph, `Discover_System_Dev_Deps` adds the system binaries a project interacts with at development time (`python3`, `git`, `gnatprove`, `make`, and more) as `Scope_Dev` SBOM components. It scans the project's dev-facing files (Makefile variants, `.sh` / `.py` / `.gpr` / `.yml` / `.toml` / `.ads` / `.adb`) for a curated toolchain list and registers every referenced tool that is actually installed on `$PATH` under a `pkg:generic/<tool>` purl. Tools referenced nowhere in the project, or referenced but not installed, are skipped. A Makefile at the project root implies `make`.

The scan runs after the cached manifest graph is resolved (so cache hits and misses agree). Each registered tool's version is probed by running `--version` (or a tool-specific subcommand such as fossil's `version`) and extracting the version token, so the SBOM records the installed version. A probe that fails or prints no digit token leaves the version empty. The source file declaring the `System_Tools` table is skipped by the scan.

Otherwise, every installed tool on the list can be registered as a self-reference.

### Vendored components and test-labelled dependencies (SBOM)

`Discover_Generic_Vendored` walks the target tree for vendor roots
(`node_modules`, `vendor`, `third_party`, and the other recognised names).
Each directory inside a vendor root that carries an ecosystem manifest
(`package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `composer.json`,
`Gemfile`, `pom.xml`, `Package.swift`, `requirements*.txt`) becomes one
component with its ecosystem purl (`pkg:npm/...`, `pkg:cargo/...`, and
more). Its scope defaults to `vendored`.

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
