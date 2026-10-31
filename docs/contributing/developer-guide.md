# Contributor guide: codebase structure and setup

This page is a human-readable tour of the adacovex codebase for people who want
to build, test, or modify it. It supplements
[CONTRIBUTING.md](https://github.com/bladeacer/adacovex/blob/main/CONTRIBUTING.md) (process, changelog format, PR rules).
This page is about **how the code is organised and how to get a working
development environment**. `AGENTS.md` is the machine-facing version of the
same information.

## Setting up the repository

Prerequisites:

- **Alire** >= 2.0 (`alr`) -- the Ada package manager. It downloads and manages
  the GNAT toolchain for you.
- **GNAT** Ada compiler -- managed by Alire (`alr` pulls `gnat_native`).
- **Python 3** -- required at **build time** to bundle the dashboard and the
  offline manual into the binary (`tools/gen-dashboard.py` and
  `tools/gen-docs.py`). The docs bundle additionally needs `sphinx` +
  `myst-parser`; their single source is `pyproject.toml`
  (`[project].dependencies`), which `just requirements` renders into the
  committed `requirements.txt`. The shipped binary itself has no Python or
  other runtime dependency.
- **gnatprove** -- optional for *using* adacovex, required for `just prove`.
  It is resolved at run time (manifest pin, `$PATH`, cached toolchain, or
  download). It lives in the dev manifest, never the published one.

```bash
git clone https://github.com/bladeacer/adacovex.git
cd adacovex
just build        # compiles bin/adacovex + bin/test_runner (covex alias)
just test         # builds + runs the native test suite (2060 tests)
just run-self     # assess adacovex itself: 100% docs, Gold, DAL-C
just prove        # SPARK proof (full-proof gate) + regenerates docs/badges/
just check        # the whole quality gate CI runs before a release
```

`just` is the task runner (`just --list` lists every recipe). The `Makefile`
is a thin shim that delegates to the same Python tasks, so an existing
`make <task>` reference still works.

### Host-side toolchain caches

A cold host pays for its toolchain once, outside the tree. The first
`alr build` fetches the Alire toolchain into
`~/.local/share/alire/toolchains/`: `gnat_native` (990 MB unpacked) and
`gprbuild` (278 MB). The dev-manifest commands fetch their binary crates
into `~/.local/share/alire/releases/`: `gnatdoc_bin` (139 MB) for
`just doc`, `gnatformat_bin` (53 MB) for `just fmt`, and `gnatprove`
(1.3 GB) for the proof tools. The `prove` subcommand's own download keeps
a second copy under `~/.local/share/adacovex/toolchain/`.

Nothing in that list is a build dependency of the crate itself. The
published `alire.toml` declares no dependencies, and the committed
`alire/alire.lock` carries an empty solution, so a cold `just build`
fetches nothing once the Alire toolchain exists. Its whole workspace sync
measures 301 ms inside a 0.3 s no-op `alr build`. The measured cold-build
phases are on [Pipeline and prove timings](perf/benchmarks-timings.md).

### The Python tooling environment

The docs toolchain (Sphinx, MyST, Furo) lives in `.venv`. Its dependency
list has one source: `pyproject.toml` (`[project].dependencies`).
`requirements.txt` is generated from that table by
`python3 tools/update-requirements.py` and stays committed, because
`.readthedocs.yaml` (`python.install`) and `pip install -r` read it.

Edit `pyproject.toml`, then run `just requirements` to regenerate the
rendered file. The `requirements sync` gate in `just check` runs the
same generator in `--check` mode and fails when the two drift, so a hand
edit of `requirements.txt` never survives a gate run.

When `.venv` is missing, `just docs-venv` bootstraps it in a fixed
order:

1. `uv`, when it is on `PATH` (`uv venv --python 3.13`, then
   `uv pip install`);
2. the project's `install.sh --python-venv`, which creates the venv and
   installs `requirements.txt` into it;
3. `python3 -m venv`, then `pip install -r requirements.txt`.

The venv path stays absolute in every recipe: a Python 3.13 interpreter
started from a relative `.venv` reports a relative `sys.prefix`, and
`<frozen site>` then prints a `RuntimeWarning` about it. On Windows the
recipes pick `.venv/Scripts` instead of `.venv/bin`.

`just check` is the pre-commit gate. It runs `fmt` first, because gnatprove
and the API docs both read the sources and every later gate must see
formatted code. It then runs cheap static checks (ASCII, SPARK_Mode-Off
policy, changelog format, version source, doc-links, markdown links), then
build, tests, proof, docs, and SBOM, and finishes with the tree-wide
count-sync checks.

Every gate runs a preflight before it runs. A gate whose tool is missing on
the host is skipped with the reason instead of failing: no `alr` on `PATH`,
no `gnatformat` on the developer path, a `gnatdoc` that cannot document a
one-package probe project, no `sphinx` in the interpreter. The run continues
past a failed gate. It prints a PASS/FAIL/SKIP summary and exits non-zero
only when a gate failed.

**`gnatformat` has no Windows binary.** The `fmt` gate resolves
`gnatformat_bin` through the dev manifest, and the Alire community index
carries no Windows build of it, so `just fmt` and the `fmt` step of
`just check` SKIP on a Windows host with the reason "gnatformat is not
available in the dev toolchain". The formatting itself is unchanged: the
gate still runs on Linux and on the CI Linux runners, and a Windows
developer runs `just check` with `fmt` skipped and the rest of the gate
still verifies the tree. If a Windows binary of `gnatformat` ships in a
later Alire index, the gate picks it up automatically.

Everything must pass. The sync checks fail loudly when a count in any documentation file is stale.

The repository layout, the execution pipeline, where a change belongs, and
the generated artifacts are on [Contributor guide: repository layout and
generated artifacts](developer-guide-layout.md).

## Testing

The test suite is native and zero-dependency. `src/tests/` holds one file per category (scanner, config, types, renderers, SBOM, VCS, and more). Each file exposes a `Run (R : in out Runner'Class)` procedure wired into `src/tests/test_runner.adb`. A test is a `R. Check (Condition, "Description")` call.

The runner counts them, prints a per-category table, and writes `docs/test_result.md`.

```ada
-- src/tests/adacovex_scanner_tests.adb (pattern to follow)
Adacovex.Parsers.Source.Scan_Ads_File (Tmp_File, Pkg, Success);
R.Check (Success, "Test 1: parse succeeded");
```

After adding or removing tests:

```bash
just test          # rebuild + run; rewrites docs/test_result.md
just test-count    # sync every anchored count across the repo (AGENTS.md,
                   # README, Makefile, CI workflows, manifests, agents-tree.map)
```

The count-sync is enforced by `just check`. A test change that skips the sync fails the gate. Tests write to `/tmp` scratch dirs and clean up after themselves. The default on-disk result cache (`<cache>`) is shared.

Tests that exercise caching use content-hashed keys. They never depend on each other's state.

The CLI end-to-end suite (`just cli-e2e`, `tests/e2e/cli_flags.py`) runs the
real binary and checks the shorthands, the long aliases, the `--standard`
tier tokens, the reject paths, the `complexity` subcommand (its pass and
fail gates, `--excludes`, and `--skip-path`), the VCS differential modes
(`--compare-base` / `--coverage-delta`, every alias, a docstring-coverage
regression, and the not-a-repository failure), the `prove` subcommand (its
`-t`/`-l`/`-j` shorthands, the accepted option set, and the range and
subcommand reject paths), and the serve `--theme` values and `-p` port
forms. It needs no browser and runs inside `just check`.
The differential checks skip themselves when `git` is missing. The browser
suite (`just e2e`) adds the Playwright dashboard layout tests on top.

## Documentation and dashboard tooling

The pure-stdlib Python gates keep the docs and the dashboard in step with
the code. They are the drop-in replacements for the npm tools (stylelint,
and more) that a JavaScript toolchain would use; adacovex keeps its dev
tooling Python-only by convention:

- `tools/csslint.py` (`just csslint-check`) enforces the 4px spacing rule:
  every `margin`, `padding`, and `gap` pixel length is a multiple of 4px.
  It runs inside `just build` and `just check`.
- `tools/check-docs.py` (`just docs-check`) fails when any paragraph in the
  user docs, README, or human changelogs exceeds four sentences, and it
  rejects em dashes and Latin abbreviations (`i.e.`, `e.g.`, `etc.`). It also
  enforces one space after a sentence in the docs, the changelogs, the root
  `AGENTS.md` and `CONTRIBUTING.md`, and the Ada comment text under `src/`
  (a `.`, `!`, or `?` followed by two or more spaces and more text);
  `python3 tools/check-docs.py --fix` collapses the gap in exactly those
  places and never touches Ada code.
  `tools/para-split.py` rewraps over-long paragraphs to comply. Pages are
  also kept under 250 lines; a page that is a reference dictionary or a
  historical record may opt out of the line cap (never the paragraph rule)
  with a `no-covex-docs-loc` HTML comment near the top of the file.
- `tools/gen-dashboard.py` bundles the dashboard resources into
  `src/adacovex-dashboard_template.ads` and minifies the authored CSS and
  JavaScript (comments stripped, whitespace collapsed) before inlining.

Edit the dashboard under `resources/`, never the generated template. After
any docs or resource change, run `just docs-check` and `just csslint-check`
before committing.

## SPARK proof discipline

`just prove` runs gnatprove through the `prove` subcommand and enforces the
full-proof gate: **0 unproved VCs and 0 justified VCs**. The rules that keep
the proof tractable:

- Every user assertion and every runtime check must be proved.
- No `pragma Assume` / `pragma Annotate` justifications.
- No `pragma SPARK_Mode (Off)` anywhere except `Types.Implementation` and
  `Complexity` (the two non-formal-`Ada.Containers` packages. Non-formal
  `Ada.Containers` are illegal in SPARK_Mode-On code -- gnatprove rejects
  them; the evidence is in `docs/proof/16.1.0-ledger.md`. `just
  spark-off-check` enforces this.
- I/O- and container-heavy units are default-off bodies or carry per-subprogram
  `SPARK_Mode => On` aspects. They never carry an explicit Off pragma.

The proof result is anchored in `docs/proof/` (the per-version VC ledger).
`just proof-status` syncs the VC count and SPARK level into the docs.

## Common workflows

- **Assess another project**: `adacovex --target=PATH --dal=C` (see
  [Target projects](../usage/target-projects.md)).
- **Dogfood**: `just run-self` (adacovex against itself) and `just
  run-ada-crdt` (against the sibling `../Ada_CRDT` checkout, strict mode). Both
  must stay green.
- **Coverage gate between releases**: `just coverage-gate` compares docstring
  coverage between the latest two release tags.
- **Prepare a release**: `VERSION=x.y.z just bump-version`, write the changelog
  (`docs/changelogs/adacovex-x.y.z.md`, canonical format enforced by `just
  changelog-check`), then `VERSION=x.y.z just release`. The release builds the
  release binary and checks that it reports the tag before it proves anything,
  so the proof pass, the result cache, and every committed artifact come from
  the binary being released. Run `just check` first: its
  `version-consistency-check` gate fails when a manifest, the version spec,
  the binary, or the committed SBOM names a different version.
- **Keep docs current**: every code change updates the relevant user docs,
  the Ada docstrings that feed `docs/api-docs`, and the changelog, then
  re-runs the sync gates (`just docs-check`, `just action-parity-check`,
  `just surface-parity-check`, `just agents-tree`, `just doc-links`,
  `just link-check`). Stale docs are a release blocker.
- **Debug**: `adacovex --verbose` prints pipeline step diagnostics. `adacovex
  status` reports toolchain + platform state. `--no-cache` bypasses the
  on-disk result cache when inputs changed without content changing.

## Related pages

- [CLI reference](../usage/cli-reference.md) -- every flag and its defaults
- [Architecture](architecture.md) -- design decisions, the overflow contract,
  the patch system, result caching
- [Standards](../usage/standards.md) -- the DO-178C, ISO 26262, and IEC 62304
  compliance model
- [API reference](../api-docs/index.md) -- generated package docs and the
  reference pages (docstring spec, test formats, SPARK/DAL/ASIL/Class levels)
- [CONTRIBUTING.md](https://github.com/bladeacer/adacovex/blob/main/CONTRIBUTING.md) -- contribution process and changelog format
