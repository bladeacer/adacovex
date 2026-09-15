# Global configuration and state

adacovex keeps its machine-local configuration and every cache under one
directory: `~/.adacovex/`. The installer honours `$ADACOVEX_HOME` as an
alternate prefix for the binary, but the configuration and state directory is
always `~/.adacovex/`. adacovex writes nothing outside that directory and
never changes a target project. This page documents the global configuration
file, the environment variables, and the state directories.

## The `~/.adacovex/` directory

| Path | Contents |
|------|----------|
| `adacovex.toml` | The optional global configuration file. |
| `cache/<version>/<schema>/` | The content-addressed result cache. |
| `toolchain/` | gnatprove versions deployed by the `prove` subcommand. |
| `probes/` | Cached tool-version probes, with a 7-day expiry. |
| `meta/` | Cached package-registry metadata, with a 7-day expiry. |
| `stamps/index.bin` | The persistent stat-stamp index that makes re-runs fast. |

The result cache is namespaced by the adacovex version and a cache schema
token, so an upgrade starts with a clean cache and never serves a record that
the new build cannot read. The `probes/`, `meta/`, and `stamps/` directories
sit outside that namespace on purpose: they describe the machine, not a
project, so a cache wipe does not cost a re-probe of every tool.

## The global configuration file

The file is `~/.adacovex/adacovex.toml`. It is optional; without it adacovex
uses its built-in defaults. The parser reads only the keys documented below
and ignores an unknown key, so the file is safe to extend. Create the file by
hand:

```toml
# ~/.adacovex/adacovex.toml
[prove]
gnatprove-version = "16.1.0"
```

### `[prove] gnatprove-version`

This key pins the gnatprove version that the `prove` subcommand runs. It
applies **only** when the target project does not declare `gnatprove` in its
own `alire.toml` or `alire-dev.toml`; a project manifest pin always wins.
adacovex deploys the pinned version standalone with
`alr -n get gnatprove=<version>` into `~/.adacovex/toolchain/` and runs that
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
cached toolchain under `~/.adacovex/toolchain/`, and finally the last-resort
platform download.

## Environment variables

| Variable | Effect |
|----------|--------|
| `ADACOVEX_GNATPROVE_VERSION` | Global gnatprove pin; overrides the config file. |
| `ADACOVEX_TOOLCHAIN_URL` | URL of the last-resort gnatprove toolchain bundle. |
| `ADACOVEX_VERSION` | Build-time version override; the release builds use it. |
| `ADACOVEX_HOME` | Installer prefix for the binary; the state stays in `~/.adacovex/`. |
| `ADACOVEX_REPO` | Installer source repository; defaults to `bladeacer/adacovex`. |
| `NO_COLOR` | Disables terminal colour, whatever the other conditions say. |
| `SOURCE_DATE_EPOCH` | Fixes the SBOM build time so output is reproducible; the release flow sets it. |
| `TMPDIR` / `TEMP` / `TMP` | Temporary directory for the captured prove output. |

## Resetting state

Delete a directory to reset the state it holds, or point the tool at another
location.

- Delete `~/.adacovex/cache/` to drop every cached result. Pass
  `--cache-dir=PATH` to relocate the cache instead.
- Delete `~/.adacovex/toolchain/` to force the next `prove` run to deploy its
  gnatprove again.
- Delete `~/.adacovex/stamps/index.bin` to drop the stat-stamp fast path; the
  next run re-hashes every file and rebuilds the index.
- Delete `~/.adacovex/probes/` and `~/.adacovex/meta/` to force the next SBOM
  run to re-probe the toolchain and the package registries.

Result caching is documented in full, including the schema namespace and the
eviction policy, in
[Architecture -- result caching](../contributing/architecture.md#result-caching).
The gnatprove resolution order is documented in
[Architecture -- dependency management](../contributing/architecture-dependencies.md#gnatprove-toolchain-resolution-prove-subcommand).
