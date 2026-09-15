# CLI flag details: emitted reports, scan scope, and differential modes

This page details the flags that write artifacts (the automatic SBOM and the
`--emit-*` family), the scan-scope flags (`--skip-dir`, `--relaxed`), and the
differential assessment modes (`--compare-base`, `--coverage-delta`) with
their VCS support. The serving, CI, and tool flags are on [CLI flag details:
serving, CI, and tool options](cli-reference-options.md); the flag summary
table is on the [CLI reference](cli-reference.md).

### Automatic SBOM (`--no-sbom` / `--sbom-format`)

Every assessment writes a proof-aware SBOM by default (the pipeline's last
step): `<target>/sbom.json` (CycloneDX 1.5), `<target>/sbom.spdx.json`
(SPDX 2.3), or `<target>/docs/compliance/SBOM.md` depending on
`--sbom-format` (default `cyclonedx-json`). `--no-sbom` skips it entirely.
These are separate from the dedicated [`sbom` subcommand](sbom.md), which
writes a single SBOM at an explicit path and exits.

### `--emit-svg[=PATH]`

Alias: `--svg-path=PATH`. Write SVG badges to a directory. Default
`<target>/docs/badges` (project-scoped). The value is optional: bare
`--emit-svg` uses the default directory. Creates:

- `spark.svg` -- SPARK assurance level (Stone through Platinum)
- `tests.svg` -- test pass/fail count
- `do178c.svg` / `iso26262.svg` / `iec62304.svg` -- compliance status for the
  selected standard (Achieved / Unmet), or all three with `--standard=all`
- `docs.svg` -- docstring coverage percentage

`--no-svg` overrides and disables SVG output entirely.

### `--no-svg`

Suppress all SVG badge output. Overrides `--emit-svg` if both are given.

### `--emit-metrics=PATH`

After the assessment, it writes a machine-readable JSON export to `PATH`:
`{"metrics": {...}, "dependencies": {...}}`. `metrics` is the same
object the dashboard JSON API serves at `/api/metrics`. `dependencies` is
the resolved dependency graph (name, version, scope, parent, purl, kind) at
`/api/deps`. It is useful for scripting gates, external dashboards, or
archiving assessment results. The composite GitHub Action uploads it as a CI
artifact when `emit-metrics` is set.

### `--emit-markdown[=PATH]`

Aliases: `--emit-md[=PATH]` and `--md-path=PATH`. Write compliance reports to
a directory (default `<target>/docs`; the value is optional, so bare
`--emit-md` uses the default). Creates two files:

- `VERIFICATION.md` -- full verification report with all metrics
- `TRACE.md` -- HLR traceability matrix (source-to-requirement mapping)

### `--no-md`

Suppress all Markdown report output. Overrides `--emit-markdown` /
`--emit-md` / `--md-path` if both are given.

### `--skip-dir=NAME`

Add a directory name to the scanner's skip list (repeatable). Directories whose
simple name matches an entry are not recursed into during source scanning.
Only effective in relaxed mode. In strict mode (default) the skip list is
always empty.

### `--relaxed`

Alias: the bare word `relaxed`. Disable strict mode. Enables the skip list
(default `demo,deps,examples` plus any `--skip-dir` entries) and does NOT
apply `.adacovex/patches/`. `--strict` re-enables strict mode. See
[Strict vs relaxed mode](cli-reference.md#strict-vs-relaxed-mode).

### `--compare-base=REF`

Aliases: `--diff=REF`, `--base=REF`, and `-b REF`.

Differential mode: snapshot a base revision and print a side-by-side
comparison against the current tree (packages, subprograms, docstring %, HLR traced, orphan tags, SPARK level, VCs proved, tests, DAL status). Exit `0` only if there are no regressions AND the current DAL is Achieved. Exit `1` otherwise. Works on **git, Mercurial, Subversion, Fossil, and jj**.

Full detail and the per-VCS snapshot mechanisms are in [VCS support and differential assessment](vcs.md).

### `--coverage-delta=REF`

Alias: `--delta=REF` (and `-d REF`).

Lightweight docstring-coverage gate for PR-style CI checks. Scans sources + patches + computes docstring metrics on both a base revision and the current tree (no GNATprove/tests/DAL), prints a compact coverage table plus a machine-parseable `coverage_delta:` line, and cleans up the snapshot. Exit `0` if current docstring coverage is `>=` the base. Exit `1` if coverage regressed.

Mutually exclusive with `--compare-base`. See [VCS support and differential assessment](vcs.md).

### VCS support

**A version control system is not required for base adacovex functionality**
(scanning, proof analysis, test parsing, compliance assessment, SBOM generation, dashboards, caching). A VCS is only needed for the differential modes (`--compare-base` / `--coverage-delta`). Those modes snapshot a base revision across **git, Mercurial, Subversion, Fossil, and jj** without touching the working tree. Detection is marker-file based (`.git` / `.jj` / `.hg` / `.svn` / `.fslckout` / `_FOSSIL_`) with a command-probe fallback.

Full detail, the snapshot mechanism per VCS, and the Subversion/Fossil UX notes are in [VCS support and differential assessment](vcs.md).
