# SBOM comparison with syft

[syft](https://github.com/anchore/syft) is an Anchore SBOM generator
(Apache-2.0) that catalogues software from a container image, a directory, or
an archive. It is the reference point this page measures adacovex against.
syft is never a dependency of adacovex: the comparison runs offline, and
`adacovex sbom` never calls syft.

## How the comparison was made

The numbers below come from one run on 2026-11-14 on the development machine.
syft was built from a source checkout (`go build ./cmd/syft`) and run as
`syft dir:<path> -o json`. adacovex was run as
`adacovex sbom --format=cyclonedx-json`, and both JSON documents were counted
by one script. A component counts as **versioned** when it carries a version
and as **licensed** when it carries at least one licence entry.

The machine had `.venv` installed for the offline manual and the `obj/` test
fixtures present, which matters for the result (see the findings below).

| Project | syft components | Versioned | Licensed | adacovex components | Versioned | Licensed |
|---------|-----------------|-----------|----------|---------------------|-----------|----------|
| adacovex self | 63 | 56 | 23 | 25 | 22 | 5 |
| yams (C, Meson) | 0 | 0 | 0 | 2 | 2 | 0 |
| Ada_CRDT (Ada) | 18 | 18 | 0 | 16 | 12 | 4 |

syft's 63 components on the adacovex tree split by type: 33 python, 12
github-action, 7 go-module, 5 npm, 4 java-archive, and 2 rust-crate.
adacovex's 25 split by PURL type: 18 `pkg:generic` (system tools), 3
`pkg:alire`, 3 `pkg:pypi`, and 1 `pkg:npm`.

## Findings

Where the difference comes from, in order of size:

- **Installed environments.** syft reads `dist-info` metadata from
  `.venv/lib/python3.13/site-packages` and reports the whole installed Sphinx
  closure, 26 components of the 33 python entries. adacovex treats
  `requirements.txt` as the declaration and does not read an installed
  environment, so it reports the three declared packages.
- **Build and test fixtures.** syft parses `obj/sbom_*/go.mod`,
  `Cargo.lock`, and `pom.xml` files that adacovex's own test suite writes
  there: 13 components of the 63. adacovex skips `obj` by design, because
  generated output is not a project input.
- **Workflow action usage.** syft's `github-action` cataloger lists the 12
  `uses:` actions across `.github/workflows`. adacovex has no action
  cataloger, so a workflow action is not a component.
- **System tools.** Only adacovex reports them: 18 on the self tree, 8 on
  Ada_CRDT, and 2 on yams. syft has no concept of a system-tool dependency
  for a directory scan, so `make`, `ninja`, and `git` never appear.
- **The Ada ecosystem.** syft has no Alire or GPR cataloger. Ada_CRDT's 18
  components are all workflow actions, and its `alire.lock` crate graph is
  invisible to syft. adacovex resolves 4 `pkg:alire` and 1 `pkg:gpr`
  component there.
- **A C tree with no package manifest.** Neither tool finds a package in
  yams, which carries no ecosystem manifest. adacovex still reports the build
  tools the Makefile uses.

The two tools therefore agree on one thing: a declared package set is what an
SBOM should carry. They disagree on what counts as declared, because syft also
inventories installed environments, generated fixtures, and CI action usage.

## Gaps worth closing

These gaps fit the zero-dependency rule, because each one is a file parse:

- **Workflow action usage.** `uses: owner/action@ref` in
  `.github/workflows/*.yml` is a manifest line, and a workflow action is a
  real build-time dependency of a project that runs CI. The parse is a line
  scan with no new dependency. The v1.71.0 item decides whether an action is
  a component of its own scope or a `dev` dependency.
- **Dev-dependency inclusion.** syft reads `devDependencies` only when asked
  (`javascript.include-dev-dependencies: false` by default). adacovex reports
  test-labelled dependencies as a first-class `test` scope, which is the
  richer answer for the standards this tool serves.
- **Lockfile-resolved licence.** A crate or module that only a lockfile
  names has no sibling licence file, so adacovex leaves the licence empty
  where syft reads one from an installed copy. Registry licence resolution
  covers the declared set; the lockfile-only set stays a documented gap.

## Gaps rejected

- **Installed-environment cataloguing.** Reading `.venv` or `site-packages`
  would make the SBOM describe one machine instead of the project, and it
  would report transitive packages the project never declared. The
  `requirements.txt` declaration stays the source of truth.
- **Generated trees.** `obj/`, `build/`, and `dist/` hold outputs. Cataloguing
  them would make the SBOM depend on what a previous build left behind.
- **Container and image sources.** adacovex audits source, not images.

## Dogfood projects

The parser is regression-checked against the sibling projects on the
developer machine: `../polars` (Cargo workspace), `../playwright` (npm
workspace), `../opencv` (CMake tree with vendored 3rdparty sources),
`../lccst` (pnpm workspace with a vendored `node_modules` tree), `../numpy`
(meson Python project), and `../yams` (meson C project).

`tests/e2e/cli_flags.py` runs `sbom` over every project that is present. It
checks the component table: known scopes, no duplicate component, no invented
licence or source link on a system row, and no component from an ecosystem
the project does not declare. A missing sibling is skipped, so a clean clone
and CI stay green.

yams also pins the generated-tree rule: its Meson build tree records the
developer's `PATH`, so a scan that read the tree listed `cargo` and `go` for a
C project. The check fails if either name appears again.
