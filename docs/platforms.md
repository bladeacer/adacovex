# Platform support

adacovex is a zero-dependency Ada/SPARK binary: it uses only the GNAT runtime
and the standard library, so any platform with a working GNAT/Alire toolchain
can build and run it. adacovex itself makes no OS-specific assumptions beyond
the CPU-core and CI detection described below, which degrade gracefully to
single-core operation when the host cannot be probed.

## Supported platforms

| Platform | Status | Notes |
|----------|--------|-------|
| Linux x86-64 | **Primary** | CI, releases, and the proof toolchain bundle all target it. |
| **WSL** | **Supported** | Runs on the Linux/WSL targets below: `man` installs to the WSL man root and `mandb` refreshes it; VCS snapshot commands run via `sh -c`. |
| Linux aarch64 | Supported | Builds from source; the prebuilt toolchain bundle is x86-64 only. |
| macOS | Supported | Builds from source (Intel and Apple Silicon). |
| FreeBSD | Supported | Builds from source. |
| Windows | Supported | Builds from source; core detection uses the Windows env var + PowerShell fallback. |

## Release binaries

The CI **release binary is Linux x86-64 only for now**. The
`adacovex-vX.Y.Z.tar.gz` bundle (`adacovex` + the `covex` alias) and the
prebuilt GNATprove toolchain asset are built on `ubuntu-latest`. Every other
platform builds adacovex from source via Alire (`alr build`) -- see
[Installing adacovex](README.md#installing-adacovex).

## CPU core-count detection

`Adacovex.CPUs.Detect_Core_Count` returns the number of logical processors on
the host, falling back to `1` when the host cannot be probed. Detection order
(pure GNAT runtime, no external library):

1. **Linux** -- count `processor` entries in `/proc/cpuinfo`.
2. **macOS / FreeBSD** -- `sysctl -n hw.ncpu`.
3. **Linux fallback** -- `nproc`.
4. **Windows** -- the `NUMBER_OF_PROCESSORS` environment variable.
5. **Windows fallback** -- a PowerShell CIM query
   (`Get-CimInstance Win32_ComputerSystem`).

Each stage falls through to the next on failure; exhausting all of them
returns `1` (safe: adacovex still runs, just single-threaded).

## CI detection and prove parallelism

`Adacovex.CPUs.Is_Running_In_CI` detects the CI markers set by GitHub Actions,
GitLab CI, Azure Pipelines, Buildkite, CircleCI, Travis CI, AppVeyor, Jenkins,
and the generic `CI` variable.

GNATprove parallelism resolves as:

- `--jobs=N` (`N > 0`) -- exactly `N` jobs.
- `--jobs=0` / `-j0` -- all cores (`gnatprove -j0`).
- default (`--jobs` omitted) -- **all cores inside CI**, otherwise
  `max(1, cores - 2)` so a developer machine keeps two cores free for the
  system.

The chosen basis is printed in the verbose log (`Jobs_Justification`) and in
the [`status`](#status-subcommand) report, so a proof run is auditable.

## `status` subcommand

`adacovex status` reports the toolchain + platform state without running any
assessment and **without downloading or deploying anything**:

```
adacovex status --target=PATH
```

It checks and prints:

- whether **Alire** (`alr`) is installed on `$PATH`;
- whether **gnatprove** is dependency-managed (target manifest pin) or
  detectable (global pin, on `$PATH`, or cached in
  `~/.adacovex/toolchain`);
- the **logical CPU count**, **CI status**, and the resulting default
  `-j` parallelism;
- a **VCS report**: which VCS command-line tools are available on `$PATH`
  for the differential modes (git, mercurial/`hg`, subversion/`svn`,
  fossil, jj, and the man-page tool `mandb`), the VCS detected for the
  target repository, a note when the target's VCS tool is missing, and a
  note when man-db (`mandb`) is absent -- so you know up front that
  `adacovex man` can install the page but cannot refresh the man database;
- the release-note that the CI binary is Linux x86-64 only.

Base adacovex functionality (scanning, proof analysis, test parsing,
compliance assessment, SBOM generation, dashboards, caching) does **not**
require a version control system; a VCS is only needed for the differential
modes (`--compare-base` / `--coverage-delta`).

Exit code `0` when a usable gnatprove is detectable without a download (and
`alr` is present whenever the deploy path is the only option), `1` otherwise.
The VCS report is informational and does not affect the exit code.

## Local man page (Linux/WSL)

`adacovex man` installs the man page into the **local man database** without
root: the default root is `$XDG_DATA_HOME/man` when set, else
`~/.local/share/man` (the standard Linux/WSL per-user man tree), and the
index is refreshed with `mandb` when it is present (Ubuntu and WSL ship it).
When man-db is **not** installed (or `mandb` fails), adacovex prints a
warning that the database was not refreshed -- the page is still installed
and readable with `man -l ~/.local/share/man/man1/adacovex.1` -- and
`adacovex status` reports whether `mandb` is on `$PATH` up front.
`--dir=PATH` overrides the root. The page embeds the binary version;
`adacovex man --check` compares it to the installed page and exits 0/1, so a
prompt hook can auto-install when a newer version is available. See
[CLI reference](cli-reference.md#man).

## VCS support (Linux/WSL)

`--compare-base` and `--coverage-delta` snapshot a base revision across
git, Mercurial, Subversion, Fossil, and jj (see
[VCS support](vcs.md)). The snapshot commands run through `sh -c`, which
WSL provides, and all temp snapshots live under `/tmp/adacovex-diff-<pid>`.
For VCS with poor snapshot UX (Subversion, Fossil) adacovex prints a note
recommending conversion to git.

See the [CLI reference](cli-reference.md) for the full flag surface.
