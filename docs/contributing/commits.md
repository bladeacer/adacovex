# Commit Messages

adacovex uses Conventional Commits. The format is
`<type>(<scope>): <description>`. These conventions live on this page so
human contributors and [LLM coding agents](llm-usage.md) read and apply
the same rules. Every commit in the repository follows them.

## Types

| Type | Use for |
| ---- | ------- |
| `feat` | A new feature for a user. |
| `fix` | A defect repair. |
| `docs` | A documentation change only. |
| `refactor` | A code change with no new behaviour. |
| `test` | A test change only. |
| `perf` | A change that improves a measured result. |
| `build` | The task runner, a manifest, or a build setting. |
| `ci` | The workflows and the composite action. |
| `chore` | A task with no product change, such as a new scope row. |

## The scope table

The scope names the component the change serves. It comes from this
table; a folder name is never a scope on its own.

| Scope | Covers |
| ----- | ------ |
| `cli` | `src/adacovex_main.adb`, the version spec, and the man-page constants. The CLI surface and the early-exit modes. |
| `core` | `src/core/`. Types, config, cache, paths, the prove runner, and the other core packages. |
| `parsers` | `src/parsers/`. The input-file parsers and the dependency graph. |
| `renderers` | `src/renderers/`. The ANSI, HTML, man, Markdown, SBOM, and SVG output. |
| `server` | `src/server/`. The HTTP server and its routes. |
| `ir` | `src/ir/`. The IR synthesiser and the bounded scalar types. |
| `compliance` | `src/compliance/`. The DAL assessment logic. |
| `tests` | `src/tests/`. The native suite and the test runner. |
| `tools` | `tools/`. The task runner, the gates, and the generators. |
| `docs` | `docs/`, `README.md`, `CONTRIBUTING.md`, `AGENTS.md`, and the changelogs. |
| `ci` | `.github/workflows/` and `action.yml`. |
| `build` | The `justfile`, the `Makefile`, `install.sh`, and the Alire manifests. |
| `tldr` | The bundled tldr page (`docs/tldr/adacovex.md`) and its installer. The page format, client detection, the platform directory, and the structure gate. |
| `release` | `tools/release.py`, `alire/releases/`, and `index/`. |

## The rules for a scope

- Keep the subject up to 72 characters. Start with a verb, end the
  subject without a full stop, and use British English.
- Name the one component the change serves. Omit the scope when the
  change touches the whole repository, and never repeat the type as
  the scope.
- Never invent a scope. Add its row to the table above first, in a
  `chore:` commit of its own.
- Split a change that touches two components into two commits. Explain
  why the change was needed, never what the diff shows.
- Link the issue at the end of the body with `Closes #123`.
- Regenerated artifacts (`sbom.json`, `test_result.md`,
  `docs/test_result.md`, `docs/api-docs/`, the version spec, and the
  bundled template specs) ride with the commit that triggers them.

## Examples

```text
fix(parsers): keep the cached source walk out of dot links
fix(tests): fail the process when the native suite is red
docs: rewrite the plan for v1.62.0 and ASCII-clean the perf notes
```

## Suggesting a message

After you finish a change, suggest the commit message and do not run
the commit yourself unless the user asks for it. Give the message in a
fenced block, state why the scope fits, name the version in `plan.md`
(the work plan at the repository root) the change belongs to, and say
whether the change needs a MAJOR version.
