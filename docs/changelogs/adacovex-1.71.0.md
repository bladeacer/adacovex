# adacovex 1.71.0

Date: _2026-11-16_

Version bumped 1.70.0 -> 1.71.0.

## Changes

### C1: The SBOM parses every language syft catalogues

`adacovex sbom` now reads a source tree in every language syft catalogues,
plus Ada. The ecosystem table in `Read_Vendor_Manifest` covers 24 manifest
shapes through six readers: JSON, TOML, XML, and one generic key/value
reader for the `Key: value`, `Key = value`, and `{Key, value}` dialects, plus
a package-named suffix row for the six ecosystems whose manifest name varies
(`*.csproj`, `*.gemspec`, `*.podspec`, `*.rockspec`, `*.opam`, `*.cabal`).

`Register_Root_Manifest_Deps` registers the root's own composer, cargo, pub,
cran, hackage, and opam declarations from one row table, and its collectors
read TOML sections, YAML blocks, and comma lists structurally. A licence in a
non-SPDX vocabulary (R's free-form field, CPAN's `perl_5`) stays empty so the
sibling licence file classifies instead: a licence is never guessed.

One committed mini project per language lives under
`src/tests/fixtures/ecosystems/`, each with a real manifest, a source file,
and a README. The suite copies each project into a temporary vendor tree and
reads name, version, licence, PURL type, and language back out of the graph.
A language is never claimed without a project a reader can open.

### C2: Lockfile-only packages and workflow actions reach the graph

`Read_Lockfiles` covers nine lockfiles through five readers: a TOML package
list, an indented gem list, a JSON object map, a YAML package map, and the
Elixir term map. A package that only a lockfile names is a `transitive`
component with its version, PURL type, and language.

A declared package keeps its base, dev, or test scope and takes the locked
version when the manifest states only a constraint. The version follows into
the PURL and the bom-ref. `Discover_Workflow_Actions` catalogues
`uses: owner/repo@ref` as a dev-scope `pkg:github` component, and skips a
local action, a container image, an unpinned reference, and an unresolved
expression.

Debt D15 closed in the same work: `Is_SPDX_Id` sends an SPDX expression to
CycloneDX `license.expression` and keeps a single identifier in `license.id`.
The SPDX output states either shape unchanged.

### C3: Every fixed-width copy takes one checked bound

`Adacovex.Prove` copied the two proof artefacts through an array of padded
17-character names, so a component bound of 15 raised a length check at copy
time for the summary name. The copy now passes each artefact name as an
unconstrained string to one local `Copy_Artefact` procedure, which checks it
against `Max_Path` alone. No second name width can disagree with the path
bound.

The five `Max_*` constants now state their tier in the package docstring:
`Max_Path` and `Max_Line` fail loudly, and `Max_Id_Str`, `Max_Desc_Str`, and
`Max_Filename` clamp with their length field. The overflow contract in the
architecture guide tabulates all five and names the copy rule. Debt D5
closed.

### C4: The tool scan reads command text and covers the fixture tools

A build file that mentions a tool only in a comment no longer registers that
tool. `Scan_File` stops at an unquoted `#` that starts a word, and a leading
`#!` shebang stays command text because a shell script depends on its
interpreter. Debt D3 closed: the whole-word rule still counts a tool named in
a variable, and the SBOM page states that wider rule as accepted.

The curated table gains `meson`, so it covers every build tool the committed
fixture projects name (`make`, `ninja`, `meson`, `alr`, `python3`, `git`,
`gnatprove`). `sphinx-build` stays out on purpose, because it is the pypi
package sphinx. Debt D14 closed.

### C5: One build, one docs bundle, and one proof run feed `just check`

`tools/tasks.py` now memoises three products across a `check` run: the build,
the bundled offline manual, and the proof. `tools/build.py` already
regenerates the manual among its pre-build steps, so `task_book` reuses that
product instead of running `tools/gen-docs.py` a second time. `task_prove`
records a successful run, so no later gate re-runs gnatprove, and the SBOM
gate reads the single run's `obj/gnatprove/` artefacts.

The `build` gate moved before every gate that needs the binary. The compile
is one row of the timing table instead of being charged to the first gate
that needed it, so the complexity row measures the walk alone. A failed build
is never memoised, so a broken compile cannot hide behind a stale product.
`tools/tests.py` counts the invocations to hold the rule: one build, one
bundle, one proof per run.

A full run on 2026-11-16 passed all 31 gates in 281.30 s, with the compile as
its own 69.65 s row and complexity at 0.16 s. The offline-manual gate read
0.00 s because it reused the build's bundle. The 60 s budget stays with item
15c in v1.72.0, which owns the tools unit tests (80.27 s) and the prove
diagnostics fixtures (44.55 s).

## Fixes

### H1: A comment is not a dependency

A Makefile comment that named `curl` added an installed `curl` to the SBOM as
a system-scope component of the root, because the word scan read the whole
line. The scan now reads command text only, so a tool that a build file
merely mentions in a comment stays out of the graph. A comment that starts a
word opens the comment, and a `#` inside a double-quoted manifest string
stays text.

## Test Suite

`src/tests/adacovex_sbom_tests.adb` adds two checks: a tool named only in a
comment never registers, and `meson` registers from the C-project fixture's
Makefile recipe when it is installed. `src/tests/adacovex_types_tests.adb`
adds five checks: every field subtype matches its `Max_*` constant, the
identifier and description bounds are ordered, and `Max_Line` stays wider
than `Max_Path`. `tools/tests.py` adds a `CheckReuseTests` class that counts
the build, bundle, and proof invocations, including the failed-build case.

Native suite: 2394/2394 passing (29 categories). The tools suite passes 207
tests.

`just prove-e2e` passes 132 checks, and `just cli-e2e` passes 165. `just
run-ada-crdt` is unchanged.

## Proof Results

The change is outside the proof surface. The prove artefact copy and the
manifest scanner are I/O-bound units with no `SPARK_Mode => On` contracts,
and no `SPARK_Mode (Off)` pragma was added: the two exempt packages are
unchanged. The `Types` docstring change is comment-only.

The tree proves at the default budget (gnatprove 16.1.0: 1058 VCs, 0
unproved, 0 justified). Self-assessment: Gold, 100% docstrings, DAL-C
Achieved, ASIL B and Class A Achieved under `--standard=all`.

## Traceability

HLR-SBOM: The SBOM resolves every ecosystem syft catalogues, every lockfile
dialect, and every GitHub Actions workflow action, and states a licence
expression as an expression.

HLR-SBOM: The system-tool scan reads command text in authored build files
only, so a comment or a generated build tree contributes no component.

HLR-METRICS: Every fixed width is one `Max_*` constant with one overflow
tier, and a bounded copy keeps no private bound.

HLR-CHECK: One build, one docs bundle, and one proof run feed every gate, and
a failed product is never reused.
