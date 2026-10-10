# Platforms and the `status` subcommand

adacovex runs on any host that satisfies three requirements:

- a C compiler exposing the Ada 2012 / SPARK 2014 runtime (GNAT, LCC,
  or anycompiler),
- `GNAT.OS_Lib` (the GNAT runtime's run-time library path, or a
  `gprconfig` override), and
- a target project root that holds an Alire manifest, an Alire
  `alire.lock` or `alire-dev.toml`, or a GNAT project file.

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
base revision through the VCS command itself and need a POSIX shell (`sh`) to
run their snapshot command. They therefore work on Linux, the BSDs, WSL, and
macOS, and on Windows only from a shell that provides one (WSL, or Git Bash).
The `man` subcommand installs into a local man database and is Linux/WSL only.
Every other feature works on every platform above.

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
- **GNAT compiler**: detected version and the target word size;
- **GNATprove**: dependency-managed or `PATH`-detected, plus the
  resolved proof level;
- **CPUs**: logical core count and the default `(--jobs)` job count
  (all cores in CI, `cores - 2` otherwise);
- **CI**: whether the `CI` variable or one of the known CI markers is
  set;
- **VCS**: the detected source-control tools for the differential
  modes (`git`, `hg`, `svn`, `fossil`, `jj`) plus `mandb` for the man
  page installer.

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

## Release binaries

The `install.sh` script and the GitHub Releases bundle ship a prebuilt
`adacovex` binary. The bundle is Linux x86-64 only, and every other platform
builds from source. Each archive is attested with `actions/attest`, so the
provenance of a downloaded binary is verifiable.

## Local man page (Linux/WSL)

`adacovex man` installs the man page into `$XDG_DATA_HOME/man` (default
`~/.local/share/man`), or into `--dir=PATH` when that flag is given. It
refreshes the `mandb` database when man-db is present and prints a warning
when it is not. Read the page with `man -l ~/.local/share/man/man1/adacovex.1`
when `mandb` is missing. The installer is Linux/WSL only.
