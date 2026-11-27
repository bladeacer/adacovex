# adacovex 1.76.0

Date: _2026-11-27_

Version bumped 1.75.0 -> 1.76.0.

## Changes

### C1: The base `--help` fits one screen and groups its flags

The base `--help` is a 50-line summary under seven task headings: Assess,
Report, Prove, Cache and scope, CI gates, Differential and SBOM, and More
detail. A user who wants the full text of one flag reaches it through
`adacovex help TOPIC`, `adacovex TOPIC --help`, or the man page, and the
footer names both routes.

`-h` equals `--help` in every position, including after a subcommand, so
`prove -h` selects the prove frame. `help <topic>` and `<subcommand> --help`
stay byte-identical, and a help request exits 0.

### C2: One option table renders the console frame and the man page

The option text lives once, in `Adacovex.Cli_Help`, with a task group per
option. The console frame and the man page both render that table, so a
description has one source and the two surfaces cannot drift. Every
`Known_Flags` entry appears exactly once, and a test fails on an unknown
option or a missing group.

Every option on the man page now carries its own description, default,
example, and related flag. The stub description is gone, and the section
order follows the help groups.

### C3: The user documentation speaks to users first

`docs/usage/index.md` states the reading convention, and the usage pages
move build recipes, gate internals, fixture layout, and CI job wiring into
`> **For contributors:**` callouts at the point they are needed. The task
detail is kept, one level down, and each page names the user-facing
subcommand for the operation it describes.

The audit also corrected the help footer, which still called `--help` the
full option list, and the syft comparison, which still claimed no action
cataloguer exists.

### C4: The manual carries the full sample configuration

`docs/usage/configuration.md` now embeds the repository's complete
`adacovex.toml` between `config-sample` markers, with every key at its
default value. `tools/check-docs.py` fails when the block differs from the
committed file, so a key change cannot leave the manual behind.

The state directories, environment variables, and reset procedure moved to
`docs/usage/configuration-state.md`, which keeps the configuration reference
inside the line cap. `adacovex init` also writes the level, timeout, steps,
and memlimit keys now, so its scaffold states every supported key as the
page already promised.

### C5: A bare invocation asks for a target (breaking)

`adacovex` with no arguments prints the usage summary and exits 0, followed
by a hint that names `adacovex --target=.` as the exact replacement for the
old bare form. A run now names its target, its subcommand, or its flag.

This is a breaking change in behaviour only: no flag, output format, or exit
code changed, and `--target=.` reproduces the old assessment exactly. The
`prove` subcommand and `just prove` agree on level 4, and the sample
configuration, the configuration page, the tldr page, and the CLI reference
all state that default.

## Fixes

### H1: A warm walk shares one directory snapshot (D16)

The SPARK coverage walker now uses the shared skip predicate and the
directory memo, so it no longer enters `.venv`. The coverage summary line
reuses the rollup the level assessment already measured instead of walking
the tree a second time, and the vendor-hash discovery walk takes the memo.

A warm run reads 18 904 `newfstatat` calls and 378 ms against 282 020 calls
on the 1.75.0 binary for the same tree. `Skip_Walk_Dir` is in the
`Adacovex.Parsers.Manifest` spec, so a walker cannot keep a private copy.

## Test Suite

Native suite: 2606/2606 passing across 30 categories, 0 skips. The CLI
configuration category carries the grouped help snapshots, the `-h`
equivalence cases, and the bare-invocation and level-4 cases.

`just cli-e2e` passes 226 checks, including the one-screen frame, the group
headings, the bare-invocation hint, and the level-4 default in `prove
--help`. `just prove-e2e` passes 274 checks over 20 committed fixture
projects.

## Proof Results

The product changes touch the CLI parser, the man-page renderer, the SPARK
coverage walker, and the sample scaffold writer. No `SPARK_Mode (Off)`
pragma was added outside the two exempted packages.

The tree proves at the default budget (gnatprove 16.1.0: 1060 VCs, 0
unproved, 0 justified). Self-assessment: Gold, 100% docstrings, DAL-C
Achieved, ASIL B and Class A Achieved under `--standard=all`.

## Traceability

HLR-CLI: a bare invocation asks for a target and exits 0, `-h` equals
`--help` in every position, the base frame groups its flags, and the console
and man page render one option table.

HLR-SCAN: the SPARK coverage walker shares the skip predicate and the
directory snapshot, so a warm run reads the tree once.

HLR-PERF: the warm stat count returns to the tree's own size, and
`docs/stats/` records the figure the 1.76.0 session measured.

No product HLR changed for the documentation audience work, the embedded
sample, or the man-page wording; those changes keep the documented surface
and the gates in step.
