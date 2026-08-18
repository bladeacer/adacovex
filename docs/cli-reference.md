# adacovex CLI Reference

## Usage

```
adacovex [options]
adacovex sbom [--format=cyclonedx-json|spdx-json] [--out=PATH]
           [--standard=NAME|--dal=LEVEL|--asil=LEVEL|--class=LEVEL]
adacovex prove [--target=PATH] [prove options]
adacovex status [--target=PATH]
adacovex man [--check] [--dir=PATH]
```

## Flags

| Flag | Default | Mode | Description |
|------|---------|------|-------------|
| `--target=PATH` | `.` (CWD) | both | Target project root directory |
| `--manifest=PATH` | auto-detected | both | Override project manifest path |
| `--dal=LEVEL` | `C` | both | DO-178C DAL level (A-E; also the shared rigor tier) |
| `--asil=LEVEL` | - | both | ISO 26262 level: `A`\|`B`\|`C`\|`D`\|`QM` |
| `--class=LEVEL` | - | both | IEC 62304 safety class: `A`\|`B`\|`C` |
| `--standard=NAME` | `do178c` | both | `do178c`\|`iso26262`\|`iec62304`\|`all` |
| `--serve` | off | both | Start HTTP dashboard server (standard-aware; light/dark/system themes) |
| `--theme=NAME` | `system` | serve | Dashboard theme: `light`\|`dark`\|`system` |
| `--port=N` | `8080` | serve | Dashboard server port |
| `--emit-svg=PATH` | `<target>/docs/badges` | both | Output directory for SVG badges |
| `--no-svg` | off | both | Suppress SVG badge output |
| `--emit-markdown=PATH` | off | both | Output directory for Markdown reports |
| `--skip-dir=NAME` | `demo,deps,examples` | relaxed | Directory name to skip (repeatable) |
| `--relaxed` | off | both | Disable strict mode (skip dirs, no patches) |
| `--compare-base=REF` | off | both | Differential mode vs a base rev (git/hg/svn/fossil/jj) |
| `--coverage-delta=REF` | off | both | Docstring-coverage gate vs a base rev (git/hg/svn/fossil/jj) |
| `--cache` | on | both | Enable on-disk result caching |
| `--no-cache` | off | both | Disable result caching (always re-scan/re-parse/re-prove) |
| `--cache-dir=PATH` | `~/.adacovex/cache/<ver>/<schema>` | both | Cache directory for analysis results |
| `--cache-max=N` | `4096` | both | Max cache entries before oldest-first eviction |
| `--require-spark=LVL` | off | both | Fail loudly (exit 1) if SPARK level < LVL (Stone..Platinum) |
| `--require-docstrings=PCT` | off | both | Fail loudly if docstring coverage < PCT% (0-100) |
| `--require-tests=N` | off | both | Fail loudly if passing test count < N |
| `--require-proof=PCT` | off | both | Fail loudly if proved-VC coverage < PCT% (0-100) |
| `--verbose` | off | both | Verbose diagnostics |
| `--version` | - | - | Print the bundled version and exit |
| `man` | - | - | Install the man page into the local man database |
| `man --check` | - | - | Exit 0 if the installed man page matches the binary version, 1 otherwise |
| `man --dir=PATH` | `~/.local/share/man` | - | Install the man page under `PATH/man1` instead |
| `--help` | - | both | Print usage and exit |

## Flag details

### `--target=PATH`

Project to analyze. Relative paths are resolved against the current working
directory to an absolute path. Determines the root directory for source
scanning, manifest detection, SVG badge output, and patch file resolution.
Default: current working directory.

### `--manifest=PATH`

Override the project manifest file. Auto-detected from
`<target>/alire-dev.toml` or `<target>/alire.toml` (dev first). The manifest
path is shown in stderr output and used by `adacovex sbom` to resolve the root
project metadata for the dependency graph.

### `--dal=LEVEL`

DO-178C DAL level (and the shared rigor tier): `A`, `B`, `C`, `D`, or `E`
(case-insensitive). Determines the minimum SPARK proof level required and the
specific criteria checked. This tier is shared across standards -- `--dal=C`
is DAL-C under DO-178C, ASIL B under ISO 26262, and safety Class A under
IEC 62304. See [DAL levels](api-docs/adacovex-dal-levels.md) and
[Standards](standards.md).

### `--asil=LEVEL`

ISO 26262 Automotive Safety Integrity Level: `A`, `B`, `C`, `D`, or `QM`
(case-insensitive). Sets the standard to `iso26262` and maps the ASIL level
to the shared rigor tier (ASIL D -> DAL A, ASIL C -> DAL B, ASIL B -> DAL C,
ASIL A -> DAL D, QM -> DAL E). `--asil=B` is therefore the clearest spelling
of "assess this project at ASIL B". See
[ASIL Levels](api-docs/adacovex-asil-levels.md).

### `--class=LEVEL`

IEC 62304 software safety class: `A`, `B`, or `C` (case-insensitive). Sets
the standard to `iec62304` and maps the class to the shared rigor tier
(Class C -> DAL A, Class B -> DAL B, Class A -> DAL C). `--class=A` is the
clearest spelling of "assess this project at safety Class A". See
[Safety Classes](api-docs/adacovex-class-levels.md).

### `--standard=NAME`

Select the compliance standard used to label the assessment (default
`do178c`). The evidence checks are identical across standards; only the
integrity-level names change in the report and badges:

- `do178c` -- DAL A--E (avionics)
- `iso26262` -- ASIL D / C / B / A / QM (automotive)
- `iec62304` -- Class C / B / A / no class (medical-device software)
- `all` -- run one assessment at the shared tier and emit badges/reports for
  every standard (`do178c.svg`, `iso26262.svg`, `iec62304.svg`)

Accepted case-insensitively, with or without the hyphen/space (`ISO-26262`,
`iec62304`, ...). See [Standards](standards.md) for the full tier mapping.

When both a dedicated level flag (`--asil` / `--class`) and `--standard` are
passed, the dedicated flag sets the standard and `--standard` is ignored for
labelling (last-write-wins per field); the shared tier is always whatever the
level flag (or `--dal`) resolved to.

### `status`

`adacovex status [--target=PATH]` reports toolchain + platform state without
running an assessment and without downloading or deploying anything:

- whether Alire (`alr`) is installed on `$PATH`;
- whether gnatprove is dependency-managed (target manifest pin) or detectable
  (global pin, on `$PATH`, or cached in `~/.adacovex/toolchain`);
- the host logical-CPU count, CI status, and resulting default `-j`
  parallelism;
- a **VCS report**: which VCS command-line tools are on `$PATH` for the
  differential modes (git, mercurial/`hg`, subversion/`svn`, fossil, jj, and
  the man-page tool `mandb`), the VCS detected for the target repository
  (see [VCS support](#vcs-support)), a note when the target's VCS tool is
  missing, and a note when man-db (`mandb`) is absent -- so you know up
  front that `adacovex man` can install the page but cannot refresh the
  man database;
- the release-note that the CI binary is Linux x86-64 only.

Exit `0` when a usable gnatprove is detectable without a download (and `alr`
is present whenever the deploy path is the only option), `1` otherwise. The
VCS report is informational and does not affect the exit code. See
[Platforms](platforms.md#status-subcommand).

### `--serve`

After scanning and assessment, start the built-in HTTP/1.1 web dashboard on
`--port` (default `8080`):

- `GET /` -- HTML dashboard with coverage, proof, test, and compliance cards
- `GET /api/metrics` -- JSON object with key metrics
- `GET /badge/spark.svg`, `GET /badge/tests.svg`, `GET /badge/do178c.svg`,
  `GET /badge/iso26262.svg`, `GET /badge/iec62304.svg` -- SVG badges

The served dashboard is **standard-aware**: like the `sbom` subcommand it
defaults to all standards when no `--standard` / `--asil` / `--class` flag is
given, so the compliance card lists every standard's level (DAL-C, ASIL B,
Class A) at the shared tier; an explicit standard flag narrows the dashboard
to that single standard (e.g. `--asil=B` shows only ISO 26262 at ASIL B).

The dashboard supports **light, dark, and system themes**: colors are driven
by CSS custom properties, and a header dropdown switches live between
**light mode**, **dark mode**, and **system theme** (which follows the
browser's `prefers-color-scheme`). The browser's choice is persisted in
`localStorage` and wins over `--theme` on later visits.

The server blocks (does not return to the shell) until interrupted.

### `--theme=NAME`

Dashboard color theme for `--serve`: `system` (default, follows
`prefers-color-scheme`), `light`, or `dark` (case-insensitive). Sets the
initial dropdown selection in the served page; the header dropdown can
switch live afterwards. Only relevant with `--serve`.

### `--port=N`

HTTP server port when `--serve` is used. Must be a valid `Positive` integer.
Only relevant with `--serve`.

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

### `--emit-markdown=PATH`

Write compliance reports to a directory. Creates two files:

- `VERIFICATION.md` -- full verification report with all metrics
- `TRACE.md` -- HLR traceability matrix (source-to-requirement mapping)

### `--skip-dir=NAME`

Add a directory name to the scanner's skip list (repeatable). Directories whose
simple name matches an entry are not recursed into during source scanning.
Only effective in relaxed mode; in strict mode (default) the skip list is
always empty.

### `--relaxed`

Disable strict mode. Enables the skip list (default `demo,deps,examples` plus
any `--skip-dir` entries) and does NOT apply `.adacovex/patches/`. See
[Strict vs relaxed mode](#strict-vs-relaxed-mode).

### `--compare-base=REF`

Differential mode: snapshot a base revision in a temporary directory
(`/tmp/adacovex-diff-<pid>`) and print a side-by-side comparison against the
current tree (packages, subprograms, docstring %, HLR traced, orphan tags,
SPARK level, VCs proved, tests, DAL status). Works on **git, Mercurial,
Subversion, Fossil, and jj** -- see [VCS support](#vcs-support). The
`--target` directory must be a supported VCS repository with the VCS
command-line tool on `PATH`.

Exit `0` only if there are no regressions AND the current DAL is Achieved;
`1` otherwise. Artifacts the base does not commit (`gnatprove.out`, a
test-result summary) report `N/A` and are not compared.

### `--coverage-delta=REF`

Lightweight docstring-coverage gate for PR-style CI checks. Scans sources +
patches + computes docstring metrics on both a base revision and the current
tree (no GNATprove/tests/DAL, so it works when the base does not commit build
artifacts), prints a compact coverage table plus a machine-parseable
`coverage_delta:` line, and cleans up the snapshot.

Exit `0` if current docstring coverage is `>=` the base (or the base has no
sources); `1` if coverage regressed. Mutually exclusive with `--compare-base`.
`make release` runs the same gate against the last release tag (e.g.
`--coverage-delta=v1.1.0`) and aborts if docstring coverage regressed between
releases.

### `--version`

Print the bundled version (`adacovex vX.Y.Z`) and exit, without scanning or
assessing. The version source depends on the **installation method**:
`tools/gen-version.py` regenerates `src/adacovex_version_info.ads` (the
compiled-in constant) on every `make build` from the first available of
`ADACOVEX_VERSION` (release builds -- the release workflow / `make release`
set it from the `vX.Y.Z` tag, so the shipped binary always reports exactly the
tag it was built from), `alire/alire-dev.toml` (source checkouts), or
`alire.toml` (dependency-managed installs: when covex is built as an Alire
crate the binary is compiled from the published crate source, whose
`alire.toml` -- the toml associated with the covex binary for dependency
management -- carries the release version; `alire-dev.toml` may not exist in
that tree). The same constant drives the man page, the SBOM tool
version, and the result-cache namespace, so they can never drift.

### `man`

The `man` subcommand installs the adacovex man page into the **local man
database** (Linux/WSL, no root required) and refreshes the index:

```bash
adacovex man                 # install to ~/.local/share/man/man1 + run mandb
adacovex man --check         # exit 0 if installed page matches, 1 otherwise
adacovex man --dir=PATH      # install under PATH/man1 instead
```

- **Default root**: `$XDG_DATA_HOME/man` when set, else `~/.local/share/man`.
  `--dir=PATH` overrides it (install goes to `PATH/man1/adacovex.1`).
- **The page contains the version** (in the `.TH` header and a `VERSION`
  section). `adacovex man --check` parses the installed page and exits `0`
  when it matches the binary, `1` when a newer version is available or no
  page is installed -- so a shell prompt hook can run `adacovex man --check`
  and `adacovex man` automatically when the machine detects a newer version:

  ```bash
  # ~/.bashrc / ~/.zshrc: refresh the man page when the binary is newer
  command -v adacovex >/dev/null && adacovex man --check >/dev/null 2>&1 \
    || adacovex man >/dev/null 2>&1
  ```

- **Database refresh**: `mandb` is run on the man root when present (Ubuntu
  and WSL ship it). When man-db is **not** installed (or `mandb` fails),
  adacovex prints a warning that the database was not refreshed -- the page
  is still installed and readable with `man -l
  ~/.local/share/man/man1/adacovex.1`. `adacovex status` reports whether
  `mandb` is on `$PATH` before you run `man`.
- Exit codes: `0` on success/up-to-date, `1` on install failure or when
  `--check` finds a newer version available (or none installed).

### VCS support

**A version control system is not required for base adacovex functionality**
(scanning, proof analysis, test parsing, compliance assessment, SBOM
generation, dashboards, caching). A VCS is only needed for the differential
modes below, which snapshot a base revision to compare against the current
tree. Since adacovex assesses source code, assuming the audited project lives
in a VCS is sensible -- but the base tool never requires one.

The differential modes run against the VCS that manages the target. Detection
is marker-file based, with a command-probe fallback:

| VCS | Marker | Base snapshot mechanism |
|-----|--------|-------------------------|
| git | `.git` | `git worktree add --detach` (linked worktree) |
| jj | `.jj` | `jj git export` into the internal git store, then a git worktree against `.jj/repo/store/git` (jj commits are git commits) |
| Mercurial | `.hg` | `hg archive -r REF DIR` (pure export) |
| Subversion | `.svn` | `svn info --show-item url` + `svn export -r REF URL DIR` |
| Fossil | `.fslckout` / `_FOSSIL_` | copy the repo DB and `fossil open` it at REF in a scratch dir |

For colocated git+jj repos git wins (exact interop). All snapshots land in
`/tmp/adacovex-diff-<pid>` and are cleaned up afterwards; the working tree is
never touched.

**UX recommendation**: git (and jj, its git-compatible sibling) give the best
experience. Mercurial is fully supported. For VCS whose snapshot UX is poor,
adacovex prints a note recommending the developers **convert the repository to
git** (or a git-compatible VCS):

- **Subversion** -- no local history, network-dependent checkouts, slow
  `svn export` per snapshot. Converting gives you local branches, offline
  history, and faster diffs.
- **Fossil** -- workable, but the tooling is niche and the single-file DB
  model complicates CI integration.

These notes are informational only: the assessment still runs and gates still
apply on every supported VCS. Works on **Linux and WSL** (the snapshot
commands run through `sh -c`, which WSL provides).

### CI threshold gates (`--require-*`)

The four `--require-*` flags add explicit minimum-bar checks on top of the DAL
criteria. They are off by default; when set, the assessment fails loudly
(exit code `1`, with an explicit `CI GATE:` reason printed to the report) if the
target does not meet the required level:

```bash
adacovex --target=. --require-spark=Platinum --require-docstrings=100 \
         --require-tests=634 --require-proof=100
```

- `require-spark` compares the honest assessed SPARK level (Stone..Platinum).
- `require-docstrings` and `require-proof` take a percentage (0-100).
- `require-tests` takes a count of passing tests.

CI that pins a gnatprove version (manifest or global `adacovex.toml` pin)
should set these to the values that version actually achieves -- a stricter
prover can legitimately leave more VCs unproved, so gate on the results of the
prover you pin.

### Result caching (`--cache` / `--no-cache` / `--cache-dir` / `--cache-max`)

adacovex persists parsed analysis results on disk so unchanged inputs are not
re-scanned / re-parsed / re-proved. Source scans, GNATprove summaries, test
summaries, HLR.md/LLR.md requirement parses, the resolved SBOM dependency
graph, and the differential-mode scans are each keyed by a namespace prefix
plus the SHA-256 of the artifact(s) they were derived from -- e.g.
`"scan:" | "prove:" | "tests:" | "hlr:" | "llr:" | "graph:" + digest` -- so
re-parsing a byte-identical artifact yields a cache hit regardless of the
target directory or command line. An unchanged manifest/lockfile/.gpr set
serves the cached dependency graph; unchanged HLR.md/LLR.md serve the cached
requirement parses; and `--compare-base` / `--coverage-delta` reuse cached
source scans for the current tree.

- **Schema namespace**: the default cache root is
  `~/.adacovex/cache/<version>/<Cache_Schema>`. `Cache_Schema` (in
  `src/core/adacovex-cache.ads`) is bumped whenever the serialized layout of a
  cached record or the scanner/parser semantics change, so blobs written by an
  incompatible build are never served as if valid.
- **Eviction**: `Put_Cached` evicts oldest-first by modification time when more
  than `--cache-max` entries (default `4096`) accumulate. `Eviction_Count`
  tracks removals and is reported in the ANSI cache line.
- **Overflow safety**: `Serialize` returns an empty blob when a package would
  exceed `Max_Cache_Blob`; callers skip storing it and `Deserialize` rejects
  empty/oversized input, so truncated data can never be served as a hit.
- **`--target` normalization**: `--target` is normalized (`.`/`..` collapsed to
  a canonical absolute path) before scanning, keeping the `File_Path` values in
  cached `Package_Info` consistent across invocations that spell the same
  directory differently.
- **CI**: the GitHub action persists `~/.adacovex/cache` between workflow runs
  (`result-cache` input, default true).

`--no-cache` bypasses it entirely (useful when artifacts change without their
content hash changing, or to measure rescan cost) and `--cache-dir` relocates
it. The ANSI report shows a
`result cache: X hit(s), Y miss(es), Z evicted` line per run.

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

## Strict vs relaxed mode

| Aspect | Strict (default) | Relaxed (`--relaxed`) |
|--------|-----------------|----------------------|
| Directory exclusions | `.git`, `obj`, `tests`, `config`, `.adacovex` only | Same + `demo,deps,examples` + `--skip-dir` additions |
| Vendored code | Scanned and counted | Skipped |
| Patch files | Applied from `.adacovex/patches/` | Not applied |
| Use case | Full compliance audit | Quick assessment of production code |

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success (DAL achieved, all checks pass, `--version`, man page installed/up-to-date) |
| `1` | Compliance failure (DAL unmet, tests failing, a `--require-*` CI gate unmet, differential regression, `man --check` finding a newer version available or none installed, etc.) |

## NO_COLOR support

adacovex respects the `NO_COLOR` environment variable. If `NO_COLOR` is set,
ANSI color codes are suppressed in terminal output. Color is enabled by default.

## The `sbom` subcommand

`adacovex sbom` resolves the target project's dependency graph from its Alire
manifest (`alire.toml` / `alire-dev.toml`), the solved-crate list in
`alire/alire.lock`, and the root `.gpr` `with` clauses, then writes a
proof-aware software bill of materials in CycloneDX 1.5 JSON or SPDX 2.3 JSON.

- **Usage**:
  `adacovex sbom [--format=FMT] [--out=PATH] [--standard=NAME] [--dal=LEVEL | --asil=LEVEL | --class=LEVEL]`.
  The sbom subcommand is **standard-aware**: it accepts the same standard
  flags as the assessment (`--standard`, `--dal`, `--asil`, `--class`) and
  **defaults to all standards** -- without an explicit standard flag the SBOM
  carries the joined DO-178C / ISO 26262 / IEC 62304 properties at the shared
  DAL tier; `--standard=iso26262` / `--asil=B` narrows it to ISO 26262 at
  ASIL B, and `--class=A` to IEC 62304 at Class A.
- **Default output**: `<target>/sbom.json` for `cyclonedx-json`,
  `<target>/sbom.spdx.json` for `spdx-json`. The containing directory is
  created automatically.
- **Properties**: only the root component -- the project adacovex actually
  assessed -- carries `adacovex:proof_level` (`Stone`..`Platinum`, the honest
  assessed level), `adacovex:standard` (`DO-178C` / `ISO 26262` /
  `IEC 62304`), `adacovex:dal_target` (`DAL-A`..`DAL-D`; omitted for
  `DAL-E`), and `adacovex:level` (the standard-specific label `DAL-C` /
  `ASIL B` / `Class A`; omitted for `DAL-E`). Dependency components report
  `adacovex:proof_level = "Not proved"` (adacovex only proves the target
  itself, never third-party dependencies). Encoded as `attributionTexts` in
  SPDX.
- **Determinism**: the `metadata.timestamp` / `creationInfo.created` field
  honors the `SOURCE_DATE_EPOCH` environment variable (reproducible-builds
  convention); when set to a Unix epoch second count the timestamp is derived
  from it in UTC via pure integer math, so SBOM output is byte-for-byte
  deterministic across runs and machines. To tie it to a specific git commit,
  run `export SOURCE_DATE_EPOCH=$(git -C <target> log -1 --format=%ct)` before
  adacovex. The bundled `make` targets (`run-self`, `run-ada-crdt`, `prove`,
  `release`, and Ada_CRDT's `prove`/`badges`) already set it from the target's
  git `HEAD` commit time.
- **Exclusivity**: mutually exclusive with `--compare-base` and
  `--coverage-delta`. `sbom` scans sources, parses proof/test results, and
  assesses DAL first, so the emitted properties reflect the real assessment
  state.
- **Exit code**: `0` when the SBOM was written, `1` otherwise. If the target
  has no Alire manifest the SBOM cannot be generated (the GitHub Action reports
  this as a warning without failing the job).

Both formats validate against the official
[CycloneDX 1.5](https://github.com/CycloneDX/specification) and
[SPDX 2.3](https://spdx.dev) JSON schemas (see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)).

## Examples

```bash
# Self-assessment (strict mode, 100% docs required)
adacovex --target=.

# ISO 26262 assessment at ASIL B (dedicated flag)
adacovex --target=. --asil=B

# IEC 62304 assessment at safety Class A (dedicated flag)
adacovex --target=. --class=A

# ISO 26262 assessment at rigor tier C (ASIL B) via --standard
adacovex --target=. --standard=iso26262 --dal=C

# Emit badges for every standard at the shared tier
adacovex --target=. --standard=all

# Report toolchain + platform status
adacovex status --target=.

# Assess a CRDT library at DAL-C in relaxed mode
adacovex --target=../Ada_CRDT --dal=C --relaxed

# DAL-A assessment (requires Gold SPARK)
adacovex --target=. --dal=A

# Without SVG output
adacovex --target=../Ada_CRDT --no-svg

# Custom skip dirs
adacovex --target=../Ada_CRDT --relaxed --skip-dir=vendor

# With Markdown reports
adacovex --target=. --emit-markdown=docs/compliance

# Web dashboard on custom port
adacovex --target=. --serve --port=9090

# Differential assessment vs a git base revision
adacovex --target=. --compare-base=HEAD

# Proof-aware SBOM (CycloneDX 1.5 JSON; all standards by default)
adacovex sbom --format=cyclonedx-json --target=. --dal=C
# SBOM for a single standard (ISO 26262 at ASIL B)
adacovex sbom --format=cyclonedx-json --target=. --asil=B
# SPDX 2.3 SBOM at IEC 62304 Class A
adacovex sbom --format=spdx-json --target=. --class=A --out=sbom.spdx.json

# Proof-aware SBOM (SPDX 2.3 JSON) at a custom path
adacovex sbom --format=spdx-json --out=docs/compliance/sbom.spdx.json
```
