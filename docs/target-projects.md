# Target project requirements

adacovex assesses an **Ada/SPARK project**. The target root can be the
repository root or a subdirectory (via `--target=PATH`). For a meaningful
report, the target must provide the items that follow. Any missing item shows
as `N/A`. DAL checks that depend on the missing item report `Unmet`.

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
    generate a fresh summary before you assess.
3. **Test results** -- a test-summary file, auto-discovered from a
   conventional name at the project root or under `docs/` (for example
   `test_result.md`, `test_results.md`, `test-result.md`, `tests.md`,
   `test_result.txt`, `test_results.log`, `docs/test_result.md`, ...).
    Supported formats come from your runner's log or a summary file:

    - Markdown tables: the native `test_runner` layout
      `| Category | N | PASS |` and the AUnit-report layout
      `| - | Category | N | PASS |`
    - TAP (`ok`/`not ok`)
    - GNU Automake (`PASS:`/`FAIL:`)
    - Maven Surefire (`Tests run: N`)
    - Unity (`N Tests M Failures`)

    See the [test format spec](api-docs/adacovex-test-format.md) for the
    detailed rules (what each line looks like and which line wins when formats
    mix).
4. **HLR / LLR documents** (for DAL assessment) --
   `<target>/docs/compliance/HLR.md` and optionally
   `<target>/docs/compliance/LLR.md`, following the
   [HLR traceability-tag format](api-docs/adacovex-docstring-spec.md#hlr-traceability-tags).

## Missing data

| Missing | Effect |
|---------|--------|
| No `.ads` sources | No packages scanned; metrics report zero |
| No `gnatprove.out` | SPARK level `Stone`, proof metrics `N/A` |
| No test summary | Test metrics `N/A`; DAL `Tests passing` criterion `Unmet` |
| No `HLR.md` | HLR coverage `N/A`; DAL traceability criteria `Unmet` |

## Non-Ada projects

adacovex currently targets Ada/SPARK sources. Non-Ada projects (C/C++, Python,
JS, and more) that want the compliance/SBOM tooling provide their own
`alire.toml` / `alire-dev.toml` to manage the Ada dependencies needed to build
adacovex itself. Running `adacovex` from such a repo scans it and uses its
manifest.

> We are working on support for other languages. Watch for updates.

## Vendored code and strict mode

By default (strict mode) adacovex scans and counts every directory except the
always-excluded ones. Vendored code is included. For third-party code you
cannot modify, use docstring **patch files** at
`<target>/.adacovex/patches/<relative-path>` (see
[Architecture -- Patch System](architecture.md#patch-system)). Or run in
relaxed mode (`--relaxed`, skip dirs, no patches) (see
[Strict vs relaxed mode](cli-reference.md#strict-vs-relaxed-mode)).

Vendored code can also take part in the **SPARK proof**. A patch carrying
`SPARK_Mode` / `Pre` / `Post` / `Global` aspects is a *proof patch*. The
`prove` subcommand merges it into a patched tree copy. The copy uses `.ads`
spec contracts and `.adb` body patches that opt a SPARK-clean vendored body
into the proof. See
[Proving and writing proofs](proving.md#proof-patches-proving-vendored-dependencies)
for how to write them. See
[Architecture -- Proof patches](architecture.md#proof-patches-spark-contracts-over-vendored-dependencies)
for the design.
