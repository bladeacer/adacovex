# adacovex 1.74.0

Date: _2026-11-21_

Version bumped 1.73.0 -> 1.74.0.

## Changes

### C1: The result cache uses the resolved project location

The cache identity is now the resolved filesystem location of the target, not
the spelling the caller used or the current directory. `Adacovex.Paths.Resolve`
expands `~`, makes a relative path absolute against the working directory,
folds `.` and `..`, and normalises separators. The scan, test, requirement,
dependency-graph, tool-probe, registry-metadata, and proof caches all read
that one identity. A run started in the project, its parent, or any other
directory therefore hits the same entries when the resolved project path is
the same.

Every entry carries a fixed header with a format tag and the entry's own write
time in OS seconds. A load strips the header, so a caller sees the bytes it
stored. The lifetime reads the header time, never the file mtime, because a CI
cache restore or a file copy rewrites mtime. Entries expire after 7 days by
default: `--cache-expiry=DAYS` or `[cache] expiry-days` sets the lifetime, and
zero means never expire.

Expiry runs before the `--cache-max` count cap, and oldest-first eviction reads
the same header time. `adacovex --cache-clear` removes every entry under the
resolved root, prints the path and the count, and exits 0. It refuses a
file-system root, the home directory, and an empty path. `Cache_Schema` is
`s12`; entries without a header are never read.

### C2: The proof cache records one entry per unit

`Adacovex.Prove_Units` gives every proof unit its own entry under the
`proveunit:` namespace. A unit key covers the unit's resolved path, its
content, the content of the units its `with` closure names, the gnatprove
options, and the prover identity. A one-unit edit invalidates that unit and
the units that depend on it; every other unit entry stays a hit. The run
reports the split as `N/M unit(s) hit` on a warm run and as
`N/M unit(s) hit, K changed` before a re-prove.

The whole-run `prove:` entry stays the correctness gate. gnatprove proves a
project in one invocation, so a partial edit still runs it once; its own
session store re-analyses only the changed units. The unit entries record
which units the cached proof covers, and a warm run restores the complete
`gnatprove.out` and `gnatprove.sarif` pair through the whole-run entry.

### C3: `prove`, `sbom`, and a plain assessment share their entries

The SBOM and assessment paths use the same resolved target as `prove`. The
dependency-graph key, the tool-set key, the source-scan key, and the
registry-metadata key are all content-based, and the target is resolved once
before any cache is read. A relative `--target`, an absolute `--target`, and a
run started in the project directory therefore share the same graph, scan, and
probe entries. The SBOM e2e now runs from the parent directory and from the
project directory and asserts that the second run adds no cache entry and
reports the same result.

### C4: Every classified contract error has a fixture pair

The diagnostics matrix now marks every classified check kind as Supported. Six
broken/fixed fixture pairs join the committed contract-error projects:

- `predicate` reports a `predicate check`.
- `floating_point` reports a `float overflow check`.
- `subtype_conversion` reports the `range check` on a subtype conversion.
- `modular` reports the `range check` on a modular narrowing.
- `ghost_lemma` reports the `postcondition` of a ghost lemma.
- `aliasing` reports the flow error for overlapping subprogram parameters.

The `float` keyword now reaches the floating-point fix hint, and the matrix
lists the exact kind each fixture proves. The `prove` diagnostics e2e reads
the case list from the fixture directory, so a new pair runs without a second
registry. `just diagnostics-coverage-check` keeps the matrix, the hint
keywords, and the fixture directories in step.

### C5: adacovex-owned tool sets say "toolkit"

The adacovex cache, bundle, and environment variable now say **toolkit**
(`<data>/toolkit`, `ADACOVEX_TOOLKIT_URL`,
`adacovex-toolkit-<os>-<arch>.tar.gz`). Upstream tool sets keep their own
names: Alire, GNAT, gnatprove, and Go each publish a toolchain. The retired
`toolchain` directory and variable are not read; only the `toolkit` names are
live, so the first `prove` run after the upgrade deploys gnatprove once into
the new directory. Historical changelogs keep their factual upstream
references.

### C6: Documentation accuracy audit

The usage pages were checked against the parser, the server routes, the action
inputs, and the current output: flag names, defaults, exit codes, paths,
counts, versions, and examples. The contributor pages were checked against the
task runner and the gates. The audit restored the real Alire cache path
(`~/.local/share/alire/toolchains/`) after the terminology pass had changed it,
and replaced the stale 32-gate, 38.77 s check reference with the v1.74.0 run
(34 gates, 37 s). Every link, docs-coverage, action-parity, and
surface-parity gate passes.

### C7: The Python and test scripts have one job per module

`tools/tasks.py` is the entry point and task registry; the implementation
lives in `tools/taskkit/` (`common`, `build`, `gates`, `e2e`, `release`, and
`checks`). `tools/tests.py` is a thin runner; the domains live in
`tools/test_release.py`, `tools/test_docs_generation.py`,
`tools/test_docs_gates.py`, `tools/test_tasks.py`, and `tools/test_misc.py`,
with shared helpers in `tools/testsupport.py`. The CLI e2e registry lives in
`src/tests/e2e/cli/cli_flags.py`, with the shared helpers in `cli_support.py`
and the check groups in `checks_basic`, `checks_sbom`, `checks_serve`,
`checks_config`, and `checks_prove`. The dependency rule is unchanged:
standard library only, `typing` annotations, `argparse` for a CLI, and
`pathlib` for paths.

### C8: The complexity gate scans every SBOM language

The complexity scanner uses one extension-to-language table that mirrors
`Adacovex.Parsers.Manifest.Extension_Language`, plus the data and prose
formats the gate owns (YAML, JSON, TOML, XML, Markdown, reStructuredText, and
`.jsx`). `Adacovex.Complexity.Language_Of` is the single source of truth for
scanning, reporting, and the tests. A `.swift`, `.scala`, `.lua`, or `.vhdl`
file is no longer invisible to the LOC and decision gates. Per-subprogram
analysis stays Ada-only; every other language contributes file-level LOC and
decision counts.

## Fixes

### H1: Cache paths stay where v1.71.0 put them

The v1.74.0 audit pinned the live layout: the result-cache root
(`<cache>/<version>/<schema>`), the stat-stamp index
(`<cache>/stamps/index.bin`), the tool-probe store (`<cache>/probes/<tool>.v2`),
and the registry-metadata store (`<data>/meta/<hash>`). Only the toolkit
directory moved, by decision. The audit also fixed two stale test assumptions:
the cache suite still built a per-file stamp path retired since 1.44.0, and it
recorded a registry-meta entry in the result cache rather than in
`<data>/meta/`. The prove help and man page no longer say "cached toolchain"
for the adacovex-owned cache.

## Test Suite

Native suite: 2468/2468 passing across 30 categories. The `GNATprove parser`
category grew from 88 to 93 checks with the per-unit key tests: two spellings
of one target agree, an edited unit and its dependent both change, and a
different prover identity changes every key.

`just cli-e2e` passes 179 of 180 checks; one skips on this host. The cache
group adds the SBOM working-directory equivalence (no new entry, same result)
to its existing resolved-key, lifetime, 31/1 one-edit split, and clear checks. `just prove-e2e` passes 274 checks over 20 committed
fixture projects, up from 132 over 14.

## Proof Results

The product change adds `Adacovex.Prove_Units` and touches the prove runner,
the diagnostics hint table, and the cache documentation. `Prove_Units` is an
I/O-heavy unit with no `SPARK_Mode (On)` contract surface, and no
`SPARK_Mode (Off)` pragma was added outside the two exempted packages.

The tree proves at the default budget (gnatprove 16.1.0: 1058 VCs, 0 unproved,
0 justified, 78 analysed units). Self-assessment: Gold, 100% docstrings, DAL-C
Achieved, ASIL B and Class A Achieved under `--standard=all`.

## Traceability

HLR-CACHE: The cache key is the resolved project location, each proof unit has
its own `proveunit:` entry, entries expire from their header time, and
`--cache-clear` removes only the configured root.

HLR-PROVE: The diagnostics matrix now covers every classified check kind with
a broken/fixed fixture pair, and the prove e2e reads the fixture directory
instead of a second hand-written list.

No product HLR changed for the terminology, documentation-audit, script-layout,
or complexity-language work; those changes keep the documented surface and the
gates in step.
