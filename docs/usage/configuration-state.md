# Configuration state and environment

The configuration file sits beside adacovex's machine-local state. This page
documents the state directories, the environment variables, and how to reset
that state. The file's keys are on
[Global configuration and state](configuration.md).

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
|`<cache>/<version>/<schema>/`|The content-addressed [result cache](../glossary/ste100/tooling-terms.md#technical-name-result-cache).|
|`<cache>/stamps/index.bin`|The persistent stat-stamp index that makes re-runs fast.|
|`<cache>/probes/`|Cached tool-version probes, with a 7-day expiry.|
|`<data>/toolkit/`|gnatprove versions deployed by the `prove` subcommand.|
|`<data>/meta/`|Cached package-registry metadata, with a 7-day expiry.|

adacovex 1.74.0 renamed this directory from `<data>/toolchain/` to
`<data>/toolkit/`, and the bundle variable from `ADACOVEX_TOOLCHAIN_URL` to
`ADACOVEX_TOOLKIT_URL`. The old path and variable are not read. The first
`prove` run after the upgrade deploys [gnatprove](../glossary/ste100/identifiers.md#technical-name-gnatprove) into the new directory, so it
performs one re-download.

The result cache is namespaced by the adacovex version and a cache schema
token, so an upgrade starts with a clean cache and never serves a record that
the new build cannot read. The `probes/`, `meta/`, and `stamps/` directories
sit outside that namespace on purpose: they describe the machine, not a
project, so a cache wipe does not cost a re-probe of every tool.

`--cache-dir=PATH` relocates the result cache alone. The probe, metadata, and
stat-stamp stores stay in the platform directories, because they are answers
about the machine and not about one project.

Every entry carries its own write time in a fixed header, and the TTL reads
that time, never the file mtime. A CI cache restore or a file copy rewrites
mtime, so an mtime rule would make an old entry look new. The default
lifetime is 7 days; `--cache-expiry=DAYS` or `[cache] expiry-days` changes it,
and `0` means entries never expire. `adacovex --cache-clear` removes every
entry under the resolved cache root and prints the count.

The key uses the resolved project location, not the spelling the caller used.
A run from the project directory, its parent, or another directory hits the
same entries for `prove`, `sbom`, and a plain assessment. The proof cache also
stores one entry per unit (`proveunit:`), so a one-unit edit keeps the
unchanged unit entries; the run report shows `N/M unit(s) hit`.

## Environment variables

|Variable|Effect|
|--------|------|
|`ADACOVEX_STATE_HOME`|Replaces the configuration, cache, and data directories with `DIR`, `DIR/cache`, and `DIR/data`.|
|`ADACOVEX_OFFLINE`|Set to `1` to skip every package-registry probe (`alr show`, `npm view`, `pnpm show`, `cargo search`, `go list`): the SBOM carries only offline-known versions and licences. The native suite and the CLI e2e checks set it, so local verification runs without the network.|
|`ADACOVEX_GNATPROVE_VERSION`|Global gnatprove pin; overrides the config file.|
|`ADACOVEX_TOOLKIT_URL`|URL of the last-resort gnatprove toolchain bundle.|
|`ADACOVEX_VERSION`|Build-time version override; the release builds use it.|
|`ADACOVEX_HOME`|Installer prefix for the binary (`$ADACOVEX_HOME/bin`); the state directories are unaffected.|
|`ADACOVEX_REPO`|Installer source repository; defaults to `bladeacer/adacovex`.|
|`NO_COLOR`|Disables terminal colour, whatever the other conditions say.|
|`SOURCE_DATE_EPOCH`|Fixes the SBOM build time so output is reproducible; the release flow sets it.|
|`TMPDIR` / `TEMP` / `TMP`|Temporary directory for the captured prove output.|

## Resetting state

Delete a directory to reset the state it holds, or point the tool at another
location.

- Run `adacovex --cache-clear` to drop every cached result; it prints the
  resolved root and the count. Pass `--cache-dir=PATH` to clear a relocated
  cache instead.
- Delete `<data>/toolkit/` to force the next `prove` run to deploy its
  gnatprove again.
- Delete `<cache>/stamps/index.bin` to drop the stat-stamp fast path; the
  next run re-hashes every file and rebuilds the index.
- Delete `<cache>/probes/` and `<data>/meta/` to force the next [SBOM](../glossary/ste100/tooling-terms.md#technical-name-software-bill-of-materials-sbom) run to
  re-probe the [toolkit](../glossary/ste100/tooling-terms.md#technical-name-toolkit) and the package registries.

Result caching is documented in full, including the schema namespace and the
eviction policy, in
[Architecture -- result caching](../contributing/architecture.md#result-caching).
The gnatprove resolution order is documented in
[Architecture -- dependency management](../contributing/architecture-dependencies.md#gnatprove-toolchain-resolution-prove-subcommand).
