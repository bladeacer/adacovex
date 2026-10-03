# adacovex v1.57.0 -- implementation plan

Status: **planning complete, no code written.** This document records the
measurements taken on 2026-10-03, the design decisions taken from them, and the
answers to every open question, so the implementation can start without
repeating the investigation. Section 7 is the decision table.

Scope, in delivery order:

1. Build performance (the `make build` bottleneck).
2. `adacovex spark-coverage` -- a new subcommand reporting three coverage
   metrics, plus a dashboard panel and a JSON API endpoint.
3. SPARK opt-in sweep -- the full pure-logic work queue, in prove order.
4. A `tldr` page for the command line, kept in-repo.
5. The prove-timing phase decision for 1.55.0-1.57.0.

Items 2 and 3 interact: the new command reports the surface that item 3
shrinks, and item 3 is judged by whether the report's work-queue class gets
smaller. Item 1 lands first because item 3 changes Ada source and a slow build
makes every proof iteration expensive.

---

## 1. Build performance

### 1.1 What was measured

The user report says "fresh rebuild is a bit too slow, most likely docs
bundling". **The docs bundling is not the bottleneck.** A full
`alr build` (all 101 bodies recompiled) is 39.1 s on this 12-core machine.
Per-file compile times, measured with the Alire toolchain gcc
(`gnat_native_16.1.0_9f74f58a`) and the project's own switch set:

| Unit | ms |
|------|----|
| `src/parsers/adacovex-parsers-manifest.adb` | 21 910 |
| `src/core/adacovex-types.adb` | 9 275 |
| `src/tests/adacovex_config_tests.adb` | 8 839 |
| `src/core/adacovex-complexity.adb` | 7 366 |
| `src/parsers/adacovex-parsers-do178c.adb` | 3 986 |
| `src/core/adacovex-config.adb` | 3 928 |
| `src/parsers/adacovex-parsers-source.adb` | 3 589 |
| `src/renderers/adacovex-renderers-html.adb` | 2 650 |
| `src/core/adacovex-prove.adb` | 2 537 |
| `src/adacovex-docs_template.adb` | **288** |
| `src/adacovex-dashboard_template.ads` | n/a (spec only, folded into its body) |

Total serial compile: 99.8 s across 101 files. The two generated bundle specs
together are 0.3 percent of it.

Generator costs when nothing changed (the normal `make build` shape):

| Step | ms |
|------|----|
| `tools/gen-version.py` | 44 |
| `tools/csslint.py --check` | 44 |
| `tools/gen-dashboard.py` | 152 |
| `tools/gen-docs.py` (stamp current, 250 assets cached) | 365 |
| `sphinx-build` from scratch | 7 847 |

So a *no-op* `make build` is ~0.6 s of generators plus a 0.8 s no-op
`alr build`. The 41 s figure the user pasted is a **full** rebuild, where every
body recompiles.

### 1.2 Why the compile is slow

`adacovex-parsers-manifest.adb` alone is 22 percent of the serial compile.
Same file, same switch set, varying only the optimisation level:

| Switches | ms |
|----------|----|
| `-O2 -gnatn -g` (project default) | 20 316 |
| `-O2 -gnatn` | 19 107 |
| `-O1 -gnatn` | 11 633 |
| `-O0 -gnatn` | 5 466 |

`-O2` costs 3.5x over `-O0` on this one body. The body is 2 254 lines with
four local `Ada.Containers.Vectors` instantiations and heavy string-field
copying (`Types.Desc_Field` is a fixed-size array copied by value on every
append), which is exactly the shape GCC's inliner and alias analysis spend
time on.

`gnatprove` runs on its own analysis of the same tree and does **not** use the
`-O2` object code, so `-O2` buys nothing for the proof path. It only buys
runtime speed for the released binary, which the [benchmarks]
(docs/contributing/perf/benchmarks-timings.md) already measure at a 41 ms warm
pipeline.

### 1.3 Planned changes

**Decision: do all of B1-B4.** The measured causes are independent (code
shape, optimisation level, debug info, build parallelism), so each is a
separate lever and the plan takes all four. B4 is still measured first,
because if Alire's job count is the ceiling it is a one-line fix that may
make B2's cost less pressing.

**B1 -- Split `adacovex-parsers-manifest.adb` (largest single win).**
The 21.9 s body is already a partially-split package: 40 sibling
`adacovex-parsers-manifest-*.adb` files hold small helpers, and the parent body
holds the rest. The remaining parent body is still one 2 254-line unit. Split
the remainder the same way (one helper per file, named for the subprogram),
which also matches the existing convention the AGENTS.md tree documents. This
is pure code motion: no behaviour change, no new proof surface.

Expected effect: the longest single compile drops well under 10 s, which is
what sets the critical path on a parallel build.

**B2 -- Add a `-O1` development profile and keep `-O2` for release.**
`adacovex.gpr` currently puts `-O2 -gnatn` in `Compiler.Default_Switches`, which
applies to both `alr build` and `alr build --release`. Add a `development`
external profile that overrides the optimisation level to `-O1`, and have
`tools/build.py` detect a release build (`--release`, or `ADACOVEX_VERSION` set)
and select the matching profile. A developer rebuild then costs roughly
half the serial compile time.

Risk, and it is a real one: `-O1` changes the runtime speed of the binary the
pipeline benchmarks measure. **All prove-timing and pipeline figures in
[prove-timing.md](docs/contributing/perf/prove-timing.md) and
[benchmarks-timings.md](docs/contributing/perf/benchmarks-timings.md) must be
taken on the release-equivalent `-O2` build**, whatever profile the developer
happens to be using day to day. State the profile beside every figure. The
existing page already records `/proc/loadavg` beside each number; the profile
belongs in the same note.

**B3 -- Drop `-g` from the release profile.**
`Builder.Default_Switches ("Ada")` adds `-g`, which reached every compile in
the observed command lines and cost ~1.2 s on the manifest body (20.3 s with,
19.1 s without). Keep it on the development profile, where debuggability is
the point, and drop it from the release profile. Re-measure the stripped-size
figures in
[benchmarks-binary-size.md](docs/contributing/perf/benchmarks-binary-size.md)
afterwards, because removing `-g` should shrink the shipped binary and that
figure is recorded in the docs.

**B4 -- Fix the parallelism ceiling.**
`alr build` reports 39 s wall for 99.8 s of serial work on 12 cores, a speedup
of only 2.6x. Sampling the process table during a rebuild shows at most 3
concurrent `gnat1` processes, so the build is not using the machine. Determine
whether the cause is Alire's default job count or the dependency chain
funnelling through `adacovex-types.ads` and `adacovex-parsers-manifest.ads`.
If it is the job count, `tools/build.py` passes `--jobs=<cores>` through. This
is the cheapest fix available, so it goes first even though the other three are
committed.

**B5 -- Keep the docs bundling fast, and prove it stays fast.**
The existing incremental design already does its job: a no-op `gen-docs.py` is
365 ms because of the content stamp plus the SHA-256 encode cache under
`obj/adacovex-docs-encode/`. Two things to do rather than to redesign:

- add the measured table above to
  [benchmarks-timings.md](docs/contributing/perf/benchmarks-timings.md) so the
  "docs are not the bottleneck" claim is a recorded number, not folklore;
- watch the encode cache's growth: at 250 cached bodies it is a real
  directory, and a cold clone re-encodes everything. A cold
  `gen-docs.py` on a fresh checkout is the shape to measure (estimated 8-10 s:
  a 7.8 s Sphinx build plus first-time encoding of ~6 MB).

### 1.4 What is explicitly not changing

The generated specs stay as they are. Splitting the 2.1 MB
`adacovex-docs_template.ads` differently, or moving the blob out of Ada
entirely, would break the proof-input hash exclusion and the offline-manual
cache. Its 288 ms compile is not worth the risk.

---

## 2. `adacovex spark-coverage`

A new early-exit subcommand that reports SPARK proof coverage, grouped by file,
by source folder and by Ada package, and classifies every unit into one of
three states.

**Decisions taken for this feature:**

- Report **all three metrics as separate sub-metrics** -- statement coverage,
  subprogram coverage, and VC coverage. Each is labelled with its unit, and
  the report states plainly which is which. See 2.3.
- Live **inside the existing Proof tab** in the dashboard, not a ninth tab.
  See 2.5.
- Grouping is selectable: `--group=file|folder|package`. See 2.5.
- A **CI threshold gate ships with the feature**, not later. See 2.7.
- The SPARK-off category reports **three sub-classes**. See 2.2.

The three-metric decision is the one that shapes the rest, so it comes first.

### 2.1 What already exists (do not rebuild this)

The data is already on disk after any `make prove`. Two artefacts:

- `obj/gnatprove/gnatprove.out` -- the Detailed analysis report carries
  `in unit <name>, N subprograms and packages out of M analyzed` for all 66
  analysed units, plus one line per skipped entity:
  `Adacovex.Cache.Load at adacovex-cache.ads:98 skipped; SPARK_Mode => Off`.
  There are 357 such lines today.
- `obj/gnatprove/gnatprove.sarif` -- 921 results with `kind` in
  `{pass, open}` and a physical location (`artifactLocation.uri` plus
  `startLine`) per result. The 878 `pass` results are exactly the proved VCs
  and they carry a file and line.

`gnatprove.out` gives the denominator per unit and the skip reason per entity.
The SARIF gives the proved-check count per file and line. Together they cover
the whole metric without running gnatprove.

`Adacovex.Complexity.Analyze_Project` already walks a tree, counts code lines,
and groups by path, so its walk and grouping approach is the model to follow.

### 2.2 Metric definition

Three states per source unit:

- **Proved** -- code in `SPARK_Mode => On` subprograms for which gnatprove
  discharged every check.
- **SPARK off** -- a subprogram the codebase deliberately keeps out of the
  proof. **Three sub-classes, each counted and displayed separately**, so the
  number is honest and the actionable subset stays visible:
  1. **Irreducible** -- the two documented packages
     (`adacovex-types.ads`, `adacovex-complexity.ads`), off because
     non-formal `Ada.Containers` is illegal in `SPARK_Mode On` code.
  2. **I/O-bound** -- bodies calling `Ada.Text_IO`, `Ada.Directories`,
     `GNAT.OS_Lib`, `Ada.Environment_Variables`, or spawning processes.
     gnatprove cannot analyse these at all; off is correct and permanent.
  3. **Work queue** -- default-off bodies that are *pure logic*. These are
     provable in principle and are exactly what item 3 shrinks. This class
     must never be silently merged into the other two, because it is the
     backlog.
- **Not covered** -- everything gnatprove did not report on and that is not
  in a named off class. This must be a real number, not folded into "off",
  or the metric is meaningless.

The off sub-classes need an objective test, not a hand-maintained list.
Classify by what the body's `with` clauses and body text reference: a body
that references one of the I/O packages above, or spawns a process, is
I/O-bound; otherwise it is work queue; the two irreducible packages are
matched by path. The test is the same shape as
`Adacovex.Opt_Outs`' per-file marker detection, so it belongs there or in the
new package, and it must be covered by fixture tests.

### 2.3 The three metrics

**Decision: report all three, each labelled with its unit.** They answer
different questions and an auditor will ask which one a given percentage
means. Presenting only one invites exactly that confusion.

| Metric | Numerator | Denominator | Answers |
|--------|-----------|-------------|---------|
| **Statement coverage** | proved statements | all statements in assessed files | How much of the code is verified |
| **Subprogram coverage** | proved subprograms | all subprograms in assessed files | How much of the design surface is verified |
| **VC coverage** | proved VCs | all reported checks | What the prover actually discharged |

Each is reported overall and per group (`--group=file|folder|package`).

The cost of this choice is that all three denominators must be computed, so
the statement counter in 2.4 is required, not optional. The SARIF and the
per-subprogram JSON are what make the other two cheap.

Within each metric, report the split so the raw ratio does not hide structure:

- `proved / (proved + off)` -- "how much of the SPARK-relevant surface is
  actually verified". This is the number item 3 moves, and the one to watch
  as a trend.
- `proved / total` -- "how much of the whole program is verified". This is
  the audit-facing number, and it will stay far lower because I/O-bound code
  is a large fixed floor.

A reader must never have to guess which of the four ratios they are looking
at. Every table header states its numerator and denominator, and the JSON
output carries them as named fields rather than bare percentages.

### 2.4 Counting statements, subprograms and VCs

None of the three denominators comes free. Each has a source, and all three
are needed under the decision in 2.3.

**Statements -- extend the source scanner (required).**
`Adacovex.Parsers.Source` already parses Ada bodies for procs and funcs.
Extending it to count statements per subprogram reuses the proven,
line-bounded read path. Define the statement count precisely before coding and
write it into the docs, because "statement" is not a standard Ada notion.
Suggested definition: count one per statement -- assignments, procedure calls,
`return`, `raise`, `exit`, `goto`, `null`, and each iteration of a loop body --
excluding declarations, and excluding blank, comment and continuation lines.

**Subprograms -- from `gnatprove.out` plus the per-subprogram JSON.**
`in unit X, N subprograms and packages out of M analyzed` gives the
analysed/total split per unit directly, and the 357 `skipped;` lines name the
individual skipped entities. This is cheap and already accurate at
subprogram granularity. Its one weakness is inherent: a partly proved
subprogram counts as wholly proved or wholly off.

**VCs -- from the SARIF.**
The 878 `pass` results are the proved checks, each with a file and line. This
is the cheapest of the three and needs no new parser.

Reuse note: the scanner extension is the only genuinely new parsing work, and
it is the piece item 3's trend tracking depends on, so do it first.

### 2.5 Placement in the codebase

Follow the `complexity` subcommand exactly; it is the closest existing
analogue (a scan, a gate, an early exit, a report).

- `src/core/adacovex-config.ads` -- `Spark_Coverage_Mode : Boolean := False`
  in the `Config` record, next to `Complexity_Mode`. Add the new flags to
  `Known_Flags` (`src/core/adacovex-config.adb`, the space-separated constant)
  so completion and the typo suggestion know them.
- `src/core/adacovex-config.adb` -- the `A = "spark-coverage"` branch beside
  the existing `elsif A = "complexity"` branch, and its flag branches in the
  `--flag=value` chain.
- New package `src/core/adacovex-spark_coverage.ads/.adb` -- the scanner and
  the report. Keep the parsing logic (the `gnatprove.out` and SARIF line
  shapes) in `SPARK_Mode => On` units where they are pure text handling, the
  way `Adacovex.Parsers.GNATprove` and `Adacovex.Complexity` are split today.
  The package is new, so it must reach 0 unproved under `make prove` with no
  `SPARK_Mode (Off)`: put the tree walk and file reads in an explicitly
  default-off subprogram rather than opening a third Off package (the AGENTS.md
  rule permits exactly two).
- `src/adacovex_main.adb` -- the early-exit block beside
  `if Cfg.Complexity_Mode then` (line 636). Exit 1 when a gate fails, mirroring
  complexity.

CLI shape:

```
adacovex spark-coverage [-t=PATH] [--group=file|folder|package]
                        [--metric=statements|subprograms|vcs]
                        [--format=text|json] [--min=PCT]
                        [--require-coverage=PCT] [--metric-used=GATE_METRIC]
```

`--min` filters the display; `--require-coverage` sets the exit code. Keep
them separate, because a filter that also fails the build is a trap.

`--group` and `--metric` are display selectors with no gate effect, so they
need no action input beyond the parity minimum; `tldr` and the docs still list
them because every `Known_Flags` entry must be documented.

Parity obligations, all feature gates: `action.yml` needs a matching input and
a row in the `docs/usage/ci-cd.md` `### Inputs` table
(`make action-parity-check`), and every flag needs a row in
`docs/usage/cli-reference.md` (`make docs-coverage-check`).

### 2.6 Dashboard and API

**Decision: inside the existing Proof tab. No ninth tab.** The tab strip
already carries eight sections and the coverage table is proof data, so it
belongs with the proof figures a reader has already opened the dashboard to
see.

- `src/server/adacovex-server-http.ads` -- add `Route_API_Spark` to
  `Route_Kind` and the matching `elsif` in the `Route` expression function.
  The routing function is proved, so the new branch is covered by the existing
  postcondition without extra steps.
- `src/renderers/adacovex-renderers-html.adb` -- a
  `Render_Spark_Coverage_HTML` beside `Render_Deps_HTML`, and a
  `Render_Spark_Coverage_JSON` beside `Render_Deps_JSON`. Wire into the
  `Replace_All` chain that fills the `__*__` placeholders.
- `resources/dashboard.html` -- a new `__SPARK__` panel placed **inside**
  `<div id="tab-proof">`, below the current proof content. The existing
  `__PROOF__` placeholder fills that panel, so the coverage markup is appended
  after it rather than added as a sibling tab panel.
- The panel shows all three metrics side by side, the group selector
  (file / folder / package), and the off breakdown with the three sub-classes
  as separate rows. The work-queue row is the one to make visually distinct,
  since it is the actionable backlog.
- `resources/js/spark.js` -- the sortable table, the group selector, and the
  rollup arithmetic. Add the `__JS_SPARK__` entry to `tools/gen-dashboard.py`
  (both the placeholder map and the minify-flag map) or the placeholder is
  never filled.
- `tools/csslint.py` gate applies: every margin, padding and gap a multiple of
  4px.
- `src/tests/adacovex_server_tests.adb` pins every route, so add the new route
  there.

### 2.7 The CI gate

**Decision: the threshold gate ships with the feature, not later.** A
coverage number nobody gates regresses silently, and the point of the command
is to stop that.

Design points to settle before coding:

- **Which metric gates.** Three metrics, so `--require-coverage` needs an
  explicit companion naming the metric it applies to (default: statement
  coverage, the one item 3 moves). Never let an unqualified percentage be
  ambiguous between metrics.
- **Default threshold.** Set it at or just below the self-assessment baseline
  once measured, so the gate passes on the tree it was calibrated from. A gate
  that fails on the project's own tree is a broken gate.
- **Comparison direction.** Fail when coverage falls **below** the threshold.
  Note that item 3 legitimately *raises* coverage, and item 3's work-queue
  class shrinking is the visible sign it worked.
- **Failure output** must name the metric, the numerator, the denominator and
  the achieved value, matching the table headers, and print the `::error::`
  annotation form the other gates already use in CI.

Wire into `action.yml` as an input, add its row to the `docs/usage/ci-cd.md`
`### Inputs` table, and document both flags in
`docs/usage/cli-reference.md`.

### 2.8 Tests

A new category `adacovex_spark_coverage_tests.adb`, registered in the four
places the count-sync gates require (the `test_runner.adb` runner, the category
map in `tools/update-test-count.py`, `tools/agents-tree.map`, and the
CONTRIBUTING table). Cover:

- a fixture `gnatprove.out` with a known mix of proved, skipped and
  unreported lines, asserting the exact values of **all three** metrics, not
  just one;
- the three off sub-classes: an I/O-bound body, a pure-logic body (which must
  land in the work-queue class), and one of the two irreducible packages;
- rollup arithmetic for **each** grouping (`file`, `folder`, `package`); a
  group percentage is a ratio of sums, never a mean of its children;
- the gate: exit 1 below the threshold, 0 at or above it, and the error
  message naming the metric it applied to;
- a missing or unreadable `gnatprove.out`, which must fail loudly, consistent
  with the fixed-size-buffer overflow contract.

Add e2e coverage in `tests/e2e/cli_flags.py` beside `check_complexity`.

---

## 3. SPARK opt-in sweep

### 3.1 Current state

`make prove` reports 878 VCs, 878 proved, 0 unproved, 0 justified, across 66
analysed units. That number only counts what gnatprove looked at. `gnatprove.out`
lists **357 skipped subprograms** carrying `SPARK_Mode => Off`. So the verified
surface is 878 checks against 357 skipped bodies, and the skipped bodies are
where the remaining risk lives.

`docs/archive/16.1.0-ledger-audit.md` classified them. The archive is a record,
not current guidance, and its conclusions are four months old; treat the list
below as a starting hypothesis and re-measure.

Genuinely I/O-bound, out of scope by design (a `pragma SPARK_Mode (Off)`
here is correct and needs no justification work): `adacovex-cache.adb`,
`adacovex-prove.adb`, `adacovex-vcs.adb`, `adacovex-diff.ads`,
`adacovex-server-http.adb` (socket I/O), `adacovex-renderers-man.adb`,
`adacovex-cpus.adb` (env vars, `/proc`), `adacovex-prove_patch.adb`, and the
test harness (`*_tests.adb`, `test_runner.adb`, `adacovex_main.adb`).

The work queue is the default-off pure-logic remainder the audit named:

| Unit | Subprograms |
|------|-------------|
| `adacovex-parsers-source.adb` | `Is_Subprogram_Decl`, `Is_Docstring_Line`, `Has_Sphinx_Field`, `Has_Google_Section`, `Comment_Indent`, `Is_Skipped_Dir` |
| `adacovex-config.adb` | `Set_String`, `To_SPARK_Level`, `Edit_Distance`, `Normalize_Flag`, `Normalize_Topic`, `Suggest_Flags` |
| `adacovex-cpus.adb` | `Parse_Natural` |

Plus whatever item 2's report surfaces beyond this list. The audit found these
left overflow and index VCs at `--steps=30000`, and quantified invariants that
timed out. The known remedies are bounded subtypes for loop cursors, explicit
`Loop_Variant`s, and guard-before-access refactors.

### 3.2 Approach

**Decision: the full queue, one subprogram at a time.** All three units in the
table above are in scope for 1.57.0, not a first tranche. The risk is the
prove-cold row, which item 5 measures; that risk is handled there, not by
shrinking the work.

Work one subprogram at a time, smallest first. For each:

1. Move it to `SPARK_Mode => On` on the body with `Global => null` and
   `Pre`/`Post` contracts.
2. Add `Loop_Invariant` and `Loop_Variant`.
3. Run `make prove` and read the actual unproved VCs. Do not guess.
4. Where a VC resists, apply the bounded-subtype refactor the audit names
   rather than raising `--steps`. The Platinum gate is measured at
   `--level=4`, so a step-budget increase would move every row in the
   prove-timing table.
5. Where a subprogram genuinely cannot be proved, it stays off and the item 2
   report classifies it, with the specific obstruction recorded in the ledger.

   Order the queue so the easy wins land first and the hard ones are not
   blocking: `adacovex-cpus.adb:Parse_Natural` and the simpler
   `adacovex-parsers-source.adb` functions before `Edit_Distance`,
   `Suggest_Flags` and `Is_Subprogram_Decl`, which the audit found resist at
   `--steps=30000`. Landing the tractable ones first means a late blocker costs
   less than it would with the queue in the other order.

Non-negotiable: 0 unproved, 0 justified, and no `pragma Assume` /
`pragma Annotate`. `make spark-off-check` stays green; the two irreducible
packages stay the only two.

### 3.3 What is likely to be unrecoverable, and what to do about it

Some bodies will not yield. When that happens the choice is between a
restructuring that pays for itself (a bounded subtype removes a whole class of
overflow VCs for the rest of the codebase) and an honest classification. Prefer
the restructuring when the subprogram is on a hot path; otherwise record it as
justified-off with the specific obstruction.

I/O-bound bodies are the large majority of the 357. The plan does not attempt
to prove `GNAT.OS_Lib` callers. It attempts to **shrink the pure-logic
boundary** and to make every remaining off body visible and justified in the
item 2 report. That is the honest goal: not 100 percent proved, but a complete
account of why each unproved statement is unproved.

### 3.4 Cost, stated plainly

Every additional proved subprogram adds VCs, and the prove-cold row is
solver-bound and load-dependent (72-82 s at 878 VCs on an idle box, 121 s
under heavy load). Expect the cold row to grow. If it grows past what the
1.55.0-1.56.0 band can absorb, that is a methodology signal, not a
regression, and it belongs in the item 5 phase decision.

The item 2 work-queue class is the progress measure: it should shrink as this
section lands. If it does not shrink, the sweep did not do its job no matter
what the headline percentage says.

---

## 4. tldr page for the `man` workflow

### 4.1 How tldr-pages actually works

The user's question ("not sure if tldr pages has its own sort of man db and how
we write such an entry") deserves a straight answer: **no, tldr-pages has no
man database.** It is a single git repository of Markdown files,
`pages/<platform>/<command>.md`, consumed by clients
(`tldr`, `tealdeer`, `tldr-rs`, web front ends). There is no install step and
no index to register with.

So there are two separate things, and they should not be confused:

- a **tldr entry** is one Markdown file in the tldr-pages repository,
  distributed by that repository's own update mechanism. That is the thing this
  section is about.
- the **`adacovex man` subcommand** installs a real roff page into the local
  man database. That is adacovex's own feature and is unaffected.

**Decision: the page stays in this repository. No upstream pull request.**
The tldr page is kept as adacovex's own documentation of its own command line,
linted against the tldr format so it stays correct, but adacovex does not
contribute it to `tldr-pages/tldr`. The upstream file would land at
`pages/common/adacovex.md` and reach clients only on their own update
schedule, which is not worth a release-blocking dependency on an external
review queue. The in-repo page serves every adacovex user directly.

This does not weaken the value of the format: the page is still written to the
tldr style guide, so it stays concise and correct, and it can be submitted
upstream later if that is ever wanted.

### 4.2 The format

From the [style guide]
(https://github.com/tldr-pages/tldr/blob/main/contributing-guides/style-guide.md):

```md
# adacovex
> Coverage, proof and compliance assessment tool for Ada and SPARK projects.
> More information: <https://github.com/bladeacer/adacovex>.

- Assess the current project and print the report:
`adacovex`
- Assess a project at another path:
`adacovex --target {{path/to/project}}`
- Assess against a DO-178C DAL level:
`adacovex --standard {{DAL-C}}`
- Serve the results as a web dashboard:
`adacovex --serve`
- Run SPARK proofs and then assess the result:
`adacovex prove`
- Install the man page into the local man database:
`adacovex man`
- Check whether the installed man page is current:
`adacovex man --check`
```

Rules that bite: at most 8 examples; the filename and title match the command
name exactly, lowercase filename; descriptions are imperative mood; no italics or
boldface; serial comma in lists; backticks for paths, commands, `stdout` and
`stderr`; `{{placeholders}}` for values.

### 4.3 What to do

- Keep the page **in this repository** at `docs/tldr/adacovex.md` as the
  source of truth, and add a `make tldr-lint` target that runs `tldr-lint`
  against it when `tldr-lint` is on PATH. `tldr-lint` is node-based while the
  repo's tooling is Python-only by convention, so the target detects it and
  **skips cleanly with a message** when it is absent. Do not add an npm
  dependency to this project, and do not add it to `make check`, because a
  gate that silently skips is not a gate -- keep it a local target and note in
  its help text that it needs `tldr-lint` installed.
- Because the linter may be absent in CI, add a **pure-stdlib structural
  check** in `tools/check-docs.py` or a small tool that enforces the rules
  that matter and cost nothing to verify: at most 8 examples, the `#` title
  matches `adacovex`, the `>` description block is at most two lines, every
  example description is imperative, and no italics or boldface. That is the
  check `make check` runs; `make tldr-lint` is the fuller local check.
- Do **not** generate the page from the CLI help text. tldr's format is a
  curated subset, not a dump, and a generator would produce exactly the kind of
  page the linter rejects. Hand-write it.
- Document the page in `docs/usage/cli-reference.md` next to the `man`
  subcommand, and add any Technical Names it introduces to
  `docs/contributing/ste100/index.md`.
- If the page later goes upstream, it is one `git mv` plus a PR; nothing else
  in the plan depends on that.

---

## 5. Prove-timing phase decision for 1.55.0-1.57.0

The user asks whether 1.57.0's proof timing is better than 1.55.0's and
whether the pair can stand as one phase. **Answer: measure first, decide after.
No numbers have been taken yet.**

The rule, from AGENTS.md and
[prove-timing.md](docs/contributing/perf/prove-timing.md): the table keeps one
column per phase, a phase is a range of versions sharing an implementation
methodology, and the column carries one representative version's **complete**
metric set. Never mix best-of rows across versions.

The open phase is 1.55.0-1.56.0 with 1.55.0 as representative. 1.57.0 folds in
if the methodology is unchanged: same measurement method, same
`/proc/loadavg` recording beside every figure, same four-scenario bench. It
closes the phase and opens 1.57.0+ only if the methodology shifts.

### 5.1 The measurement protocol to follow

- `./bin/covex prove` at the binary level, not bare gnatprove.
- Record `/proc/loadavg` beside every figure. The existing page is explicit
  that this machine is shared and the cold rows move by more than 50 percent
  on the same binary.
- Five shapes, as `make bench` already implements them: pipeline warm, pipeline
  cold, prove warm, prove cold (result cache plus `obj/gnatprove/` wiped),
  prove cold clone (fresh tree, no cache, no session, no summary).
- Report the load alongside each figure, and give a range rather than a single
  number where the load spread makes one dishonest.

### 5.2 What the two outcomes mean

**If the timings hold or improve** and the VC count moves only modestly, 1.57.0
folds into the open phase and 1.55.0 keeps the representative slot. The reading
note must state that the new work (build profile, coverage subprogram, SPARK
opt-ins) is off the measured hot path, or that it is on it and still flat.

**If the timings regress materially**, decide whether the cause is
methodology or implementation. A build-profile change (item B2) changes what the
release binary is, so figures from a `-O1` build do not belong in a column
whose representative was measured at `-O2`. Measure the phase figures on the
release-equivalent build regardless, and record the profile in the table.

**If the VC count grows enough to move the solver**, that is a real signal: the
phase's methodology is unchanged but its cost profile is not. Record the new
band honestly rather than folding it in silently.

### 5.3 Also update

- The phase table rows and the representative slot in `prove-timing.md`.
- `docs/contributing/perf/prove-rebaseline.md` if a new re-baseline page is
  needed, following the 1.55.0 one.
- The VC count and SPARK level in the docs, via
  `python3 tools/update-proof-status.py` (item 3 changes them).
- `docs/proof/16.1.0-ledger.md` with the new unit and VC counts and with the
  classification of every subprogram item 3 leaves off.
- The baseline the item 2.7 gate is calibrated from, since the gate threshold
  is set at or just below the self-assessment figure this section measures.

---

## 6. Order of work and gates

| Step | Work | Gate |
|------|------|------|
| 1 | B4 parallelism diagnosis and fix | `make build` timing recorded, before and after |
| 2 | B1 split the manifest body; B2/B3 profiles | `make complexity-check`; benchmark pages state the profile |
| 3 | Scanner statement count (2.4) | `make test` |
| 4 | `spark-coverage` package, CLI, three metrics, gate | `make test`, `make cli-e2e`, `make action-parity-check`, `make docs-coverage-check` |
| 5 | Dashboard panel in the Proof tab, route, JS | `make csslint-check`, `make test`, Playwright e2e |
| 6 | SPARK opt-in sweep, one subprogram at a time, full queue | `make prove` clean, `make spark-off-check` |
| 7 | tldr page plus the pure-stdlib structural check | the structural check in `make check`; `make tldr-lint` when installed |
| 8 | prove-timing measurement and the phase decision; calibrate the gate | `make bench`, `python3 tools/update-proof-status.py` |
| 9 | docs, changelog, STE100 names, `make book` | every gate in `make check` |

The gate threshold in step 4 is added before it is calibrated in step 8.
Add it as a flag with the default at the current measured baseline, then
re-confirm it against the post-sweep figure in step 8.

`make check` runs end to end and must be green before the release. The
count-sync gates (`make test-count`, `make proof-status`, `make description`,
`make agents-tree`) run last, after tests and proofs settle.

## 7. Decisions taken

All planning questions are now answered. Each decision is recorded inline in
its section under **Decision**:

| # | Question | Decision |
|---|----------|----------|
| 1 | Coverage denominator | Report **all three metrics** (statements, subprograms, VCs), each labelled with its unit (2.3) |
| 2 | Dashboard placement | **Inside the existing Proof tab**; no ninth tab (2.6) |
| 3 | Build work scope | **All of B1-B4**, with B4 measured first (1.3) |
| 4 | SPARK sweep scope | **Full queue**, one subprogram at a time, easy wins ordered first (3.2) |
| 5 | tldr upstream PR | **In-repo only**, never upstream (4.1) |
| 6 | Coverage gate | **Ships with the feature**, not later (2.7) |
| 7 | Off-category breakdown | **Three sub-classes**: irreducible, I/O-bound, work queue (2.2) |
| 8 | Grouping | **Selectable**: `--group=file|folder|package` (2.3) |

### 7.1 What these decisions cost

Worth stating plainly, so none of them is a surprise later:

- **Three metrics** means the statement counter is mandatory work, not an
  option, and three denominators must stay consistent with each other. That is
  the single largest build cost the spark-coverage feature carries.
- **Full SPARK queue** means the prove-cold row will grow, and the item 5 phase
  decision has to absorb a real cost change rather than a flat one.
- **`-O1` development profile** creates a trap: it is tempting to benchmark on
  it, and any figure taken there does not belong in the phase table.
- **`-g` dropped from release** changes the recorded stripped-binary size, so
  that figure has to be re-measured and the docs updated.
- **In-repo tldr only** means the page never reaches tldr clients. That is the
  accepted trade for not blocking the release on an external review queue.