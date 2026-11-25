# SBOM comparison with syft

[syft](https://github.com/anchore/syft) is an Anchore SBOM generator
(Apache-2.0) that catalogues software from a container image, a directory, or
an archive. It is the reference point this page measures adacovex against.
syft is never a dependency of adacovex: the comparison runs offline, and
`adacovex sbom` never calls syft.

## How the comparison was made

The syft column comes from one run on 2026-11-14 on the development machine:
syft was built from a source checkout (`go build ./cmd/syft`) and run as
`syft dir:<path> -o json`. The adacovex column was re-measured on 2026-11-25
with `adacovex sbom --format=cyclonedx-json`, because the workflow-action
cataloguer landed between the two runs. One script counted both JSON
documents. A component counts as **versioned** when it carries a version and
as **licensed** when it carries at least one licence entry.

The machine had `.venv` installed for the offline manual and the `obj/` test
fixtures present, which matters for the result (see the findings below).

| Project | syft components | Versioned | Licensed | adacovex components | Versioned | Licensed |
|---------|-----------------|-----------|----------|---------------------|-----------|----------|
| adacovex self | 63 | 56 | 23 | 30 | 27 | 5 |
| yams (C, Meson) | 0 | 0 | 0 | 3 | 3 | 0 |
| Ada_CRDT (Ada) | 18 | 18 | 0 | 19 | 15 | 4 |

syft's 63 components on the adacovex tree split by type: 33 python, 12
github-action, 7 go-module, 5 npm, 4 java-archive, and 2 rust-crate.
adacovex's 30 split by PURL type: 17 `pkg:generic` (system tools), 6
`pkg:github` (workflow actions), 3 `pkg:alire`, 3 `pkg:pypi`, and 1
`pkg:npm`.

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
- **Workflow action usage.** Both tools read the `uses:` lines, so this group
  is no longer a gap: adacovex reports 6 dev-scope `pkg:github` components on
  the self tree and syft listed 12 at its run. An action that the workflows
  reference more than once appears once, because the graph keeps one node per
  name.
- **System tools.** Only adacovex reports them: 17 on the self tree, 7 on
  Ada_CRDT, and 3 on yams. syft has no concept of a system-tool dependency
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

## Language coverage

The ecosystems adacovex reads are the **union** of the languages its own
parser resolves and the ecosystems syft catalogues **from a package
manifest in a source tree**: npm, cargo, go, pypi (pyproject, setup.cfg,
requirements), composer, cpan, gem (Gemfile and gemspec), maven (pom and
the Gradle Groovy and Kotlin DSL), swift and CocoaPods, pub, nuget, hex
(Elixir and Erlang), cran, conan (python and text), luarocks, opam, and
hackage -- plus Ada, which syft does not resolve at all. The v1.71.0 SBOM
depth work brought every one of them into the ecosystem table, so an
ecosystem is a table row rather than a code path.

The table is the manifest-to-language mapping on
[the SBOM page](sbom.md#manifest-declared-ecosystems). The coverage rule
is the same for both tools: a declared package set is what an SBOM
carries, so a directory that states its packages in its own manifest
becomes a component set, and a directory that states none does not.

Three groups of syft cataloguers stay out of scope, because none of them
reads a package declaration. The OS package managers (apk, dpkg, rpm,
pacman, portage, brew) inventory an **installed machine**, the binary
cataloguers classify an **artefact**, and the nix, terraform, wordpress,
and container-image cataloguers read a **store, a provider lock, or an
image** rather than the project's own package set. adacovex audits
source, and a language whose packages are not declared in a manifest has
nothing for it to read.

The transitive set reaches the SBOM the same way for both tools. syft walks
an installed environment, and adacovex reads the **lockfile**, which states
the resolved set without describing a machine: Cargo.lock, poetry.lock,
Gemfile.lock, composer.lock, package-lock.json, packages.lock.json,
Package.resolved, pubspec.lock, and mix.lock. A package only the lockfile
names is a transitive component of the root. The rule and the per-dialect
read are on [SBOM transitive dependencies](sbom-transitive.md) and
[SBOM dependency resolution](sbom-resolution.md#transitive-lockfile-resolution).

One dependency shape is neither a package manifest nor a lockfile: a GitHub
Actions workflow action. syft catalogues it, and so does adacovex, as a
dev-scope `pkg:github/owner/repo@ref` component read from `uses:` lines in
`.github/workflows/*.yml` and the repository's own composite action.

The remaining gap is deliberate. Installed environments stay unread (see
[Gaps rejected](#gaps-rejected)), because reading one would describe a
machine rather than a project, and a lockfile that is not in the table
states its set in a dialect no reader covers.

## Gaps worth closing

These gaps fit the zero-dependency rule, because each one is a file parse:

- **Dev-dependency inclusion.** syft reads `devDependencies` only when asked
  (`javascript.include-dev-dependencies: false` by default). adacovex reports
  test-labelled dependencies as a first-class `test` scope, which is the
  richer answer for the standards this tool serves.
- **Lockfile-resolved licence.** A package that only a lockfile names has
  no sibling licence file, so adacovex leaves the licence empty where syft
  reads one from an installed copy. Registry licence resolution covers the
  declared set; a licence is never read from a lockfile, because a lockfile
  states a version and not a licence.

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

`src/tests/e2e/cli/cli_flags.py` runs `sbom` over every project that is present. It
checks the component table: known scopes, no duplicate component, no invented
licence or source link on a system row, and no component from an ecosystem
the project does not declare. A missing sibling is skipped, so a clean clone
and CI stay green.

yams also pins the generated-tree rule: its Meson build tree records the
developer's `PATH`, so a scan that read the tree listed `cargo` and `go` for a
C project. The check fails if either name appears again.
