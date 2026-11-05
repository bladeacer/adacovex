# Global configuration and state

adacovex keeps its machine-local configuration, cache, and data in the
directories the host platform reserves for them. Linux and the BSDs follow the
XDG base directory specification, macOS uses `~/Library`, and Windows uses the
`%APPDATA%` and `%LOCALAPPDATA%` profiles. One environment variable,
`ADACOVEX_STATE_HOME`, replaces every convention with a single directory.
adacovex writes nothing outside the directories below and never changes a
target project. This page documents the directories, the global configuration
file, the environment variables, and how to reset state.

## State directories

|Directory|Linux and the BSDs|macOS|Windows|
|---------|------------------|-----|-------|
| Configuration (`<config>`)|`$XDG_CONFIG_HOME/adacovex` (default `~/.config/adacovex`)|`~/Library/Application Support/adacovex`|`%APPDATA%\adacovex`|
| Cache (`<cache>`)|`$XDG_CACHE_HOME/adacovex` (default `~/.cache/adacovex`)|`~/Library/Caches/adacovex`|`%LOCALAPPDATA%\adacovex\cache`|
| Data (`<data>`)|`$XDG_DATA_HOME/adacovex` (default `~/.local/share/adacovex`)|`~/Library/Application Support/adacovex`|`%LOCALAPPDATA%\adacovex\data`|

`ADACOVEX_STATE_HOME=DIR` replaces all three with a single tree: the
configuration directory becomes `DIR`, the cache `DIR/cache`, and the data
`DIR/data`. Set it to pin the state to one place in a test or a CI job. It is
deliberately a different variable from the installer's `ADACOVEX_HOME`, which
names the prefix the release binary is installed into, so relocating the
binary never moves the state.

A Windows host without `%APPDATA%` falls back to `~/.adacovex`, so a stripped
environment still has a writable state directory.

## What each directory holds

|Path|Contents|
|----|--------|
|`<config>/adacovex.toml`|The optional global configuration file.|
|`<cache>/<version>/<schema>/`|The content-addressed result cache.|
|`<cache>/stamps/index.bin`|The persistent stat-stamp index that makes re-runs fast.|
|`<cache>/probes/`|Cached tool-version probes, with a 7-day expiry.|
|`<data>/toolchain/`|gnatprove versions deployed by the `prove` subcommand.|
|`<data>/meta/`|Cached package-registry metadata, with a 7-day expiry.|

The result cache is namespaced by the adacovex version and a cache schema
token, so an upgrade starts with a clean cache and never serves a record that
the new build cannot read. The `probes/`, `meta/`, and `stamps/` directories
sit outside that namespace on purpose: they describe the machine, not a
project, so a cache wipe does not cost a re-probe of every tool.

`--cache-dir=PATH` relocates the result cache alone. The probe, metadata, and
stat-stamp stores stay in the platform directories, because they are answers
about the machine and not about one project.

## Configuration files

Two files supply defaults, and each one is optional. The **project file** is
`<target>/adacovex.toml`: a project carries the settings its code needs, and
every run against that directory picks them up. The **global file** is
`<config>/adacovex.toml` (`~/.config/adacovex/adacovex.toml` on Linux,
`~/Library/Application Support/adacovex/adacovex.toml` on macOS,
`%APPDATA%\adacovex\adacovex.toml` on Windows), and it applies to every run
on the machine.

The parser reads only the keys documented below and ignores an unknown key or
section, so a file is safe to extend. The repository root carries a sample
[`adacovex.toml`](../../adacovex.toml) that states every key with its default
value and links to the deployed copy of this page. `adacovex init` writes the
same scaffold into a project (see
[Scaffolding a project file](#scaffolding-a-project-file)).

```toml
# <target>/adacovex.toml
[prove]
coverage = false
jobs = 4
```

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
`alr -n get gnatprove=<version>` into `<data>/toolchain/` and runs that
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
cached toolchain under `<data>/toolchain/`, and finally the last-resort
platform download.

### `[prove] coverage`

This key sets whether a successful `prove` run prints the proof-coverage
summary. The summary is one line: statement coverage, subprogram coverage, and
VC coverage, each with the proved count and the total.

```
  coverage:  statements 96% (1448/1508)  subprograms 98% (392/400)  VCs 100% (1054/1054)
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
|`level`|gnatprove's default|Proof effort, 0-4|
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

## Environment variables

|Variable|Effect|
|--------|------|
|`ADACOVEX_STATE_HOME`|Replaces the configuration, cache, and data directories with `DIR`, `DIR/cache`, and `DIR/data`.|
|`ADACOVEX_OFFLINE`|Set to `1` to skip every package-registry probe (`alr show`, `npm view`, `pnpm show`, `cargo search`, `go list`): the SBOM carries only offline-known versions and licences. The native suite and the CLI e2e checks set it, so `make check` runs without the network.|
|`ADACOVEX_GNATPROVE_VERSION`|Global gnatprove pin; overrides the config file.|
|`ADACOVEX_TOOLCHAIN_URL`|URL of the last-resort gnatprove toolchain bundle.|
|`ADACOVEX_VERSION`|Build-time version override; the release builds use it.|
|`ADACOVEX_HOME`|Installer prefix for the binary (`$ADACOVEX_HOME/bin`); the state directories are unaffected.|
|`ADACOVEX_REPO`|Installer source repository; defaults to `bladeacer/adacovex`.|
|`NO_COLOR`|Disables terminal colour, whatever the other conditions say.|
|`SOURCE_DATE_EPOCH`|Fixes the SBOM build time so output is reproducible; the release flow sets it.|
|`TMPDIR` / `TEMP` / `TMP`|Temporary directory for the captured prove output.|

## Resetting state

Delete a directory to reset the state it holds, or point the tool at another
location.

- Delete `<cache>/` to drop every cached result. Pass `--cache-dir=PATH` to
  relocate the result cache instead.
- Delete `<data>/toolchain/` to force the next `prove` run to deploy its
  gnatprove again.
- Delete `<cache>/stamps/index.bin` to drop the stat-stamp fast path; the
  next run re-hashes every file and rebuilds the index.
- Delete `<cache>/probes/` and `<data>/meta/` to force the next SBOM run to
  re-probe the toolchain and the package registries.

Result caching is documented in full, including the schema namespace and the
eviction policy, in
[Architecture -- result caching](../contributing/architecture.md#result-caching).
The gnatprove resolution order is documented in
[Architecture -- dependency management](../contributing/architecture-dependencies.md#gnatprove-toolchain-resolution-prove-subcommand).
