# SBOM transitive dependencies

A manifest states the packages a project **declares**. A lockfile states the
set the project actually **resolves**, which is larger, because each declared
package pulls its own. A CI workflow states a third shape: the actions the
pipeline runs. This page covers both extra sets, the scopes they carry, and
the rules that keep a structure key out of them.

## Lockfile-resolved dependencies

adacovex reads the lockfile beside a manifest, so the SBOM carries the
packages the project really installs. A declared package keeps its `base`,
`dev`, or `test` scope, and a package only the lockfile names is a
`transitive` component of the root.

| Lockfile             | PURL type      | Language   |
| -------------------- | -------------- | ---------- |
| `Cargo.lock`         | `pkg:cargo`    | Rust       |
| `poetry.lock`        | `pkg:pypi`     | Python     |
| `Gemfile.lock`       | `pkg:gem`      | Ruby       |
| `composer.lock`      | `pkg:composer` | PHP        |
| `package-lock.json`  | `pkg:npm`      | JavaScript |
| `packages.lock.json` | `pkg:nuget`    | C#         |
| `Package.resolved`   | `pkg:swift`    | Swift      |
| `pubspec.lock`       | `pkg:pub`      | Dart       |
| `mix.lock`           | `pkg:hex`      | Elixir     |

A declaration that states only a constraint (for example `http: ^1.0.0`)
takes the version the lockfile pins. The version follows into the PURL and
the bom-ref, so `pkg:pub/http@1.1.0` is the same component everywhere. A
lockfile states a version and not a licence, so a lockfile-only component
carries no licence and no source link until a licence file or the registry
answers. Editing a lockfile invalidates the cached graph, so the next run
reads the new set.

The reader for each dialect, and the line shape it follows, are on
[SBOM dependency resolution](sbom-resolution.md#transitive-lockfile-resolution).

## Workflow actions

A GitHub Actions workflow declares its own dependencies: a
`uses: owner/repo@ref` line names an owner, a repository, and a ref the
pipeline runs. adacovex reads `.github/workflows/*.yml`, `*.yaml`, and the
repository's own composite `action.yml`, and registers each one as a
dev-scope `pkg:github/<owner>/<repo>@<ref>` component. The ref is the pinned
tag or the commit SHA, and `pkg:github` is the type syft uses for an action.

Four values state no dependency, so they are skipped rather than guessed:

- a local action (`uses: ./path`), which is the project itself;
- a container image (`uses: docker://...`), which is not a repository;
- a reference with no ref (`uses: owner/repo`), which pins nothing;
- an unresolved expression (`uses: owner/repo@${{ matrix.ref }}`).

A subdirectory reference (`owner/repo/sub/dir@v1`) registers the repository,
because the subdirectory is a location inside it. A workflow and a composite
action carry the same key, so a step in either one registers the same way.
