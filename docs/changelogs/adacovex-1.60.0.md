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

A `platform-build` job builds the tree with a plain `alr build` and runs the
native suite on macOS and Windows, on the same consumer path Alire's
crate-index CI exercises. It lives in the release workflow, so a release tag
starts it and it gates the publish step. That job is the evidence behind the
non-Linux rows of the platform matrix, and the release `summary` job reports
it with the other gates.

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

### C5: Every CI gate runs as plain Python

The workflows no longer need `make` or `just` on a runner. Each gate job
invokes `python3 tools/tasks.py <task>`, the same recipe `just <task>` runs
locally, and the Ubuntu runner images ship `python3`. The invocation and the
release-only platform matrix are recorded in `docs/usage/ci-cd-workflows.md`
and the platforms page.

### C6: `just check` reports every gate instead of stopping at the first

A missing developer tool now skips its gate with the reason instead of
failing it. The formatter and API-docs gates probe `gnatformat` and
`gnatdoc` through the manifest swap that puts them on `PATH`, and the
offline-manual gate checks that the interpreter can import `sphinx`. The run
continues past a failed gate, prints a PASS/FAIL/SKIP summary, and exits
non-zero only when a gate failed.

### C7: A printed report never mixes path separators

`Adacovex.Paths.Display` presents a path in the host's separator style. On
Windows every `\` becomes `/`; on POSIX both characters stay as they are,
because `\` is then an ordinary file-name character. The status rows, the
complexity file table, and the parser diagnostics run every printed path
through it, and the result keeps the path's length, so a display row never
shifts a column.

### C8: The documentation names `just <task>` everywhere

The developer documentation, the changelogs, the README, the tldr page, and
the user-facing tool messages now name the `just` task for a command. Four
references stay on `make` on purpose: the SBOM's curated-tool name, GNU
Automake's own `make check` example, the scanner's matching-semantics
sentence, and another repository's `make prove` target. The `justfile`
gained a `help` recipe, so `just help` lists the tasks as `make help` did.

### C9: The developer workflow survives a Windows host

The sync and generator scripts write LF (`newline="\n"` on every writer), so
a Windows run no longer puts carriage returns into tracked files. The
release, version, and test gates resolve a `.cmd` or `.bat` stand-in for a
fake tool binary, and the dev-tool tests drive their fixtures through Python
instead of the platform shell.

The ascii gate scans git-tracked, non-ignored files, so a gitignored build
product cannot fail it. The test report is normalised to LF after every run.

## Fixes

### H1: The generated man page named the old cache path

The man page embedded `~/.adacovex/cache` in its FILES section, which the
platform-directory change made wrong. It now names `~/.cache/adacovex`, the
Linux default that the man page carries, and states that this is the platform
cache directory.

### H2: The prover-pin readers failed on a CRLF checkout

`File_GNATprove_Version` and `Global_GNATprove_Pin` compared a line with a
trailing carriage return against its bare value, so a checkout with CRLF
line endings lost the pinned gnatprove version and the self-assessment CI
job failed. Both readers now strip the carriage return, and the committed
tree is renormalised to LF, so a fresh clone cannot carry the problem.

### H3: An unknown timezone passed as a UTC offset on macOS and BSD

The offset probe read `zdump` or `date` output and, when the tool printed an
unrecognised message instead of erroring, fell back to a zero offset and the
run continued in the wrong zone. The probe now checks the zone name against
the platform's zoneinfo database and rejects an unknown zone before it
formats a date.

### H4: The action's cache-path text carried a control byte

`action.yml` spelled the Windows cache path with a `\a` that had been stored
as a BEL control byte, so the comment read `%LOCALAPPDATA%dacovex\cache`, and
two cache-input descriptions named the cache by placeholder rather than by
its platform directory. The byte is removed and both descriptions now name
the platform cache directory.

## Test Suite

1818 tests across 27 categories, up from 1815 across 27 in 1.59.0. The three
extra checks cover `Adacovex.Paths.Display`, the display normaliser, and the
cache tests already rebuild the stamp and probe paths from the platform cache
directory, so they cover the new layout on every host.

`just test` runs the native suite, `just cli-e2e` runs the end-to-end suite,
and the release workflow's `platform-build` job runs the native suite on
macOS and Windows. The tools test suite (`just tools-check`) drives its
fixtures through Python instead of the platform shell, so it also runs on a
Windows host.

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
`Adacovex.Cache` (`HLR-CACHE`), `Adacovex.Prove` (`HLR-PROVE`),
`Adacovex.Timezones` (`HLR-TZ`), `Adacovex.Renderers.Man`
(`HLR-RENDER-MAN`), the complexity report (`HLR-COMPLEXITY`), and the line
reader (`HLR-SCAN`). C3 through C9 change no requirement: they change the CI
that proves the tree, the runner that gates it, and the documentation that
describes it.
