# Contributor guide: codebase structure and setup

This page is a human-readable tour of the adacovex codebase for people who
want to build, test, or modify it. It supplements
[CONTRIBUTING.md](../CONTRIBUTING.md) (process, changelog format, PR rules);
this page is about **how the code is organized and how to get a working
development environment**. `AGENTS.md` is the machine-facing version of the
same information.

## Setting up the repository

Prerequisites:

- **Alire** >= 2.0 (`alr`) -- the Ada package manager; it downloads and
  manages the GNAT toolchain for you.
- **GNAT** Ada compiler -- managed by Alire (`alr` pulls `gnat_native`).
- **Python 3** -- only for build/dev tooling (`tools/*.py`); the shipped
  binary has no Python dependency.
- **gnatprove** -- optional for *using* adacovex, required for `make prove`.
  It is resolved at run time (manifest pin, `$PATH`, cached toolchain, or
  download) and lives in the dev manifest, never the published one.

```bash
git clone https://github.com/bladeacer/adacovex.git
cd adacovex
make build        # compiles bin/adacovex + bin/test_runner (covex alias)
make test         # builds + runs the native test suite (850 tests)
make run-self     # assess adacovex itself: 100% docs, Platinum, DAL-C
make prove        # SPARK proof (Platinum gate) + regenerates docs/badges/
make check        # the whole quality gate CI runs before a release
```

`make check` is the pre-commit gate: cheap static checks first (ASCII,
SPARK_Mode-Off policy, changelog format, version source, doc-links, markdown
links), then build + tests + proof + docs + SBOM, then tree-wide count-sync
checks. Everything must pass; the sync checks fail loudly when a count in any
documentation file is stale.

## Repository tour

```
src/
|-- adacovex_main.adb              -- CLI entry point: parse -> pipeline -> render -> exit
|-- adacovex.ads                   -- Version constant
|-- core/                          -- config parsing, types, cache, VCS, GNATprove runner, diff
|-- parsers/                       -- input parsing: Ada source, gnatprove.out, tests, manifest, HLR/LLR
|-- renderers/                     -- output: ANSI, HTML dashboard, Markdown, SVG badges, SBOM, man page
|-- compliance/                    -- DO-178C DAL assessment logic
|-- server/                        -- HTTP/1.1 server (4-worker task pool) for --serve
|-- ir/                            -- bounded IR types + future-use synthesiser
`-- tests/                         -- the native test suite (test_runner entry point)
resources/dashboard.html           -- the served dashboard's page shell (plain HTML, bundled at build time)
tools/*.py                         -- pure-stdlib Python: doc sync, count sync, generators, validators
docs/                              -- all documentation (this guide, CLI reference, standards, ...)
```

The **execution pipeline** (`adacovex_main.adb`) is the spine of the tool:

```
parse CLI -> scan .ads sources -> apply docstring patches -> compute doc metrics
-> parse gnatprove.out -> parse test results -> assess DAL -> render ANSI report
-> emit SVG badges -> emit Markdown reports -> emit SBOM -> serve dashboard (if --serve)
-> exit code (0 = Achieved)
```

A handful of modes exit before the pipeline: `--help`, `--version`, `man`,
`status`, the differential modes (`--compare-base` / `--coverage-delta`), and
`sbom`.

### Where things live

| You want to... | Look at |
|----------------|---------|
| Understand the CLI flags | `src/core/adacovex-config.ads/.adb` (parser + `help` topics) |
| Add a new flag | Parse it in `adacovex-config.adb`, store it in `CLI_Config`, add a contextual `help` topic |
| Change source scanning | `src/parsers/adacovex-parsers-source.ads/.adb` |
| Add a parser for a new input | New file under `src/parsers/`, wired into the pipeline in `adacovex_main.adb` |
| Add an output format | New renderer under `src/renderers/`, called from the pipeline |
| Change the dashboard page | Edit `resources/dashboard.html` (plain HTML/CSS/JS), then run `tools/gen-dashboard.py` to regenerate `src/adacovex-dashboard_template.ads` |
| Change assessment criteria | `src/compliance/adacovex-compliance-dal.adb` (+ the DAL levels doc) |
| Add tests | `src/tests/` -- see below |
| Regenerate API docs | `make doc` (gnatdoc -> `tools/rst2md.py` -> `docs/api-docs/`) |
| Sync test counts | `make test-count` (reads `docs/test_result.md`, rewrites every anchored count) |
| Sync proof metrics | `make proof-status` |
| Regenerate AGENTS.md blocks | `make agents-tree` (src tree) and `make doc-links` (docs list) |
| Verify markdown links | `make link-check` |

### API docs and cross-links

`make doc` regenerates `docs/api-docs/` from the `.ads` docstrings via
gnatdoc + `tools/rst2md.py`: one page per package plus `index.md`. The six
hand-written reference pages (docstring spec, test formats, SPARK levels, and
the DAL / ASIL / Class level pages) are never regenerated. Cross-links
between the generated package pages and the reference pages live in
`tools/rst2md.py` -- `GUIDE_PAGES` (the index's "Guides" section) and
`PACKAGE_GUIDES` (the per-package "See also" lines) -- **not** in the `.ads`
comments: gnatdoc parses comment text as RST and drops markdown link URLs.
To add a package cross-link, extend `PACKAGE_GUIDES` in `tools/rst2md.py`,
then run `make doc` and `make link-check`.

## Testing

The test suite is native and zero-dependency: `src/tests/` holds one file per
category (scanner, config, types, renderers, SBOM, VCS, ...), each exposing a
`Run (R : in out Runner'Class)` procedure wired into `src/tests/test_runner.adb`.
A test is a `R.Check (Condition, "Description")` call; the runner counts them,
prints a per-category table, and writes `docs/test_result.md`.

```ada
-- src/tests/adacovex_scanner_tests.adb (pattern to follow)
Adacovex.Parsers.Source.Scan_Ads_File (Tmp_File, Pkg, Success);
R.Check (Success, "Test 1: parse succeeded");
```

After adding or removing tests:

```bash
make test          # rebuild + run; rewrites docs/test_result.md
make test-count    # sync every anchored count across the repo (AGENTS.md,
                   # README, Makefile, CI workflows, manifests, agents-tree.map)
```

The count-sync is enforced by `make check`, so a test change that skips the
sync fails the gate. Tests write to `/tmp` scratch dirs and clean up after
themselves; the default on-disk result cache (`~/.adacovex/cache`) is shared,
so tests that exercise caching use content-hashed keys and never depend on
each other's state.

## SPARK proof discipline

`make prove` runs gnatprove through the `prove` subcommand and enforces the
Platinum gate: **0 unproved VCs and 0 justified VCs**. The rules that keep
the proof tractable:

- Every user assertion and every runtime check must be proved.
- No `pragma Assume` / `pragma Annotate` justifications.
- No `pragma SPARK_Mode (Off)` anywhere except `Types.Implementation` (the
  non-SPARK container package; non-formal `Ada.Containers` are illegal in
  SPARK_Mode-On code). `make spark-off-check` enforces this.
- I/O- and container-heavy units are default-off bodies or carry
  per-subprogram `SPARK_Mode => On` aspects; they never carry an explicit
  Off pragma.

The proof result is anchored in `docs/proof/` (the per-version VC ledger) and
`make proof-status` syncs the VC count and SPARK level into the docs.

## Common workflows

- **Assess another project**: `adacovex --target=PATH --dal=C` (see
  [Target projects](target-projects.md)).
- **Dogfood**: `make run-self` (adacovex against itself) and
  `make run-ada-crdt` (against the sibling `../Ada_CRDT` checkout, strict
  mode). Both must stay green.
- **Coverage gate between releases**: `make coverage-gate` compares docstring
  coverage between the latest two release tags.
- **Prepare a release**: `make bump-version VERSION=x.y.z`, write the
  changelog (`docs/changelogs/adacovex-x.y.z.md`, canonical format enforced
  by `make changelog-check`), then `make release VERSION=x.y.z`.
- **Debug**: `adacovex --verbose` prints pipeline step diagnostics;
  `adacovex status` reports toolchain + platform state; `--no-cache` bypasses
  the on-disk result cache when inputs changed without content changing.

## Related pages

- [CLI reference](cli-reference.md) -- every flag and its defaults
- [Architecture](architecture.md) -- design decisions, the overflow contract,
  the patch system, result caching
- [Standards](standards.md) -- the DO-178C / ISO 26262 / IEC 62304
  compliance model
- [API reference](api-docs/index.md) -- generated package docs and the
  reference pages (docstring spec, test formats, SPARK/DAL/ASIL/Class levels)
- [CONTRIBUTING.md](../CONTRIBUTING.md) -- contribution process and changelog format
