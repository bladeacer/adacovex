# Installing adacovex

adacovex is distributed as the `covex` Alire crate, a release bundle on
GitHub, or a source build. All three routes produce the same binary
(`adacovex`, with a `covex` alias on Linux).

## Option 1: declare it in your project's Alire manifest (recommended)

Put `covex` in your project's `alire-dev.toml` (never `alire.toml`, so release
builds stay clean), alongside `gnatprove`:

```toml
# <project>/alire-dev.toml
[[depends-on]]
covex = "*"
gnatprove = "^16.1.0"
```

Then `alr build` produces `bin/adacovex` inside the project and `covex prove`
deploys the pinned gnatprove crate standalone via `alr -n get` and runs it
directly -- each project pins its own exact toolchain version, no global
install needed:

```bash
alr build
./bin/adacovex --target=. --dal=C
./bin/adacovex prove --target=.   # deploys gnatprove via alr get, then runs it
```

## Option 2: `alr install` (global, to `$PATH`)

```bash
alr install covex gnatprove
export PATH="$HOME/.local/bin:$PATH"
```

`covex` is the Alire crate name for adacovex
([crate page](https://alire.ada.dev/crates/covex)); once on `$PATH` it scans
the current directory by default. A `gnatprove` installed this way is picked up
from `$PATH` by `covex prove` when the target project declares no manifest
dependency of its own.

## Option 3: download a release bundle from GitHub

Every `vX.Y.Z` tag publishes `adacovex-vX.Y.Z.tar.gz` on the
[GitHub Releases page](https://github.com/bladeacer/adacovex/releases).

```bash
curl -fsSL https://raw.githubusercontent.com/bladeacer/adacovex/main/install.sh | bash
```

Bundles are attested with [`actions/attest`](https://github.com/actions/attest).

> Release binaries are **Linux x86-64 only**; other platforms build from source
> via Alire.

## Building from source

```bash
git clone --depth 1 https://github.com/bladeacer/adacovex.git
cd adacovex && make build   # or: --branch vX.Y.Z for a released tag
```

`make build` produces `bin/adacovex` (with a `bin/covex` alias). A stock
Alire toolchain (`gnat_native` + `gprbuild`) plus the standard GNAT runtime
is all that is needed -- no other dependencies.

## Version source per installation method

`adacovex --version` (and the man page, the SBOM tool version, and the result
cache namespace) resolve the version from `tools/gen-version.py`, which
depends on the installation method:

1. `ADACOVEX_VERSION` -- release builds (the shipped binary always reports the
   tag it was built from).
2. `alire/alire-dev.toml` -- source checkouts (`version = "x.y.z"`).
3. `alire.toml` -- dependency-managed installs: the toml associated with the
   `covex` binary for dependency management carries the release version.

## Keeping the man page in sync

`adacovex man` installs the man page (which embeds the version) into
`~/.local/share/man` and refreshes `mandb` when present. `adacovex man
--check` exits 0 when the installed page matches the binary (a shell prompt
hook can auto-update), and `man --force` overwrites an up-to-date page (e.g.
to repair a hand-edited one). When man-db is missing the page still installs
-- read it with `man -l ~/.local/share/man/man1/adacovex.1` -- and
`adacovex status` reports mandb availability up front.
