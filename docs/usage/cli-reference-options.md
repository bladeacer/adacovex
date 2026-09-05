# CLI flag details: output, serving, and CI options

This page details the output and serving flags (`--no-sbom`, `--serve`, `--emit-*`), the differential assessment flags, VCS support, the CI threshold gates (`--require-*`), result caching, `--verbose`, and `--help`.  The flag summary table and worked examples are on the [CLI reference](cli-reference.md); the assessment flags and subcommands are on [CLI flag details: assessment flags and subcommands](cli-reference-flags.md).

### Automatic SBOM (`--no-sbom` / `--sbom-format`)

Every assessment writes a proof-aware SBOM by default (the pipeline's last
step): `<target>/sbom.json` (CycloneDX 1.5), `<target>/sbom.spdx.json`
(SPDX 2.3), or `<target>/docs/compliance/SBOM.md` depending on
`--sbom-format` (default `cyclonedx-json`). `--no-sbom` skips it entirely.
These are separate from the dedicated [`sbom` subcommand](sbom.md), which
writes a single SBOM at an explicit path and exits.

### `--serve`

A **switch**: when given, adacovex scans and assesses the target, then starts the built-in HTTP/1.1 web dashboard on `--port` (default `8080`) and blocks until interrupted. Passing `--serve` is the only way to start the server; omitting it (the default, `off`) renders and exits without serving. There is no `--no-serve`, because the flag already controls it. It serves an HTML dashboard at `/`, a JSON API at `/api/metrics`, the SVG badges at `/badge/*.svg`, and the bundled offline manual at `/docs`.

The dashboard is standard-aware (it defaults to all standards) and supports light, dark, and system themes.

Full detail, the JSON schema, the theme-resolution order, and embedding tips are in [Web dashboard and JSON API](dashboard.md). Related flags: `--port`, `--serve-workers`, `--theme`.

### `--theme=NAME`

Dashboard colour theme for `--serve`: `system` (default, follows `prefers-color-scheme`), `light`, or `dark` (case-insensitive). It sets the initial dropdown selection in the served page. The header dropdown can switch live afterwards, and **Save settings** persists the choice in `localStorage` (no cookies). Only relevant with `--serve`.

See [dashboard themes](dashboard-api.md#themes).

### `--port=N`

HTTP server port when `--serve` is used. Must be a valid `Positive` integer.
Only relevant with `--serve`.

### `--serve-workers=N`

HTTP server task-pool worker count when `--serve` is used. Default is `4`.
Raise it to handle more concurrent dashboard requests, or lower it to use
less memory. It must be a valid `Positive` integer and only works with
`--serve`.

### `--tz=ZONE` / `--timezone=ZONE`

Display timezone for the status report.  Accepts a well-known IANA name
(for example `Asia/Singapore`) or a fixed UTC/GMT offset (`UTC+8`, `GMT+8`,
`UTC+08`, `GMT+08`, `UTC+08:30`).  Without it adacovex uses the operating
system's timezone.

A named zone resolves from a built-in table of common IANA names.  A zone
that may observe daylight saving time, or one the table lacks, is probed
against the platform tzdata (`zdump` + `date +%z`) for the DST-correct
current offset, with the table as the fallback when the probe is
unavailable.  Values are matched case-insensitively, and a bad value fails
loudly.

### `--emit-svg=PATH`

Write SVG badges to a directory. Default `<target>/docs/badges`
(project-scoped). Creates:

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
`{"metrics": {...}, "dependencies": {...}}`.  `metrics` is the same
object the dashboard JSON API serves at `/api/metrics`.  `dependencies` is
the resolved dependency graph (name, version, scope, parent, purl, kind) at
`/api/deps`.  It is useful for scripting gates, external dashboards, or
archiving assessment results. The composite GitHub Action uploads it as a CI
artifact when `emit-metrics` is set.

### `--emit-markdown=PATH`

Write compliance reports to a directory. Creates two files:

- `VERIFICATION.md` -- full verification report with all metrics
- `TRACE.md` -- HLR traceability matrix (source-to-requirement mapping)

### `--skip-dir=NAME`

Add a directory name to the scanner's skip list (repeatable). Directories whose
simple name matches an entry are not recursed into during source scanning.
Only effective in relaxed mode. In strict mode (default) the skip list is
always empty.

### `--relaxed`

Disable strict mode. Enables the skip list (default `demo,deps,examples` plus
any `--skip-dir` entries) and does NOT apply `.adacovex/patches/`. See
[Strict vs relaxed mode](#strict-vs-relaxed-mode).

### `--compare-base=REF`

Differential mode: snapshot a base revision and print a side-by-side comparison against the current tree (packages, subprograms, docstring %, HLR traced, orphan tags, SPARK level, VCs proved, tests, DAL status). Exit `0` only if there are no regressions AND the current DAL is Achieved. Exit `1` otherwise. Works on **git, Mercurial, Subversion, Fossil, and jj**.

Full detail and the per-VCS snapshot mechanisms are in [VCS support and differential assessment](vcs.md).

### `--coverage-delta=REF`

Lightweight docstring-coverage gate for PR-style CI checks. Scans sources + patches + computes docstring metrics on both a base revision and the current tree (no GNATprove/tests/DAL), prints a compact coverage table plus a machine-parseable `coverage_delta:` line, and cleans up the snapshot. Exit `0` if current docstring coverage is `>=` the base. Exit `1` if coverage regressed.

Mutually exclusive with `--compare-base`. See [VCS support and differential assessment](vcs.md).

### `--version`

Print the bundled version (`adacovex vX. Y. Z`) and exit, without scanning or assessing. The version source depends on the **installation method** (`ADACOVEX_VERSION` for release builds, `alire-dev.toml` for source checkouts, `alire.toml` for dependency-managed installs).

The same constant drives the man page, the SBOM tool version, and the result-cache namespace. As a result, they cannot drift. Full detail: [Installation -- version source](installation.md#version-source-per-installation-method).

### `completion`

`adacovex completion [SHELL]` (also `adacovex --completion[=SHELL]`) prints
a static shell-completion script to stdout and exits.  `SHELL` is one of
`bash`, `fish`, `zsh`, `pwsh`, when omitted it is auto-detected from
`$SHELL`, falling back to bash for unknown or empty shells.  Typical setup:

```bash
eval "$(adacovex completion)"        # bash (default)
source <(adacovex completion zsh)    # zsh
adacovex completion fish | source    # fish
adacovex completion pwsh | Invoke-Expression   # PowerShell
```

The scripts complete the subcommands and every long flag from the binary's
own flag table, so the completion set cannot drift from the CLI. The flag
list embeds at generation time. Re-run `adacovex completion` after upgrading
adacovex (a shell prompt hook that regenerates on version change works well).

### `man`

The `man` subcommand installs the adacovex man page into the **local man
database** (Linux/WSL, no root required) and refreshes the index with `mandb`
when present. `adacovex man --check` exits 0 when the installed page matches
the binary. It exits 1 otherwise (a shell prompt hook can auto-update as a
result). `--dir=PATH` overrides the install root. Full detail, exit codes,
and the prompt-hook recipe are in
[Installation -- keeping the man page in sync](installation.md#keeping-the-man-page-in-sync).

### VCS support

**A version control system is not required for base adacovex functionality**
(scanning, proof analysis, test parsing, compliance assessment, SBOM generation, dashboards, caching). A VCS is only needed for the differential modes (`--compare-base` / `--coverage-delta`). Those modes snapshot a base revision across **git, Mercurial, Subversion, Fossil, and jj** without touching the working tree. Detection is marker-file based (`.git` / `.jj` / `.hg` / `.svn` / `.fslckout` / `_FOSSIL_`) with a command-probe fallback.

Full detail, the snapshot mechanism per VCS, and the Subversion/Fossil UX notes are in [VCS support and differential assessment](vcs.md).

### CI threshold gates (`--require-*`)

The four `--require-*` flags add explicit minimum-bar checks on top of the DAL
criteria. They are off by default. When set, the assessment fails loudly
(exit code `1`, with an explicit `CI GATE:` reason printed to the report) if the
target does not meet the required level:

```bash
adacovex --target=. --require-spark=Platinum --require-docstrings=100 \
         --require-tests=1235 --require-proof=100
```

- `require-spark` compares the honest assessed SPARK level (Stone..Platinum).
- `require-docstrings` and `require-proof` take a percentage (0-100).
- `require-tests` takes a count of passing tests.

CI that pins a gnatprove version (manifest or global `adacovex.toml` pin)
must set these to the values that version actually achieves. A stricter
prover can legitimately leave more VCs unproved. As a result, gate on the
results of the prover you pin.

### Result caching (`--cache` / `--no-cache` / `--cache-dir` / `--cache-max`)

adacovex persists parsed analysis results on disk, so unchanged inputs are not re-scanned, re-parsed, or re-proved. Every entry is keyed by a namespace prefix plus the SHA-256 of the artifact(s) it was derived from. An unchanged manifest/lockfile/.gpr set serves the cached dependency graph. Unchanged `compliance/HLR.md` and `compliance/LLR.md` serve the cached requirement parses. `--no-cache` bypasses it entirely. `--cache-dir` relocates it. `--cache-max` (default `4096`) caps entries before oldest-first eviction.

The ANSI report shows a `result cache: X hit(s), Y miss(es), Z evicted` line per run. Full design (schema namespace, eviction, overflow safety, `--target` normalization) is in [Architecture -- Result caching](../contributing/architecture.md#result-caching).

### `--verbose`

Print pipeline step diagnostics to stderr.

### `--help` and contextual `help`

`--help` prints all options, defaults, and examples to stdout, then exits. No
scanning or assessment is performed.

**Contextual help**: the `help` keyword prints flag/subcommand-specific text
instead of the full usage. The topic can be given in either order, with or
without the leading `--`:

```
adacovex help serve        # or: help --serve, --serve help
adacovex help standard     # standard / dal / asil / class
adacovex help sbom         # subcommands: sbom, prove, status, man
adacovex help theme        # every flag has a topic (port, target, ...)
adacovex help              # no topic: full usage
```

The topic is case-insensitive and an `=value` suffix is ignored
(`help --standard=all` == `help standard`). Unknown topics print the full
usage with an "Unknown topic" notice. Contextual help exits `0` and never
scans or assesses.
