# Installing adacovex

## Quick start

1. **Install** via Alire: `alr install covex gnatprove && export PATH="$HOME/.local/bin:$PATH"`
2. **Assess** your project: `adacovex --target=. --dal=C`
3. **Serve** the dashboard: `adacovex --target=. --serve --port=8080`

That is all you need for a local compliance assessment. For CI or release
workflows, see [CI/CD](ci-cd.md).

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

Then `alr build` produces `bin/adacovex` inside the project. `covex prove`
deploys the pinned gnatprove crate standalone via `alr -n get` and runs it
directly. Each project pins its own exact toolchain version. No global install
is needed:

```bash
alr build
./bin/adacovex --target=. --dal=C
./bin/adacovex prove --target=.   # deploys gnatprove via alr get, then runs it
```

### How `prove` resolves gnatprove (Option 1)

The manifest pin is **authoritative**: when `alire-dev.toml` or `alire.toml`
declares `gnatprove`, `covex prove` always runs that version and never falls
back to another prover (a prover-version drift can change which VCs are
discharged, so results must always come from the pinned toolchain).  The
resolution works like this:

1. The version constraint is read from the manifest (`^16.1.0` -> `16.1.0`;
   the leading operator is stripped because `alr -n get` accepts a bare
   version only).
2. adacovex looks for an already-deployed `gnatprove_<version>_<hash>/`
   crate under `~/.adacovex/toolchain/`.  One found, it is reused directly
   -- no download, no `alr exec`, and no composition of your project's
   whole dependency set (flaky third-party downloads can never fail a
   proof run).
3. Not deployed yet: adacovex runs `alr -n get gnatprove=<version>`
   **into `~/.adacovex/toolchain/`** (not into your project's workspace)
   and prints a progress line -- the first deployment downloads a ~130 MB
   bundle and may take a minute on a slow link.  It is one-time per
   version: every later run (and every other project pinning the same
   version) reuses the deployed binary.  A deployment that fails is a
   failed run, never a silent fallback.
4. The deployed gnatprove is run with its `bin/` prepended to `PATH` so
   the solvers it ships (Z3, CVC5, Alt-Ergo) resolve.

The deployment is keyed by the exact version, so two projects pinning
different gnatprove versions keep both toolchains side by side under
`~/.adacovex/toolchain/` without interfering.  A manifest that declares
gnatprove with an unparseable version expression fails loudly rather than
guessing.

Projects that do *not* declare gnatprove fall back to (in order): a global
pin (`ADACOVEX_GNATPROVE_VERSION`, or `[prove] gnatprove-version` in
`~/.adacovex/adacovex.toml`, deployed through the same `alr -n get` path),
a gnatprove on `$PATH`, a cached toolchain in `~/.adacovex/toolchain/`, and
finally the platform toolchain download.  `adacovex status` reports which
tier applies without deploying anything.

## Option 2: `alr install` (global, to `$PATH`)

```bash
alr install covex gnatprove
export PATH="$HOME/.local/bin:$PATH"
```

`covex` is the Alire crate name for adacovex
([crate page](https://alire.ada.dev/crates/covex)). Once on `$PATH`, it scans
the current directory by default. A `gnatprove` installed this way is picked up
from `$PATH` by `covex prove` when the target project declares no manifest
dependency of its own.

## Option 3: download a release bundle from GitHub

Every `vX. Y. Z` tag publishes `adacovex-vX. Y.

Z.tar.gz` on the [GitHub Releases page](https://github.com/bladeacer/adacovex/releases).

```bash
curl -fsSL https://raw.githubusercontent.com/bladeacer/adacovex/main/install.sh | bash
```

Bundles are attested with [`actions/attest`](https://github.com/actions/attest).

> Release binaries are **Linux x86-64 only**. Other platforms build from source
> via Alire (see [Platforms](platforms.md)).

## Building from source

```bash
git clone --depth 1 https://github.com/bladeacer/adacovex.git
cd adacovex && alr build   # or: --branch vX.Y.Z for a released tag
```

`alr build` produces `bin/adacovex` (with a `bin/covex` alias). A stock Alire
toolchain (`gnat_native` + `gprbuild`) plus the standard GNAT runtime is all
that is needed. No other dependencies. (Contributors use the richer
`make build` workflow; see the [developer guide](../contributing/developer-guide.md).)

## Version source per installation method

`adacovex --version` (and the man page, the SBOM tool version, and the result
cache namespace) resolve the version from `tools/gen-version.py`. The version
depends on the installation method:

1. `ADACOVEX_VERSION` -- release builds (the shipped binary always reports the
   tag it was built from).
2. `alire/alire-dev.toml` -- source checkouts (`version = "x.y.z"`).
3. `alire.toml` -- dependency-managed installs: the toml associated with the
   `covex` binary for dependency management carries the release version.

## Keeping the man page in sync

`adacovex man` installs the man page (which embeds the version) into
`~/.local/share/man`. It refreshes `mandb` when present. `adacovex man
--check` exits 0 when the installed page matches the binary. A shell prompt
hook can auto-update. `man --force` overwrites an up-to-date page (for example
to repair a hand-edited one).

When man-db is missing, the page still installs. Read it with
`man -l ~/.local/share/man/man1/adacovex.1`. `adacovex status` reports mandb
availability up front. See [Platforms -- local man page](platforms.md#local-man-page-linuxwsl)
for the install roots and man-db behaviour.
