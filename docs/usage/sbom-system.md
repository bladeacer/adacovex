# SBOM system dependencies

adacovex reports the build tools a project's dev-facing files reference
and that are installed on `PATH` as `system`-scope components. This page
covers which tools qualify, how their versions are probed, and how the
scope is presented. The language manifests, licence resolution, and test
classification are on
[SBOM dependency resolution](sbom-resolution.md).

## Which tools qualify

`Discover_System_Dev_Deps` scans the project's dev-facing build files
(Makefile variants, build manifests, shell scripts, GPR files, CI
workflows, and TOML files) for a curated set of known system binaries,
then keeps only the tools that are installed on `PATH`. Each becomes a
`system`-scope component of the root with a `pkg:generic/<name>` PURL, a
resolved `version`, and no licence, because adacovex never guesses one.

Source files and prose are never scanned, because an identifier or a
keyword collides with a tool name. A generated build tree is never
scanned either: it records the developer's environment, `PATH` included,
so reading one invents tools the project never invokes. The scan skips a
tree by its conventional name (`build`, `builddir`, `target`, `dist`,
`out`, `coverage`) and by the build-system state inside it
(`build.ninja`, `meson-info`, `CMakeCache.txt`, `compile_commands.json`).

The table is deny-by-default and grouped by category (build drivers,
language implementations and package managers, VCS, documentation
tooling, CI and container plumbing, performance engineering). A tool
lands in the SBOM only when (a) its exact lowercase name appears as a
whole word in one of the scanned build files, and (b) it is installed on
`PATH`; whole-word matching keeps "makefile" from registering "make".
Comment text is never scanned, so a tool that a build file names only in
a comment is not a dependency. A leading `#!` shebang stays command
text, because a shell script does depend on its interpreter.

The table is closed by decision. A tool that is absent from it cannot
appear however the project uses it, and sphinx-build is the deliberate
example: the manual's Sphinx build is the pypi package sphinx, so it
registers under its language ecosystem. Add a table entry when a real
build tool is missing; the fixture projects pin every build tool the
list must cover.
The table stores only the name and category: the version-probe flag is
inferred at run time by trying `--version`, then `-v`, then the
`version` subcommand, and taking the first flag that yields a version
token -- so a subcommand-only tool (go, fossil, git-lfs) needs no
special-cased column and a misconfigured entry cannot exist.

`adacovex` and its `covex` alias take one exception to rule (b): the
running binary is the dependency, so a reference registers adacovex from
the reference alone, at the running binary's version. Three rules order
it: the audited project being adacovex itself keeps it the root; a
manifest declaration keeps its own scope (`base` from `alire.toml`, `dev`
from `alire-dev.toml`); otherwise the installation method decides, as
`adacovex status` reports it -- a source build is `dev`, a binary
installed outside a project is `system`.

## Version probes and caching

Resolved versions are never hardcoded. Each probe result is cached per
machine (outside the result cache) together with the identity of the
binary it was probed from: the PATH-resolved executable path plus its
size and mtime. A cached version is served only after adacovex re-resolves
the tool on `PATH` and compares that identity, so an upgraded, replaced,
or PATH-shadowed binary re-probes on the next run while an unchanged
toolchain serves from cache with no subprocess spawn. Every version in
the SBOM describes the binary that is installed now.

## Scope and language

`system` is a first-class dependency scope, distinct from `base`, `dev`,
`transitive`, `vendored`, and `test`; the dashboard gives it its own
filter checkbox, badge colour, and legend entry, and the SBOM lists it
under `system` scope.

The language shows up in the dashboard Dependency tab (per-dependency
detail popup) and in every SBOM renderer: CycloneDX
`components[].language`, SPDX/JSON `adacovex:language` property, and the
Markdown table's `Language` column.

Tools that are really **language packages** are never registered as
system tools; they register as language components instead. The root
project's own manifests (`package.json`, `go.mod`, `requirements*.txt`)
register the same way, and every read of them is structural -- the rules
are on
[Root project declarations](sbom.md#root-project-declarations).

A package and a tool can share a name: the `cmake` crate and the `cmake`
binary are different dependencies. When a lockfile has already resolved
the package, the component keeps that identity -- its versioned purl and
its own scope -- and the tool reference adds no `system` fact to it. So
the row reads `pkg:cargo/cmake@0.1.58` in `transitive` scope, and no row
claims a generic purl for a resolved package.
