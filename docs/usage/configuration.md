# Global configuration and state

adacovex reads an optional project file and an optional global file. This
page documents both files, every supported key, and the sample configuration
the repository ships. The state directories, the environment variables, and
the reset procedure are on
[Configuration state and environment](configuration-state.md).

## Configuration files

Two files supply defaults, and each one is optional. The **project file** is
`<target>/adacovex.toml`: a project carries the settings its code needs, and
every run against that directory picks them up. The **global file** is
`<config>/adacovex.toml` (`~/.config/adacovex/adacovex.toml` on Linux,
`~/Library/Application Support/adacovex/adacovex.toml` on macOS,
`%APPDATA%\adacovex\adacovex.toml` on Windows), and it applies to every run
on the machine.

The parser reads only the keys documented below and ignores an unknown key or
section, so a file is safe to extend. The full sample configuration is
embedded below, with every key at its default value. `adacovex init` writes a
scaffold with the same keys into a project (see
[Scaffolding a project file](#scaffolding-a-project-file)).

```toml
# <target>/adacovex.toml
[prove]
coverage = false
jobs = 4
```

### The sample file

The block below is the repository's sample `adacovex.toml` for the release you
run, and `adacovex --version` names that release. Every key states its
built-in default, so an empty file and no file behave the same.

<!-- config-sample:begin -->
```toml
# adacovex project configuration (sample).
#
# Every key here overrides a built-in default. A command-line flag overrides
# this file, and this file overrides the global one at
# <config>/adacovex.toml (for example ~/.config/adacovex/adacovex.toml).
# Copy this file into your own project, or delete it: every key below states
# the built-in default, so an empty file and no file behave the same.
#
# Reference: https://adacovex.readthedocs.io/en/latest/usage/configuration.html

[prove]
# Print the proof-coverage summary line after a successful prove run.
# Values: true (default) | false.
coverage = true

# gnatprove parallelism. 0 = all cores, N = pin N processes, omit = auto
# (max(1, cores-2) locally, all cores in CI).
# jobs = 4

# Proof effort 0-4. Omit to use the prove subcommand's default (4).
# level = 2

# Per-check prover timeout in seconds. Omit to use gnatprove's default.
# timeout = 60

# Maximum proof steps. Omit to use the prove subcommand's reproducible
# 10000-step budget.
# steps = 10000

# Prover memory limit in MB. Omit to use gnatprove's default.
# memlimit = 4096

[complexity]
# File extensions the complexity/LOC gate skips (comma-separated, no dots).
# excludes = "md,rst"

# Path fragments the complexity/LOC gate skips (comma-separated).
# skip-path = "docs/api-docs"
```
<!-- config-sample:end -->

The block is checked against the committed file on every documentation check,
so the copy in the manual cannot drift from the sample in the tree.

### Precedence

An explicit command-line flag wins over both files. Without a flag, the
project file wins over the global file, and the global file wins over the
built-in default. A key a file does not mention changes nothing, so a project
file can set one value and inherit the rest.

### `[prove] gnatprove-version`

This key pins the gnatprove version that the `prove` subcommand runs. It
applies **only** when the target project does not declare `gnatprove` in its
own `alire.toml` or `alire-dev.toml`; a project manifest pin always wins.
adacovex deploys the pinned version standalone with
`alr -n get gnatprove=<version>` into `<data>/toolkit/` and runs that
binary directly.

The pin is authoritative and never falls back. When the pinned version cannot
be deployed, the run fails instead of using a different prover, because a
different gnatprove can change which verification conditions are discharged.
The pin is also folded into the proof result-cache identity, so changing it
forces a fresh proof instead of serving a stale one. The value must be a bare
version such as `16.1.0`, or a constraint such as `^16.1.0` whose leading
operator is stripped.

The environment variable `ADACOVEX_GNATPROVE_VERSION` overrides this key. The
full resolution order is: project manifest pin, then the global pin
(environment variable, then this file), then a gnatprove on `$PATH`, then the
cached toolkit under `<data>/toolkit/`, and finally the last-resort
platform download.

### `[prove] coverage`

This key sets whether a successful `prove` run prints the proof-coverage
summary. The summary is one line: statement coverage, subprogram coverage, and
VC coverage, each with the proved count and the total.

```
  coverage:  statements 57% (7246/12582) subprograms 18% (122/668) VCs 100% (1058/1058)
```

The default is `true`, so the summary is on without a configuration file. Set
`coverage = false` to hide it for every local run. The flags `--coverage` and
`--no-coverage` win over this key, so a script or a CI job can override it for
one run. The key does not change the proof: it only changes the summary line.
`adacovex spark-coverage` prints the same coverage as a full report.

Both files accept the key, and the project file wins.

### `[prove]` integer keys

|Key|Default|Effect|
|----|--------|-------|
|`jobs`|auto|gnatprove parallelism: `0` = all cores, `N` = pin N processes, omit = auto (max(1, cores-2) locally, all cores in CI)|
|`level`|`4`|Proof effort, 0-4; the `prove` subcommand sends this level when no flag overrides it|
|`timeout`|gnatprove's default|Per-check prover timeout in seconds|
|`steps`|`10000`|Maximum proof steps; omit to keep the prove subcommand's reproducible budget|
|`memlimit`|gnatprove's default|Prover memory limit in MB|

The file values are applied only where the matching flag is absent, so
`--jobs=1` wins over `jobs = 4` in either file.

### `[complexity]` keys

|Key|Default|Effect|
|----|--------|-------|
|`excludes`|empty|Comma-separated file extensions the complexity/LOC gate skips, without dots (for example `"md,rst"`)|
|`skip-path`|empty|Comma-separated path fragments the gate skips (for example `"docs/api-docs"`)|

These mirror `--excludes` and `--skip-path`, and an explicit flag wins. They
take effect only in `adacovex complexity`.

### `[cache] keys`

|Key|Default|Effect|
|----|--------|-------|
|`expiry-days`|`7`|Entry lifetime in days; `0` means entries never expire|

The key mirrors `--cache-expiry=DAYS`, and an explicit flag wins. The age
comes from the entry's own header, so a restored cache keeps the lifetimes it
had when it was written.

### `[init] scaffold`

The global file only. This key turns the `init` subcommand off for every
project on the machine. With `scaffold = false`, `adacovex init` writes no
file, prints the reason, and exits 0.

A project file cannot set the key, because the project file is what `init`
would create. The default is `true`.

## Scaffolding a project file

`adacovex init` writes a sample `<target>/adacovex.toml` and exits. The file
states the default of every supported key, and it links to the deployed copy
of this page, so a project starts from a correct file instead of memory. The
default target is the current directory; `-t PATH` (or `--target=PATH`)
scaffolds another directory.

An existing file is left untouched and the command exits 1. This rule keeps a
project's own settings safe from an accidental rerun. `--force` overwrites the
file. The command writes to `<target>/adacovex.toml` only; it never writes to
the global configuration directory.

`[init] scaffold = false` in the global file disables the command for every
project on the machine, and the command exits 0 without touching the target.

```
adacovex init -t path/to/project
adacovex init -t path/to/project --force
```

