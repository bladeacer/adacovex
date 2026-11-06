# adacovex 1.67.0

Date: _2026-11-05_

Version bumped 1.66.0 -> 1.67.0.

## Changes

### C1: The API reference names every subprogram parameter

Many generated API pages listed a parameter with an empty Description cell.
The reader saw a table row that named a parameter and then said nothing about
it. The cause was twofold. Some source docstrings never carried an `@param`
line for the parameter, and the converter that builds the pages dropped the
docstrings that did exist.

The docstrings now document every parameter of the affected subprograms:
`Adacovex.Cache.Get_Meta`, `Adacovex.Complexity.Check_Gates` and
`Adacovex.Complexity.Print_Report`, `Adacovex.CPUs.Run_Capture`,
`Adacovex.Prove.Run_Prove`, the five `Adacovex.Types.To_String` overloads that
had none, and the four SPARK coverage and dashboard renderers in
`Adacovex.Renderers.HTML`. Each of the 26 test categories also documents its
`Run` procedure and its `R` parameter, so the per-category page states what
the category covers.

The generated `Adacovex.Docs_Template` unit now carries the same annotations.
`tools/gen-docs.py` emits the offline manual specification, so it emits the
`@param` and `@return` lines for `Body_Bytes`, `Base85_Decode`, `Content`, and
`Find` from one place.

Every page that lost a description now shows it. The converter changes that
made that possible are recorded under H1.

### C2: `adacovex init` writes the project configuration

A new project needs an `adacovex.toml` before the precedence rules can help
it, and the sample at the repository root is not in a consumer's tree. The new
`adacovex init` subcommand writes the same scaffold into the target directory:
every supported key at its default, with the deployed configuration guide
linked.

The command never replaces an existing file unless `--force` is given. Without
it the file is left alone and the command exits 1, so a project's own settings
survive an accidental rerun. The command writes to `<target>/adacovex.toml`
only, never to the global configuration directory.

The global configuration file gains `[init] scaffold`. It takes true or false
and defaults to true. With `scaffold = false`, `adacovex init` writes no file,
prints the reason, and exits 0, so a machine can turn the scaffold off for
every project. A project file cannot set the key, because the project file is
what `init` would create.

The sample file at the repository root now links to the deployed manual
(`https://adacovex.readthedocs.io/en/latest/usage/configuration.html`) instead
of the repository-relative page, so a crate consumer reaches a working link.

### C3: The configuration file is tested by real runs

The reader, merge, and precedence rule already had unit tests. Those tests
show what a parser returns, not what a run does. `tests/e2e/cli_flags.py` now
drives the built binary over the precedence matrix with an isolated global
configuration directory: a project file alone, a global file alone, the
project winning per key while the global file supplies the rest, an explicit
flag winning over both, and `--target` from another working directory reading
the target's file only.

The suite also checks that a `[prove]` key changes nothing outside the prove
subcommand, that malformed input (missing, empty, unknown section, unknown
key, non-integer, unterminated quote, over-long path) never fails a run, and
that the shipped sample file leaves a run unchanged. The `init` checks cover
the scaffold, the exit-1 refusal, `--force`, and the global `[init] scaffold =
false` switch. With a prover on `PATH`, the same suite checks that `[prove]
coverage = false` hides the coverage summary and that an explicit `--coverage`
wins over the file.

### C4: `serve` watches the target and refreshes the dashboard

`adacovex --serve` now watches the target by default. Every two seconds the
server rescans through the result cache and publishes fresh document and
package metrics. The page polls `GET /api/watch` and reloads when the
generation moves, so an edit shows without a manual restart.

`--no-watch` turns the refresh off and serves the starting metrics. `--watch`
states the default explicitly. Either form without `--serve` is an error, like
`--serve-workers`.

Watch refreshes document and package metrics only. Proof, test, and compliance
panels keep the starting run's values, because those artefacts change only on
a real `adacovex prove` or test run. The `prove` subcommand never watches.

The scan runs in the server's main loop, not in a worker, so a refresh never
blocks a response. A protected store hands the latest metrics to the workers,
and the generation moves only when the documented or total count changes.

### C5: The performance material is split by audience

The user-facing run times now live on one page,
`docs/usage/performance.md`: the cold and warm pipeline shapes, the prove
shapes, and the build no-op. It links to the contributor method instead of
repeating it.

The landing page gains a documentation map that states the job of each
directory under `docs/`. The contributor performance index keeps the benchmark
definitions, adds [The `just check` pipeline](../../docs/contributing/perf/check-pipeline.md),
and points readers at the user-facing results page.

### C6: `just check` builds once and reports its timings

`task_build` now records a successful build in the process, so the native
test, prove, complexity, and SBOM gates reuse it instead of running
`alr build` again. The gates already group the native tests, the CLI
end-to-end checks, and the prove diagnostics into one invocation each.

Every `just check` run prints a gate-timing table after the summary, slowest
first, with the sequential total. The table is the measurement to compare
across changes; no separate run is needed.

Parallel execution was explored and rejected. The gates share generated
outputs (`sbom.json`, the version spec, the docs bundle, the badges), so
concurrent writers race and the summary stops being deterministic. The wall
time is dominated by build and proof, which are already single invocations.

The 60-second budget is recorded as a warm-tree target. A cold proof alone
runs 61-88 s, so a cold tree cannot meet it; the timing table makes the
difference visible rather than hiding it.

## Fixes

### H1: rst2md keeps the docstrings it already has

`tools/rst2md.py` builds the API pages from the gnatdoc RST output and the Ada
specs. Four defects hid docstrings that the source already carried.

The `record_depth` counter rose on a multi-line `type X is` declaration and
never fell, because an enumeration has no `end record`. Every subprogram after
the first enumeration in a spec lost its annotation block, so its whole
parameter table rendered empty. The counter now treats a `type X is` header as
a type body that closes on its terminating semicolon, and a `record` line that
follows the header still opens a record.

Annotation tags also leaked across blocks. A file header that shows the
supported `@param` form put an example tag on the first subprogram of the
file, which changed the annotation key and hid the real tags. A blank line or
any other code line now ends the block, so tags belong only to the declaration
they sit against.

`find_ads` skipped `src/tests/`, so the per-category test pages never found
their spec and every `Run` parameter stayed blank. The lookup now searches the
test tree too. Private-section subprograms were recorded as private items but
their annotation blocks were discarded; they are kept now, so the private
section renders its parameter tables.

The tools suite pins the first two defects: a multi-line enumeration followed
by a documented function, and a header example tag followed by a documented
procedure.

## Test Suite

- 2143/2143 native tests passing across 29 categories. The watch flags add
  three configuration checks and the new route adds three server checks.
- `tools/tests.py` grows to 202 checks with the two new `rst2md` regression
  checks (the type-body counter and the header-tag leak).
-The CLI end-to-end suite grows to 110 checks: the `init` scaffold, the
configuration precedence matrix, and serve watch. Its prove-side checks
are skipped when no `gnatprove` is on `PATH`.

The tooling-ergonomics plan behind this release was audited after the entry
was written. The watch flags (C4), the docs map and performance split (C5),
and the build-once timing table (C6) closed the checkboxes that were still
open at the time. Two checks were never part of this release and carry into
v1.68.0: a real-run test of the composite action with a project
configuration file, and one warm-tree `just check` budget measurement. See
`plan.md` for both.

## Proof Results

- gnatprove 16.1.0: SPARK Gold, 1054/1054 VCs proved across 75 analyzed
  units, 0 unproved, and 0 justified. No proof surface changed: the work adds
  comments to specs and test packages, and it edits two Python tools (see
  `docs/proof/16.1.0-ledger.md`). The new statements sit in the
  `Adacovex.Config` I/O body and the CLI entry point, both outside the SPARK
  proof surface, so the VC count is unchanged.

## Traceability

No new HLR record enters this release. The changed packages keep their
existing tags:

- `-- HLR-CACHE` (`adacovex-cache`): the `Get_Meta` parameter block;
- `-- HLR-COMPLEXITY` (`adacovex-complexity`): the gate and report parameter
  blocks;
- `-- HLR-CPU` (`adacovex-cpus`): the `Run_Capture` parameter block;
- `-- HLR-PROVE` (`adacovex-prove`): the `Run_Prove` target parameter;
- `-- HLR-RENDER-HTML` (`adacovex-renderers-html`): the dashboard and SPARK
  coverage renderer parameter blocks;
- `-- HLR-SCAN` (`adacovex-parsers-source`): the scanner docstrings the
  converter now keeps;
- `-- HLR-ARCH` (`tools/rst2md.py`, `tools/gen-docs.py`): the converter
  fixes, the test-package lookup, and the generated manual annotations;
- `-- HLR-CLI` (`adacovex-config`): the `init` parser branch, the `[init]
  scaffold` key, the sample-file writer, and the `--watch` / `--no-watch`
  flags;
- `-- HLR-SERVER` (`adacovex-server-http`): the `/api/watch` route, the watch
  payload, the protected metric store, and the two-second scan loop.
