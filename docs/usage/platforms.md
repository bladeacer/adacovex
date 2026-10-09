# Platforms and the `status` subcommand

adacovex runs on any host that satisfies three requirements:

- a C compiler exposing the Ada 2012 / SPARK 2014 runtime (GNAT, LCC,
  or anycompiler),
- `GNAT.OS_Lib` (the GNAT runtime's run-time library path, or a
  `gprconfig` override), and
- a target project root that holds an Alire manifest, an Alire
  `alire.lock` or `alire-dev.toml`, or a GNAT project file.

## Supported platforms

adacovex is built and tested on these platforms:

| Platform | Architecture | Status |
|----------|--------------|--------|
| Linux | x86_64 | Supported, tested daily |
| Linux | i686 / 32-bit | Supported (buffer limits and all `Integer` conversions widen with the host word size) |
| Linux | ARM, ARM64, RISC-V, s390x, ppc64, and niche combinations | Supported (host-word-sized buffers; verified per architecture on each release) |
| Windows | x86, x64, ARM, ARM64 | Supported (build and run; the `Status` page reports the detection path used) |
| macOS | x86_64, ARM64 | Supported |
| FreeBSD, OpenBSD, NetBSD | x86_64, ARM | Supported |
| WSL1, WSL2 | x86_64 | Supported (appears to the tool as Linux) |

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
- never assumes the host word size when it converts a `File_Time_Stamp`
  or `Current_Time` value: `GNAT.OS_Lib.To_C` produces a
  `Long_Long_Integer`, and that is the only numeric form carried in the
  tree;
- resolves the GNATprove job count from the detected core count and
  honours the `CI` environment variable so CI uses every core and a
  developer machine keeps two cores free;
- keeps every path, line, and description buffer bounded at compile
  time, with overlong input failing loudly (skipped, count incremented,
  DAL unmet) instead of silently truncated.

## The `status` subcommand

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
alr install
alr build
sudo make install
```

The shipped binary carries the version of the manifest it was built
from: `ADACOVEX_VERSION` for release builds, `alire-dev.toml` for
source checkouts, and the `alire.toml` associated with the installed
binary for dependency-managed installs. See
[Installation](installation.md) for the full method matrix and the
`--version` output.
