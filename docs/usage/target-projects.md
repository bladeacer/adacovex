# Target project requirements

adacovex assesses an **Ada/SPARK project**. The target root can be the repository root or a subdirectory (via `--target=PATH`). For a meaningful report, the target must provide the items that follow. Any missing item shows as `N/A`.

DAL checks that depend on the missing item report `Unmet`.

## What the target provides

1. **Ada source files** (`.ads`) under the target root -- scanned for
   subprogram declarations, docstrings, and HLR traceability tags. See the
   [docstring spec](../api-docs/adacovex-docstring-spec.md) for the annotation
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

    See the [test format spec](../api-docs/adacovex-test-format.md) for the
    detailed rules (what each line looks like and which line wins when formats
    mix).
4. **HLR / LLR documents** (for DAL assessment) --
   `<target>/docs/compliance/HLR.md` and optionally
   `<target>/docs/compliance/LLR.md`, following the
   [HLR traceability-tag format](../api-docs/adacovex-docstring-spec.md#hlr-traceability-tags).

## Missing data

| Missing | Effect |
|---------|--------|
| No `.ads` sources | No packages scanned; metrics report zero |
| No `gnatprove.out` | SPARK level `Stone`, proof metrics `N/A` |
| No test summary | Test metrics `N/A`; DAL `Tests passing` criterion `Unmet` |
| No `docs/compliance/HLR.md` | HLR coverage `N/A`; DAL traceability criteria `Unmet` |

## Language support

adacovex is a tool for **Ada/SPARK**, and Ada/SPARK is the only **first-class**
language: source scanning, docstring coverage, HLR traceability, DAL
assessment, and the proof pipeline are Ada-specific. Every other language
joins the SBOM, complexity, and test-dependency tooling at the level that
applies to it. The tiers below make the support explicit, so a team knows
what to expect before it runs an assessment.

### Ada / SPARK -- first-class

- Full source scan of `.ads` / `.adb` (subprograms, docstrings, HLR tags).
- Per-subprogram cyclomatic complexity.
- SPARK proof analysis and the Platinum-level proof gate.
- DO-178C / ISO 26262 / IEC 62304 DAL assessment.
- Alire / GPR manifests build the Ada dependency graph in the SBOM.

This is the only tier whose assessment a project can fully rely on.

### Manifest-aware ecosystems -- SBOM dependency graph

These languages' manifests contribute **first-class dependency graph** entries
(with the right PURL type, scope, and licence resolution): `package.json`
(npm), `Cargo.toml` / `Cargo.lock` (cargo), `go.mod` (go), `pyproject.toml`
and `requirements*.txt` (pypi), `composer.json` (composer), `Gemfile` /
`Gemfile.lock` (gem), `pom.xml` (maven), `Package.swift` (swift), plus Alire
and GPR files for Ada. Each ecosystem gives the resolved dependency its
language, PURL, scope (base / dev / test / transitive / vendored), and a
licence when the local manifest or registry answers. See
[sbom.md](sbom.md) for the full manifest table.

### Extension-detected languages -- component language, complexity, test deps

The source **extensions** below are recognised for three purposes:

1. **Component language detection**: vendored trees, `vendor/`,
   `node_modules`, resources, and loose source drops report their language(s)
   from the extensions actually present (a directory mixes languages and
   reports its top 3).
2. **The `complexity` subcommand**: per-file lines of code and decision
   counts for these languages (Ada is the only per-subprogram analysis).
3. **Test-dependency names**: the npm/Cargo/Go/Maven/PyPI test-label heuristic
   works from the dependency *name* and is language-independent.

The recognised extensions are: Ada (`.ads` `.adb` `.ada` `.gpr`), JavaScript
(`.js` `.mjs` `.cjs`), TypeScript (`.ts` `.tsx`), CSS (`.css`), HTML (`.html`
`.htm`), Python (`.py`), Go (`.go`), Rust (`.rs`), C (`.c` `.h`), C++ (`.cpp`
`.cc` `.cxx` `.hpp` `.hh` `.hxx`), C# (`.cs`), Java (`.java`), Ruby (`.rb`),
PHP (`.php`), Swift (`.swift`), Kotlin (`.kt` `.kts`), Scala (`.scala`),
OCaml (`.ml` `.mli`), Lua (`.lua`), Perl (`.pl`), Haskell (`.hs`), Elixir
(`.ex` `.exs`), Erlang (`.erl` `.hrl`), Clojure (`.clj` `.cljs`), Dart
(`.dart`), Shell (`.sh` `.bash`), PowerShell (`.ps1`), SQL (`.sql`), Fortran
(`.f` `.f90` `.f95` `.f03`), Assembly (`.s` `.asm`), R (`.r`), Julia (`.jl`),
Zig (`.zig`), VHDL (`.vhd` `.vhdl`), and Tcl (`.tcl`).

The extension is the source of truth: a `.py` file reports Python even when a
`Cargo.toml` sits next to it. The manifest language only breaks ties.

### Python requirements files

The `requirements*.txt` parser is deliberately **flexible**: a literal
`requirements.txt` at the target root always wins, and adacovex falls back to
the first `requirements*.txt` in that directory when the fixed name is
missing. Entries register as `dev`-scope `pkg:pypi/*` components of the root
(the real packages -- for example `sphinx` and `myst-parser` -- never become
generic `system` tools). A version pinned in the requirements line wins; the
package registry (`pip index versions`) fills a missing version and the
licence/website when it is online. A missing registry or an offline machine
keeps a name-only entry -- adacovex never guesses a version or licence.

For anything outside these tiers, adacovex still runs its Ada/SPARK
assessment on the project's Ada sources (and reads its Alire manifest) when
they exist; a pure-foreign-language repository contributes its SBOM
components, language detections, and complexity scores but no Ada metrics.

## Vendored code and strict mode

By default (strict mode) adacovex scans and counts every directory except the
always-excluded ones. Vendored code is included. For third-party code you
cannot modify, use docstring **patch files** at
`<target>/.adacovex/patches/<relative-path>` (see
[Architecture -- Patch System](../contributing/architecture.md#patch-system)). Or run in
relaxed mode (`--relaxed`, skip dirs, no patches) (see
[Strict vs relaxed mode](cli-reference.md#strict-vs-relaxed-mode)).

Vendored code can also take part in the **SPARK proof**. A patch carrying `SPARK_Mode` / `Pre` / `Post` / `Global` aspects is a *proof patch*. The `prove` subcommand merges it into a patched tree copy. The copy uses `.ads` spec contracts and `.adb` body patches that opt a SPARK-clean vendored body into the proof.

See [Proving and writing proofs](../contributing/proving.md#proof-patches-proving-vendored-dependencies) for how to write them. See [Architecture -- Proof patches](../contributing/architecture.md#proof-patches-spark-contracts-over-vendored-dependencies) for the design.

