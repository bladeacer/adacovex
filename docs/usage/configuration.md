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

## The global configuration file

The file is `<config>/adacovex.toml` (`~/.config/adacovex/adacovex.toml` on
Linux, `~/Library/Application Support/adacovex/adacovex.toml` on macOS,
`%APPDATA%\adacovex\adacovex.toml` on Windows). It is optional; without it
adacovex uses its built-in defaults. The parser reads only the keys documented
below and ignores an unknown key, so the file is safe to extend. Create the
file by hand:

```toml
# <config>/adacovex.toml, for example ~/.config/adacovex/adacovex.toml
[prove]
gnatprove-version = "16.1.0"
```

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

## Environment variables

|Variable|Effect|
|--------|------|
|`ADACOVEX_STATE_HOME`|Replaces the configuration, cache, and data directories with `DIR`, `DIR/cache`, and `DIR/data`.|
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
