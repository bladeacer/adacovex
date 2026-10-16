# adacovex 1.62.0

Date: _2026-10-13_

Version bumped 1.61.0 -> 1.62.0.

## Changes

### C1: The test suites run with the network unplugged

`ADACOVEX_OFFLINE` gates the ecosystem-metadata resolver, so a gate run
spawns no package-registry CLI and reads no metadata cache. The native
runner and the end-to-end `run()` helper set it for every child process,
and three new checks pin the offline shape of the resolver.

An execve trace of the whole native suite now shows zero registry-CLI
spawns. `just check` no longer refreshes a crate index mid-run, so the
`git-credential-oauth` helper can no longer open a browser while a gate
runs.

### C2: Every supported manifest parses structurally

The manifest readers matched substrings: `File_Quoted_Value` searched a
whole file for the first `"key"=` or `"key":` pair, so a key of another
section, a commented line, or a key inside a string value could answer.
It is deleted. `Json_Top_Value` tracks brace depth and string state,
`Toml_Section_Value` reads only its own `[section]`, and
`Collect_Json_Section_Names` collects only the keys directly inside a
root-object section.

`Pnpm_Importer_Version` walks pnpm-lock.yaml by indentation, and the new
`Collect_Go_Requires` reads only require directives, so the contents of
a replace or exclude block and a commented-out require never register.
The curated tool scan still matches whole words on both sides of a
match, and `air` joins the table, so a project that references it from
its Makefiles or its air config registers it when it is installed.

### C3: The root project's npm and Go declarations register

A project that keeps no install tree in the repository now reports the
dependencies its own manifests declare. `package.json` `dependencies`
register as base scope and `devDependencies` as dev scope when no
`node_modules` tree exists, and the resolved version comes from the
root importer blocks of `pnpm-lock.yaml` when the lockfile is there.

`go.mod` registers as well: a direct require is base scope, a
`// indirect` require is transitive, and a test-named module such as
`github.com/stretchr/testify` keeps the test label. Each module carries
the version go.mod states under a `pkg:golang/<module>@<version>` purl.
An installed tree stays authoritative, so a package or module it
already resolved is never registered twice.

### C4: adacovex registers as a dependency of the projects it audits

A project that references `adacovex` or its `covex` alias from a build
file, a workflow, or a manifest now carries adacovex in its own
dependency graph. The running binary is the dependency, so the
reference alone registers it: under the canonical name `adacovex`, the
bundled version, and a `pkg:generic/adacovex` purl. A reference to the
`covex` alias collapses into that one component.

Three rules order the classification. A project that is adacovex itself
never carries itself as a component. A manifest that declares
`adacovex` or `covex` keeps its own scope, so a publishing manifest
stays `base` and a dev manifest stays `dev`. Otherwise the installation
method of the running binary decides: a source build registers as
`dev`, an Alire global install or a binary on `PATH` registers as
`system`.

The rules are pinned in both directions by fixtures, so a
parsing regression fails a gate instead of a manual run.

### C5: `status` reports how adacovex is installed

`adacovex status` prints the installation method of the running binary
and the path it was invoked from: `source-checkout` for a binary built
inside an adacovex source tree, `alire-global` for a binary under a
global `alr install` prefix, and `on-path` for every other binary. The
JSON export carries `install_method` and `install_path`, and the
metrics output carries the same two keys, so the three outputs never
drift. The report uses the same rule C4 uses in the dependency graph,
so the two answers always agree.

### C6: The dashboard serves server info and a health probe

Two new routes answer for the running server instead of the assessment.
`GET /health` is the liveness probe for scripts: it answers `200 OK` with
`{"status": "ok"}`. `GET /api/info` reports the bundled version, the audited
target, the selected standard, the bound port, the worker count, the
uptime, the result-cache counters, the assessment wall time, and the
request counters.

The counters live in one protected store that the worker tasks share, so
concurrent requests never race on an increment. Every route carries a
served count and a 404 count, the `*` entry names the bucket of every path
the server does not dispatch on, and the keep-alive count records the
connections that stayed open. The payload is a snapshot, so no lock is
held while a socket write blocks.

`/api/metrics` keeps its assessment shape: the server's own state moved to
`/api/info` instead of growing the metrics payload. Both new routes join
the `/api/endpoints` catalog, so the API playground lists them with the
rest, and both land with native routing, counter, and payload checks plus
end-to-end checks against a live server.

## Fixes

### H1: An installed package's own subpackages and source trees are no longer components

The vendored walk descended two levels and componentised every
directory it reached, so one installed package reported its bundled
`v4`, `locales`, `src`, `lib`, and `dist` directories as five separate
dependencies of the project that uses it.

A level-2 directory now becomes a component only when it carries its
own ecosystem manifest and its parent carries none. Such a parent is a
container -- an npm scope, a composer vendor name, or a Go import-path
host -- and the packages below it are real dependencies. Anything else
at that depth belongs to the package above it and stays out of the
graph.

## Test Suite

1949 tests across 28 categories, up from 1864. Forty earlier checks in
this release cover the structural readers, the package-root rule, and the
root npm and Go declarations. Fifteen more pin adacovex as a
dependency in both directions, and the new `Install method` category
holds 23 checks for the classifier, the scope rule, and the filesystem
walk behind them. The `Server routing` category grows to 180 checks: the
two new routes and their near misses, the `Route_Path` round trip over
every route kind, the protected counter store, and the `/api/info`
payload.

`just test` runs the native suite, `just cli-e2e` runs 80 end-to-end
checks including two new component-set shapes (a pnpm workspace and a
Go module) and three checks against the live `/health` and `/api/info`
endpoints, and `just tools-check` runs the 174-test tools suite.

## Proof Results

**Platinum**, 0 unproved, 0 justified, **1048 of 1048 VCs across 72
analysed units** under gnatprove 16.1.0 at `--level=4`. The count grows
by 26 checks and two units: the new `Adacovex.Install` classifier is
proved, from its machine token over the prefix rules and the scope rule
to the index arithmetic behind them, and C6's two route branches and
its `Route_Path` mapping add two checks to the proved `Route` surface.
No existing unit lost a check. The parser bodies this release adds sit
in the manifest package's default-off body, which contributes no
verification conditions, and C6's counter store and `/api/info`
renderer sit in the server package's default-off surface for the same
reason.

## Traceability

No new HLR record enters this release, and no tag is added or removed.
The dependency-graph parsing work extends `HLR-MANIFEST` (Alire manifest
and dependency-graph parsing) and `HLR-SBOM` (proof-aware SBOM
generation), both on record for the graph and its output. The new
`Adacovex.Install` package carries `HLR-MANIFEST`: it decides how a
project's reference to adacovex is classified. The status report adds
no requirement: it reports state and never assesses it.

The hermetic
suite changes no requirement: it changes the tests that gate the tree.

The packages changed by this release, and the tags already on record
that cover them: the manifest parsers and the dependency graph
(`HLR-MANIFEST`), the SBOM they feed (`HLR-SBOM`), the installation
classification they apply (`HLR-MANIFEST`), the dashboard server routes
and its API (`HLR-SERVER`), and the task gates that run the suites
(`HLR-ARCH`).
