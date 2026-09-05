# adacovex CLI Reference

This page is the quick reference. It shows usage, the full flag table, and a
short note per flag. Feature-specific detail is in dedicated pages (linked
from each section):

- the [web dashboard](dashboard.md)
- the [`sbom` subcommand](sbom.md)
- [VCS support](vcs.md)
- the [platforms/`status`](platforms.md#status-subcommand) and
  [installation](installation.md) pages
- [Architecture](../contributing/architecture.md) for design detail such as result caching and
  the patch system

## Usage

```
adacovex [options]
adacovex sbom [--format=cyclonedx-json|spdx-json|md] [--out=PATH]
           [--standard=NAME|--dal=LEVEL|--asil=LEVEL|--class=LEVEL]
adacovex prove [--target=PATH] [prove options]
adacovex status [--target=PATH]
adacovex man [--check|--force] [--dir=PATH]
adacovex completion [bash|fish|zsh|pwsh]
```

## Flags

| Flag | Default | Mode | Description |
|------|---------|------|-------------|
| `--target=PATH` | `.` (CWD) | both | Target project root directory |
| `--manifest=PATH` | auto-detected | both | Override project manifest path |
| `--dal=LEVEL` | `C` | both | DO-178C DAL level (A-E, also the shared rigour tier) |
| `--asil=LEVEL` | - | both | ISO 26262 level: `A`\|`B`\|`C`\|`D`\|`QM` |
| `--class=LEVEL` | - | both | IEC 62304 safety class: `A`\|`B`\|`C` |
| `--standard=NAME` | `do178c` | both | `do178c`\|`iso26262`\|`iec62304`\|`all` |
| `--serve` | off | both | Start HTTP dashboard server (standard-aware, light/dark/system themes) |
| `--serve-workers=N` | `4` | serve | HTTP server task-pool worker count |
| `--theme=NAME` | `system` | serve | Dashboard theme: `light`\|`dark`\|`system` |
| `--port=N` | `8080` | serve | Dashboard server port |
| `--tz=ZONE` / `--timezone=ZONE` | OS timezone | both | Display timezone (IANA name or UTC/GMT offset) |
| `--excludes=EXT,EXT` | empty | complexity | Skip comma-separated file extensions |
| `--skip-path=PATH` | empty | complexity | Skip any file whose path contains PATH (repeatable) |
| `--emit-svg=PATH` | `<target>/docs/badges` | both | Output directory for SVG badges |
| `--no-svg` | off | both | Suppress SVG badge output |
| `--emit-markdown=PATH` | off | both | Output directory for Markdown reports |
| `--emit-metrics=PATH` | off | both | Write a JSON export of metrics + dependency graph to PATH |
| `--completion[=SHELL]` | - | - | Print shell completion script (bash/fish/zsh/pwsh, auto-detected) and exit |
| `--skip-dir=NAME` | `demo,deps,examples` | relaxed | Directory name to skip (repeatable) |
| `--relaxed` | off | both | Disable strict mode (skip dirs, no patches) |
| `--compare-base=REF` | off | both | Differential mode vs a base rev (git/hg/svn/fossil/jj) |
| `--coverage-delta=REF` | off | both | Docstring-coverage gate vs a base rev (git/hg/svn/fossil/jj) |
| `--cache` | on | both | Enable on-disk result caching |
| `--no-cache` | off | both | Disable result caching (always re-scan/re-parse/re-prove) |
| `--cache-dir=PATH` | `~/.adacovex/cache/<ver>/<schema>` | both | Cache directory for analysis results |
| `--cache-max=N` | `4096` | both | Max cache entries before oldest-first eviction |
| `--no-sbom` | off | both | Skip the automatic SBOM written at the end of every assessment |
| `--sbom-format=FMT` | `cyclonedx-json` | both | Format of the automatic SBOM: `cyclonedx-json`\|`spdx-json`\|`md` |
| `--require-spark=LVL` | off | both | Fail loudly (exit 1) if SPARK level < LVL (Stone..Platinum) |
| `--require-docstrings=PCT` | off | both | Fail loudly if docstring coverage < PCT% (0-100) |
| `--require-tests=N` | off | both | Fail loudly if passing test count < N |
| `--require-proof=PCT` | off | both | Fail loudly if proved-VC coverage < PCT% (0-100) |
| `--verbose` | off | both | Verbose diagnostics |
| `--version` | - | - | Print the bundled version and exit |
| `man` | - | - | Install the man page into the local man database |
| `man --check` | - | - | Exit 0 if the installed man page matches the binary version, 1 otherwise |
| `man --force` | - | - | Reinstall the man page even when it already matches (repair) |
| `man --dir=PATH` | `~/.local/share/man` | - | Install the man page under `PATH/man1` instead |
| `--help` | - | both | Print usage and exit |

`prove`-mode flags are also accepted by the main command. They are validated
only in prove mode. The flags are: `--jobs`/`-j`, `--level`, `--timeout`,
`--steps`, `--memlimit`, `--force`, `--no-loop-unrolling`, `--no-inlining`,
`--args`, `--suppress-warnings`, `--quiet`. See
[The `prove` subcommand](#the-prove-subcommand).

## Strict vs relaxed mode

| Aspect | Strict (default) | Relaxed (`--relaxed`) |
|--------|-----------------|----------------------|
| Directory exclusions | `.git`, `obj`, `tests`, `config`, `.adacovex` only | Same + `demo,deps,examples` + `--skip-dir` additions |
| Vendored code | Scanned and counted | Skipped |
| Patch files | Applied from `.adacovex/patches/` (docstrings always, SPARK proof aspects in prove mode) | Not applied |
| Use case | Full compliance audit | Quick assessment of production code |

Patch files can carry more than docstrings. A patch with `SPARK_Mode` /
`Pre` / `Post` / `Global` aspects is a **proof patch** that adds SPARK
contracts to vendored code in prove mode (spec patches `.ads`, and body
patches `.adb` opt the vendored body into the proof). Why they exist, how
to write them, worked examples, and pitfalls are in
[Proving and writing proofs -- proof patches](../contributing/proving-patches.md#proof-patches-proving-vendored-dependencies).

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success (DAL achieved, all checks pass, `--version`, man page installed/up-to-date) |
| `1` | Compliance failure (DAL unmet, tests failing, a `--require-*` CI gate unmet, differential regression, `man --check` finding a newer version available or none installed, and more) |

## Terminal colour

adacovex colours its terminal output (red for failures, green for passes,
bold for headings) so the important lines stand out.  Colour is enabled by
default on a normal terminal.  It is suppressed automatically when the
output would not take it:

- `NO_COLOR` is set (the cross-tool opt-out convention);
- a CI variable is set (GitHub Actions, GitLab CI, and more), so CI logs
  stay plain and machine-readable;
- `TERM` is `dumb` (or set to an empty value).

## The `sbom` subcommand

`adacovex sbom` resolves the target project's dependency graph from its Alire
manifest, `alire/alire.lock`, and the root `.gpr` `with` clauses, then writes
a proof-aware software bill of materials in CycloneDX 1.5 JSON or SPDX 2.3
JSON. It is **standard-aware** (it defaults to all standards), honours
`SOURCE_DATE_EPOCH` for byte-for-byte deterministic output, and is mutually
exclusive with `--compare-base` / `--coverage-delta`. Full detail (usage,
properties, determinism, exit codes) is in
[The `sbom` subcommand](sbom.md).

## Examples

```bash
# Self-assessment (strict mode, 100% docs required)
adacovex --target=.

# ISO 26262 assessment at ASIL B (dedicated flag)
adacovex --target=. --asil=B

# IEC 62304 assessment at safety Class A (dedicated flag)
adacovex --target=. --class=A

# ISO 26262 assessment at rigour tier C (ASIL B) via --standard
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
