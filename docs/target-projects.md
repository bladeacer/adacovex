# Target project requirements

adacovex assesses an **Ada/SPARK project** -- the target root can be the
repository root or a subdirectory (via `--target=PATH`). To produce a
meaningful report the target should provide the following; anything missing
shows as `N/A`, and DAL checks that depend on it report `Unmet`.

## What the target provides

1. **Ada source files** (`.ads`) under the target root -- scanned for
   subprogram declarations, docstrings, and HLR traceability tags. See the
   [docstring spec](api-docs/adacovex-docstring-spec.md) for the annotation
   format and coverage rules.
2. **GNATprove output** -- a `gnatprove.out` summary, discovered in this
   order:
   - `<target>/obj/gnatprove/gnatprove.out`
   - `<target>/gnatprove.out`
   - `<target>/gnatprove/gnatprove.out`
   
   Or run `adacovex prove` (or the GitHub Action with `prove: true`) to
   generate a fresh summary before assessing.
3. **Test results** -- a test-summary file, auto-discovered from a
   conventional name at the project root or under `docs/` (for example
   `test_result.md`, `test_results.md`, `test-result.md`, `tests.md`,
   `test_result.txt`, `test_results.log`, `docs/test_result.md`, ...).
   Supported formats: Markdown tables, TAP, Automake, Maven Surefire, Unity,
   and AUnit-compatible output -- see the
   [test format spec](api-docs/adacovex-test-format.md).
4. **HLR / LLR documents** (for DAL assessment) --
   `<target>/docs/compliance/HLR.md` and optionally
   `<target>/docs/compliance/LLR.md`, following the
   [DO-178C requirement format](api-docs/adacovex-dal-levels.md).

## Missing data

| Missing | Effect |
|---------|--------|
| No `.ads` sources | No packages scanned; metrics report zero |
| No `gnatprove.out` | SPARK level `Stone`, proof metrics `N/A` |
| No test summary | Test metrics `N/A`; DAL `Tests passing` criterion `Unmet` |
| No `HLR.md` | HLR coverage `N/A`; DAL traceability criteria `Unmet` |

## Non-Ada projects

adacovex currently targets Ada/SPARK sources. Non-Ada projects (C/C++, Python,
JS, ...) that want to use the compliance/SBOM tooling provision their own
`alire.toml` / `alire-dev.toml` to manage the Ada dependencies needed to build
adacovex itself; running `adacovex` from such a repo scans it and uses its
manifest.

> We are currently working on support for other languages, stay tuned.

## Vendored code and strict mode

By default (strict mode) every directory except the always-excluded ones is
scanned and counted -- including vendored code. For third-party code you
cannot modify, use docstring **patch files** at
`<target>/.adacovex/patches/<relative-path>` (see
[Architecture -- Patch System](architecture.md#patch-system)), or run in
relaxed mode (`--relaxed`, skip dirs, no patches) -- see
[Strict vs relaxed mode](cli-reference.md#strict-vs-relaxed-mode).
