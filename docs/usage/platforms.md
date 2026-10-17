# Platforms and the `status` subcommand

adacovex supports any platform that can run alire: packaging and delivery go
through Alire, so adacovex runs wherever Alire itself builds. The tool targets
Ada 2012 and later together with SPARK 2014, and uses only the GNAT runtime, so
nothing in adacovex itself is platform-specific.

adacovex runs on any host that satisfies these requirements:

- the GNAT toolchain to build it (the GNAT runtime is linked into the binary;
  a prebuilt binary needs only the GNAT runtime), and
- `GNAT.OS_Lib` from the GNAT runtime - adacovex uses it for path separation,
  temp files, environment variables, and locating executables on `PATH`
  (a `gprconfig` override can redirect the runtime path).

No target manifest is required to run an assessment: the pipeline works on any
directory of Ada source. An Alire manifest (`alire.toml`), an `alire.lock` or
`alire-dev.toml`, or a GNAT project file is only needed for SBOM generation and
the dependency graph, which degrade gracefully (a warning, not a failure) when
absent.

## Supported platforms

Three columns say three different things. **Officially supported** is the
promise: a defect on that platform is a release blocker. **Run by the
maintainers** is the evidence: a maintainer builds and runs the native suite
and, where the job exists, the SPARK proof there. **Alire index CI** is what
Alire's own crate-publishing checks exercise on a pull request against the
community index, which is the public proof that the crate installs and builds
for that platform.

The `platform-build` job in `.github/workflows/release.yml` builds the tree
with a plain `alr build` and runs the native suite on macOS and Windows,
which is the evidence behind the **Run by the maintainers** column. It runs
only when a release tag is pushed: the publish job waits for it, so an
ordinary push or pull request never pays for the two extra runners and a
release never ships a binary the other platforms could not build. It uses
the same build path a consumer and Alire's crate-index CI use, so a green
job means the crate installs and builds on that platform without the local
`just` tooling.

| Platform | Architecture | Officially supported | Run by the maintainers | Alire index CI |
|----------|--------------|----------------------|------------------------|----------------|
| Linux | x86_64 | Yes | Yes (the release platform; full `just check`) | Yes |
| Linux | ARM64 | Yes | No (cross-architecture verification on each release) | Yes |
| Linux | i686, ARM, RISC-V, s390x, ppc64, and other combinations | Yes (host-word-sized buffers) | No | Yes, for the architectures Alire builds |
| Windows | x86_64 | Yes, built from source (no prebuilt bundle yet) | Yes (the second development platform; native suite in CI) | Yes |
| Windows | x86, ARM, ARM64 | Best effort (the same source, no prebuilt bundle) | No | Yes, for the architectures Alire builds |
| macOS | x86_64, ARM64 | Best effort, no prebuilt bundle | Yes (native suite in CI) | Yes |
| FreeBSD, OpenBSD, NetBSD | x86_64, ARM | Best effort (XDG directories, GNAT runtime only) | No | No (Alire does not publish binaries there) |
| WSL1, WSL2 | x86_64 | Yes (the host appears as Linux) | Yes | Covered by the Linux rows |

The prebuilt release bundle is Linux x86-64 only. Every other platform builds
from source with `just build` (`alr build` for the plain Alire route).
macOS is not a priority platform, and it is not a large gap: it shares the
POSIX path model with Linux, and `Adacovex.Paths` already answers its
`~/Library` directory convention, so the source builds there unchanged.

The **differential modes** (`--compare-base` / `--coverage-delta`) snapshot a
base revision through the VCS command itself. They run through the host shell:
`sh -c` on Linux, the BSDs, macOS, and WSL, and `cmd /c` on native Windows.
A Windows host therefore needs no WSL, Cygwin, MSYS2, or Git Bash for them.

The `man` and `tldr` subcommands follow the readers and clients that the host
runs; see [Local man page](#local-man-page) and
[Local tldr page](#local-tldr-page). Every other feature works on every
platform above.

## Platform-agnostic design

To keep the tool free of 32/64-bit and endian surprises, adacovex:

- derives every fixed-size buffer from `System.Word_Size` so a 32-bit
  host keeps proportionally smaller, still-large buffers and a 64-bit
  host keeps the classic values;
- stores time stamps and counters as `Long_Long_Integer` everywhere, so a
  value that fits on a 64-bit host cannot be shrank by an implicit 32-bit
  conversion on Win32 or ARM;
- delegates host CPU detection, temp directory resolution, and command
  capture to a single, pure GNAT runtime module (`Adacovex.CPUs`) whose
  platforms are listed in its specification;
- keeps every platform path decision in one place (`Adacovex.Paths`): both
  `/` and `\` separate components, a Windows drive letter (`C:\project`)
  and a UNC root count as absolute, `~` expands from `HOME` then
  `USERPROFILE`, the host executable suffix (`.exe` on Windows) is appended
  once, and a path is normalised to a canonical `/` form before it becomes a
  cache key;
- keeps every platform *directory* decision in the same place: the
  configuration, cache, and data directories follow the XDG specification on
  Linux and the BSDs, `~/Library` on macOS, and `%APPDATA%` /
  `%LOCALAPPDATA%` on Windows, with `ADACOVEX_STATE_HOME` as the one
  override (see [Global configuration and state](configuration.md));
- keeps a cache entry name a legal file name on every platform: a
  namespaced key (`scan:<sha256>`, `prove:<sha256>`, `tools-<sha256>`) writes
  its `:` as `-`, because Windows rejects `:` in a file name;
- never assumes the host word size when it converts a `File_Time_Stamp`
  or `Current_Time` value: every `GNAT.OS_Lib.To_C` result is carried as a
  `Long_Long_Integer` through an explicit conversion, so a 64-bit time
  stamp is never shrunk by an implicit 32-bit conversion on Win32;
- rises above Windows' small default main-thread stack: the build reserves
  32 MiB (`-Wl,--stack,33554432`) so a function that holds several large
  fixed-size line buffers in one frame cannot trip `STORAGE_ERROR`;
- resolves the GNATprove job count from the detected core count and
  honours the `CI` environment variable so CI uses every core and a
  developer machine keeps two cores free;
- keeps every path, line, and description buffer bounded at compile
  time, with overlong input failing loudly (skipped, count incremented,
  DAL unmet) instead of silently truncated.

## `status` subcommand

`adacovex status` reports platform and toolchain state without running
an assessment and without downloading anything:

- **Alire**: installed and the version it reports;
- **adacovex install**: how the running binary is installed
  (`source-checkout`, `alire-global`, `on-path`) and the path it was
  invoked from;
- **GNAT compiler**: detected version and the target word size;
- **GNATprove**: dependency-managed or `PATH`-detected, plus the
  resolved proof level;
- **CPUs**: logical core count and the default `(--jobs)` job count
  (all cores in CI, `cores - 2` otherwise);
- **CI**: whether the `CI` variable or one of the known CI markers is
  set;
- **VCS**: the detected source-control tools for the differential
  modes (`git`, `hg`, `svn`, `fossil`, `jj`) plus both man indexers
  (`mandb`, `makewhatis`) for the man page installer.

`status` never changes the working tree and never writes files, so it
is safe to run from a CI job or a packaging script before any
assessment.

## Installing on other platforms

The published installers cover the platforms above. To install on a
platform that has no installer, install the `alire` toolchain, then run:

```sh
git clone https://github.com/bladeacer/adacovex
cd adacovex
just build          # alr build + the version/dashboard generators
just test           # the native suite
just check          # every gate CI runs before a release
```

`just` is the task runner every target in this manual uses (`just --list`
lists them); the `Makefile` is a thin shim that delegates to the same tasks,
so an existing `make <task>` reference still works. A plain `alr build` also
builds the binary when `just` is not installed yet.

The shipped binary carries the version of the manifest it was built
from: `ADACOVEX_VERSION` for release builds, `alire-dev.toml` for
source checkouts, and the `alire.toml` associated with the installed
binary for dependency-managed installs. See
[Installation](installation.md) for the full method matrix and the
`--version` output.

**A Windows developer runs `just check` with the `fmt` gate skipped.**
`gnatformat` has no Windows binary in the Alire community index, so the
formatter gate SKIPs on Windows with the reason "gnatformat is not
available in the dev toolchain"; every other gate runs as usual. The
detail and the reason are on the [contributor
guide](../contributing/developer-guide.md#setting-up-the-repository).

## Release binaries

The `install.sh` script and the GitHub Releases bundle ship a prebuilt
`adacovex` binary. The bundle is Linux x86-64 only, and every other platform
builds from source. Each archive is attested with `actions/attest`, so the
provenance of a downloaded binary is verifiable.

## Local man page

`adacovex man` installs the man page into a man root that the host reader
searches, so `man adacovex` works without root. It does not depend on a
particular platform. It uses the reader that the host runs:

| Host | Man reader | Install root | Database refresh |
|------|-----------|--------------|------------------|
| Linux, WSL | man-db ([man-db](https://man-db.gitlab.io/man-db/)) | `$XDG_DATA_HOME/man` or `~/.local/share/man` | `mandb` |
| macOS | mandoc ([mandoc](https://mandoc.bsd.lv/)) | `~/Library/Application Support/man` | `mandb` when installed, otherwise `makewhatis` |
| FreeBSD, OpenBSD, NetBSD | mandoc | `$XDG_DATA_HOME/man` or `~/.local/share/man` | `mandb` when installed, otherwise `makewhatis` |
| Cygwin, MSYS2, Git Bash | the reader in that environment | the same environment's `$XDG_DATA_HOME/man` | `mandb` or `makewhatis` from that environment |

Native Windows has no man reader. Use WSL, Cygwin, MSYS2, or Git Bash to read
the installed page. The installer still runs on native Windows and writes the
page under `%APPDATA%\man`, but nothing reads it there.

The root selection follows the reader, not a fixed path:

1. The first home-owned entry in `$MANPATH`, when the user sets one. This is
the best choice because the reader already searches it.
2. Otherwise the platform data home plus `man` (the table above).
3. `--dir=PATH` overrides both.

After the install, `adacovex man` checks the root against `$MANPATH`, or runs
`manpath` when the variable is unset. When the root is not searched, the
command prints a warning and the exact `man -l` command to read the page.

It refreshes the index with `mandb` (man-db), then with `makewhatis` (mandoc)
when `mandb` is absent or fails. It prints which tool ran. When neither is
available, the page is still installed, the command prints a warning, and you
read it with `man -l`. `adacovex status` reports both indexers up front.

```sh
adacovex man                                  # install and refresh
adacovex man --dir="$HOME/.local/share/man"   # choose the root
man -l "$HOME/.local/share/man/man1/adacovex.1"
```

## Local tldr page

`adacovex tldr` installs the bundled page into the local tldr client. Both
client families publish their own platform list, and the installer follows the
client it detects:

| Client | Platforms (upstream) | Page location |
|--------|---------------------|---------------|
| tealdeer | Linux, macOS, Windows, FreeBSD, NetBSD | the custom pages directory from `tldr --show-paths` |
| base clients (C, Node, Python, tlrc) | Linux, macOS, Windows, Android, SunOS, FreeBSD, NetBSD, OpenBSD | the cache pages tree, under `common` and the host platform |

Upstream references: [tealdeer custom pages](https://docs.tealdeer.org/stable/usage_custom_pages.html)
and the [tldr client specification](https://github.com/tldr-pages/tldr/blob/main/CLIENT-SPECIFICATION.md).
The program reads the page directory from the client itself, so a non-standard
configured directory works too. Without a client it prints the page, so the
command always answers.

| Host (from `uname -s`) | Base-client platform directory |
|------------------------|-------------------------------|
| Linux | `linux` |
| Android (Termux) | `linux`, because Termux reports `Linux` |
| macOS (`Darwin`) | `osx` |
| FreeBSD, NetBSD, OpenBSD | `freebsd`, `netbsd`, `openbsd` |
| Solaris (`SunOS`) | `sunos` |
| Windows (native, Git Bash, Cygwin, MSYS2) | `windows` |

The installer writes the page to `common` and to the host platform directory,
so the two copies never disagree. A platform page shadows a stale common page,
and a common page covers an unknown platform. The Android pages are shared with
Linux in the tldr-pages repository, so `linux` is correct for Termux.
