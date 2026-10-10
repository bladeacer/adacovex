# adacovex 1.60.0

Date: _2026-10-10_

Version bumped 1.59.0 -> 1.60.0.

## Changes

### C1: Configuration, cache, and data follow the host platform convention

adacovex kept every machine-local directory under `~/.adacovex/`. That is a
Unix dot-directory, and it is wrong on the two platforms that reserve another
place for it. The state now follows the convention of the host:

- Linux and the BSDs follow the XDG base directory specification:
  `$XDG_CONFIG_HOME/adacovex` (default `~/.config/adacovex`) for the
  configuration file, `$XDG_CACHE_HOME/adacovex` (default
  `~/.cache/adacovex`) for the cache, and `$XDG_DATA_HOME/adacovex` (default
  `~/.local/share/adacovex`) for the data.
- macOS uses `~/Library/Application Support/adacovex` for the configuration
  and data, and `~/Library/Caches/adacovex` for the cache.
- Windows uses `%APPDATA%\adacovex` for the configuration and
  `%LOCALAPPDATA%\adacovex\cache` and `\data` for the cache and data.

`Adacovex.Paths` answers all three directories with one pure function per
platform, so no unit spells a convention inline. The result cache, the
stat-stamp index, the tool-version probes, the registry metadata, and the
gnatprove toolchain each move to their platform directory.

The environment variable `ADACOVEX_STATE_HOME` replaces all three with a
single tree (`DIR`, `DIR/cache`, `DIR/data`). It is deliberately separate from
the installer's `ADACOVEX_HOME`, which names the binary prefix, so relocating
the binary never moves the state. A Windows host without `%APPDATA%` falls
back to `~/.adacovex`, so a stripped environment still has a writable
directory.

### C2: The Windows stack reserve moved into the project file

The 1.59.0 reserve lived in `tools/build.py`, so a plain `alr build`, a
consumer build, and Alire's crate-index CI did not carry it. It now lives in
`adacovex.gpr` as a `Linker` switch selected on the target OS, so every build
path on Windows links with the same 32 MiB reserve. Linux and the BSDs add no
switch, and their existing 8 MiB reserve is unchanged.

### C3: CI proves with the pinned prover and tests the non-Linux platforms

The self-assessment job swapped in `alire-dev.toml`, so its `prove` step used
the pinned gnatprove dependency instead of a last-resort download. The release
workflow now performs the same swap, because the release proof is the run that
most needs the pinned prover. The packaged release ships the built binary and
`install.sh`, not `alire.toml`, so the swap never reaches a consumer.

A new `platform-build` job builds the tree with a plain `alr build` and runs
the native suite on macOS and Windows, on the same consumer path Alire's
crate-index CI exercises. That job is the evidence behind the non-Linux rows
of the platform matrix, and the `summary` job reports it with the other gates.

### C4: The platform matrix says what is supported and what is tested

`docs/usage/platforms.md` now separates three claims that were previously
blurred: what is **officially supported** (a defect there blocks a release),
what the **maintainers run** (the native suite in CI), and what **Alire's
index CI** builds on a pull request against the community index. macOS is not
a priority platform, and it is a small gap: it shares the POSIX path model
with Linux, and `Adacovex.Paths` already answers its `~/Library` convention.

The clone-from-source instructions on the installation page, the README, and
the developer guide now use `just build`, `just test`, and `just check`. The
`Makefile` remains a thin shim, so an existing `make <task>` reference still
works.

## Fixes

### H1: The generated man page named the old cache path

The man page embedded `~/.adacovex/cache` in its FILES section, which the
platform-directory change made wrong. It now names `~/.cache/adacovex`, the
Linux default that the man page carries, and states that this is the platform
cache directory.

## Test Suite

1815 tests across 27 categories, unchanged from 1.59.0. The cache tests
already rebuild the stamp and probe paths from the platform cache directory,
so they cover the new layout on every host.

`just test` runs the native suite, `just cli-e2e` runs the end-to-end suite,
and the new `platform-build` CI job runs the native suite on macOS and
Windows.

## Proof Results

**Platinum**, 0 unproved, 0 justified, **1047 of 1047 VCs across 70 analysed
units** under gnatprove 16.1.0 at `--level=4`. The counter is unchanged from
1.59.0: the platform directories live in the default-off `Adacovex.Paths`
body, and the `Linker` package adds only a Windows link switch, which the
prover never sees.

The proof ran on this tree and re-reported Platinum at the same count, so the
figure is a fresh result rather than an inherited 1.59.0 value.

## Traceability

No new HLR record enters this release, and no tag is added or removed. The
platform-directory work extends `HLR-CACHE` and `HLR-PROVE`, on record for
the result cache and the gnatprove runner, because it moves their on-disk
roots. It also extends `HLR-ARCH`, on record for the architecture and path
handling of the tool.

The packages changed by this release, and the tags already on record that
cover them: `Adacovex.Paths` and the CLI entry point (`HLR-ARCH`),
`Adacovex.Cache` (`HLR-CACHE`), `Adacovex.Prove` (`HLR-PROVE`), and
`Adacovex.Renderers.Man` (`HLR-RENDER-MAN`). C3 and C4 change no requirement:
they change the CI that proves the tree and the documentation that describes
it.
