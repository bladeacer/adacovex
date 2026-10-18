# adacovex 1.62.0

Date: _2026-10-13_

Version bumped 1.61.0 -> 1.62.0.

<!-- no-covex-docs-loc: release record, line cap does not apply -->

## Changes

### C1: The test suites run with the network unplugged

`ADACOVEX_OFFLINE` gates the ecosystem-metadata resolver, so a gate run
spawns no package-registry CLI and reads no metadata cache. The native
runner and the end-to-end `run()` helper set it for every child process,
and three new checks pin the offline shape of the resolver.

An execve trace of the whole native suite now shows zero registry-CLI
spawns. `just check` no longer refreshes a crate index mid-run, so the
`git-credential-oauth` helper can no longer open a browser while a gate
runs.

### C2: Every supported manifest parses structurally

The manifest readers matched substrings: `File_Quoted_Value` searched a
whole file for the first `"key"=` or `"key":` pair, so a key of another
section, a commented line, or a key inside a string value could answer.
It is deleted. `Json_Top_Value` tracks brace depth and string state,
`Toml_Section_Value` reads only its own `[section]`, and
`Collect_Json_Section_Names` collects only the keys directly inside a
root-object section.

`Pnpm_Importer_Version` walks pnpm-lock.yaml by indentation, and the new
`Collect_Go_Requires` reads only require directives, so the contents of
a replace or exclude block and a commented-out require never register.
The curated tool scan still matches whole words on both sides of a
match, and `air` joins the table, so a project that references it from
its Makefiles or its air config registers it when it is installed.

### C3: The root project's npm and Go declarations register

A project that keeps no install tree in the repository now reports the
dependencies its own manifests declare. `package.json` `dependencies`
register as base scope and `devDependencies` as dev scope when no
`node_modules` tree exists, and the resolved version comes from the
root importer blocks of `pnpm-lock.yaml` when the lockfile is there.

`go.mod` registers as well: a direct require is base scope, a
`// indirect` require is transitive, and a test-named module such as
`github.com/stretchr/testify` keeps the test label. Each module carries
the version go.mod states under a `pkg:golang/<module>@<version>` purl.
An installed tree stays authoritative, so a package or module it
already resolved is never registered twice.

### C4: adacovex registers as a dependency of the projects it audits

A project that references `adacovex` or its `covex` alias from a build
file, a workflow, or a manifest now carries adacovex in its own
dependency graph. The running binary is the dependency, so the
reference alone registers it: under the canonical name `adacovex`, the
bundled version, and a `pkg:generic/adacovex` purl. A reference to the
`covex` alias collapses into that one component.

Three rules order the classification. A project that is adacovex itself
never carries itself as a component. A manifest that declares
`adacovex` or `covex` keeps its own scope, so a publishing manifest
stays `base` and a dev manifest stays `dev`. Otherwise the installation
method of the running binary decides: a source build registers as
`dev`, an Alire global install or a binary on `PATH` registers as
`system`.

The rules are pinned in both directions by fixtures, so a
parsing regression fails a gate instead of a manual run.

### C5: `status` reports how adacovex is installed

`adacovex status` prints the installation method of the running binary
and the path it was invoked from: `source-checkout` for a binary built
inside an adacovex source tree, `alire-global` for a binary under a
global `alr install` prefix, and `on-path` for every other binary. The
JSON export carries `install_method` and `install_path`, and the
metrics output carries the same two keys, so the three outputs never
drift. The report uses the same rule C4 uses in the dependency graph,
so the two answers always agree.

### C6: The dashboard serves server info and a health probe

Two new routes answer for the running server instead of the assessment.
`GET /health` is the liveness probe for scripts: it answers `200 OK` with
`{"status": "ok"}`. `GET /api/info` reports the bundled version, the audited
target, the selected standard, the bound port, the worker count, the
uptime, the result-cache counters, the assessment wall time, and the
request counters.

The counters live in one protected store that the worker tasks share, so
concurrent requests never race on an increment. Every route carries a
served count and a 404 count, the `*` entry names the bucket of every path
the server does not dispatch on, and the keep-alive count records the
connections that stayed open. The payload is a snapshot, so no lock is
held while a socket write blocks.

`/api/metrics` keeps its assessment shape: the server's own state moved to
`/api/info` instead of growing the metrics payload. Both new routes join
the `/api/endpoints` catalog, so the API playground lists them with the
rest, and both land with native routing, counter, and payload checks plus
end-to-end checks against a live server.

### C7: `tldr` installs the cheat sheet into the local client

`adacovex tldr` installs the tldr cheat sheet into the local tldr client, so
`tldr adacovex` works offline. The page is authored once, in
`docs/tldr/adacovex.md`, and `tools/gen-tldr.py` bundles it into the binary as
`Adacovex.Tldr_Template`. `just tldr-check` now lints the page and fails when
the embedded spec drifts from it.

The installer is client agnostic. tealdeer is detected from `tldr
--show-paths`, and the page goes into its flat custom pages directory, which
lives outside the cache, so `tldr --update` cannot remove it. A client that
follows CLIENT-SPECIFICATION is detected from `tldr --version`, and the page
goes into its cache pages tree, in both the common and the platform
directory. The platform directory is the tldr-pages name for the host:
`linux`, `osx`, `windows`, `android`, `sunos`, or a BSD name. The Node
client's own cache tree is used when it exists.

The write is byte exact: it uses a stream, because Ada.Text_IO completes the
last line at close and would add a byte to the page. `adacovex tldr --check`
exits 0 when the installed page matches the bundled one, and 1 when it is
missing or stale, so a prompt hook can refresh it after `tldr --update`.
`--force` always rewrites the page. With no supported client the command
prints the page to stdout, so it never answers nothing.

### C8: The man page installer follows the host reader

`adacovex man` no longer assumes man-db. It installs into the first
home-owned `$MANPATH` entry, so a root the reader already searches wins,
otherwise into the platform data root: `$XDG_DATA_HOME/man` on Linux and
the BSDs, `~/Library/Application Support/man` on macOS, and `%APPDATA%\man`
on Windows. `--dir=PATH` still overrides both.

The index refresh tries `mandb` (man-db) and falls back to `makewhatis`
(mandoc), so the command reports the tool that ran instead of claiming the
database could not be refreshed on a BSD or macOS host. The command also
checks the chosen root against `$MANPATH` (or `manpath` when the variable
is unset) and warns with an exact `man -l` command when the reader does not
search it. `adacovex status` reports both indexers.

The platform matrix, the root selection, and the upstream reader links 
are in [Platforms -- local man page](../usage/platforms.md#local-man-page).

### C9: The differential modes run on native Windows

The differential modes (`--compare-base` / `--coverage-delta`) drove every
snapshot command through `sh -c`, so a native Windows host needed WSL,
Cygwin, MSYS2, or Git Bash before a base revision could be compared. That
contradicted the platform matrix, which lists Windows as a first-class
platform.

`Adacovex.VCS` now builds its command lines for the shell the host actually
runs: `sh -c` on POSIX hosts and `cmd /c` on Windows. The path quoting, the
change-directory prefix (`cd /d` on Windows, so a drive change works), and
the discard device (`NUL` versus `/dev/null`) all follow one
`Shell_Family` parameter, so both shapes are pinned by tests on every host.
The one POSIX-only step is gone: the fossil snapshot copies its repository
database in Ada instead of shelling out to `mkdir` and `cp`, and the Windows
directory removal uses `rmdir /s /q` instead of `rm -rf`.

A Windows host now needs no POSIX layer for any part of adacovex.

### C10: The user docs document gnatprove.sarif and read shorter

`gnatprove.sarif` had no user-facing documentation, so the second artefact
of every proof run was invisible to readers of the manual. The
`spark-coverage` section of the CLI reference now explains what the file is
(the OASIS SARIF format, one result per reported check), where it lives
(`<target>/obj/gnatprove/gnatprove.sarif`), and how to open it outside
adacovex (editor SARIF viewers, GitHub code scanning), and the proving guide
carries the matching section; the two pages cross-link both ways.

`docs/THIRD_PARTY_NOTICES.md` credits OASIS SARIF beside CycloneDX and SPDX
as a referenced, never-vendored specification, and **SARIF** plus
`gnatprove.sarif` enter the STE100 Technical Name dictionary before the
terms are used.

The five longest pages then lost their fat with context and meaning kept:
`sbom-resolution` (-168 words), `dashboard-html` (-91), `cli-reference`
(-30), `architecture` (-28), and `cli-reference-flags` (its old prose lost
about as much as the new SARIF section added, so the page total barely
moved while every paragraph read shorter). Every gate stayed green: docs
coverage, links, paragraph rule, STE rules, and British spelling.

### C11: The docs Python dependencies have one source and one bootstrap order

The docs dependency list lived only in `requirements.txt`, so a second
declaration would have drifted from it. `pyproject.toml`
(`[project].dependencies`) is now the single source, and the committed
`requirements.txt` is generated from it by the new
`tools/update-requirements.py` -- it stays committed because
`.readthedocs.yaml` and `pip install -r` consume it. The new
`requirements sync` gate in `just check` runs the generator in `--check`
mode and prints the unified diff on drift, `just requirements`
regenerates the file, and `requirements` joined `just sync`. The rendered
file keeps the Read the Docs header and the same three dependency lines,
so no reader of it sees a change beyond the generated-file note.

The docs-bundling venv also bootstraps in one documented order
(`just docs-venv`): `uv` when present, else the project's
`install.sh --python-venv` (a new install.sh mode that creates `.venv` and
installs `requirements.txt` into it), else `python3 -m venv` plus pip. The
absolute `venv-bin` path and the Python 3.13 relative-`sys.prefix`
`RuntimeWarning` fix are unchanged, and `.venv/Scripts` still wins on
Windows. The order is pinned by tests and documented in the contributor
guide.

### C12: The 1.62.0 proof timing is recorded with its load

The prove figures for this release are measured on this machine on the
release profile with `/proc/loadavg` recorded beside each sample: prove warm
54.1 ms +/- 3.2 ms (15 hyperfine runs plus two warm-ups) and prove cold
64.5 s +/- 4.2 s (59.7-67.6 s across three runs with the result cache and
the gnatprove session wiped each time), both at 1054 VCs with 0 unproved.
The reading notes of the prove-timing page carry them beside the open
phase. They are noted rather than promoted: the phase table keeps its three
rows and 1.58.0 keeps the open phase's representative, because the
collation into the next phase is deferred to 1.63.0. The full record, with
both samples and their loads, is `perf-analysis-1.62.0.md` at the repository
root, beside the 1.61.0 one.

## Fixes

### H1: An installed package's own subpackages and source trees are no longer components

The vendored walk descended two levels and componentised every
directory it reached, so one installed package reported its bundled
`v4`, `locales`, `src`, `lib`, and `dist` directories as five separate
dependencies of the project that uses it.

A level-2 directory now becomes a component only when it carries its
own ecosystem manifest and its parent carries none. Such a parent is a
container -- an npm scope, a composer vendor name, or a Go import-path
host -- and the packages below it are real dependencies. Anything else
at that depth belongs to the package above it and stays out of the
graph.

### H2: The tools test suite runs again

Commit `7a5a283` replaced `tools/tests.py` with a 141-line tldr scratch
script, so `just tools-check` exited 0 while running none of the suite's 178
tests -- the gate looked green and checked nothing. The file is restored to
the full multi-class suite, and the eight requirements-sync checks of C11
join it, so `just tools-check` runs 186 tests again.

## Test Suite

2017 tests across 30 categories, up from 1864. Forty earlier checks in
this release cover the structural readers, the package-root rule, and the
root npm and Go declarations. Fifteen more pin adacovex as a
dependency in both directions, and the new `Install method` category
holds 23 checks for the classifier, the scope rule, and the filesystem
walk behind them. The `Server routing` category grows to 180 checks: the
two new routes and their near misses, the `Route_Path` round trip over
every route kind, the protected counter store, and the `/api/info`
payload.

The new `tldr installer` category holds 48 checks: client classification,
the `--show-paths` parse with its annotation, the per-client path rules, the
`uname` mapping for Linux, macOS, the BSDs, Android, SunOS, and the Windows
shells, and the install and read-back round trip in a temporary tree. The
`Man page renderer` category grows to 30 checks: the man path split and the
home-owned entry rule, the default root, and the indexer contract. The
`VCS support` category grows to 37 checks: both shell families pin their
quoting, their change-directory prefix, and their discard device, so the
Windows command shape is asserted on a POSIX host and the POSIX shape on a
Windows host. `just test` runs the native suite, and `just cli-e2e` runs 87
end-to-end checks, including two new component-set shapes (a pnpm workspace
and a Go module), three checks against the live `/health` and `/api/info`
endpoints, and seven that install the page into a fake tealdeer client and a
fake base client and compare it byte for byte. `just tools-check` runs the
186-test tools suite (restored in H2, plus the eight requirements-sync
checks of C11).

## Proof Results

**Platinum**, 0 unproved, 0 justified, **1054 of 1054 VCs across 75
analysed units** under gnatprove 16.1.0 at `--level=4`. The count grows
by six checks and three units over the shipped 1048: the new
`Adacovex.Install` classifier is proved, from its machine token over the
prefix rules and the scope rule to the index arithmetic behind them, C6's
two route branches and its `Route_Path` mapping add two checks to the
proved `Route` surface, and C9's three host-platform shell helpers
(`Is_Windows` plus the command, flag, and discard-device answers) each
carry their `GNAT.OS_Lib.Directory_Separator` input in a Global aspect,
which SPARK RM 6.1.4(15) requires of a deferred constant. No existing
unit lost a check.

The new parser bodies sit in the manifest package's default-off body, C6's
counter store and `/api/info` renderer in the server package's default-off
surface, and C7's installer in the same file-system surface. None of them
contributes verification conditions.

## Traceability

One new HLR record enters this release: `HLR-TLDR` (client-agnostic tldr
page installation), traced by `LLR-TLDR-01` for the client detection and
`LLR-TLDR-02` for the install and the read-back comparison. The
dependency-graph parsing work extends `HLR-MANIFEST` and `HLR-SBOM`, both
on record for the graph and its output. The new
`Adacovex.Install` package carries `HLR-MANIFEST`: it decides how a
project's reference to adacovex is classified. C9 extends `HLR-DIFF`, whose
requirement is the comparison itself.

The status report adds no requirement: it reports state and never assesses it.
The hermetic suite changes no requirement: it changes the tests that gate
the tree. The requirements single-sourcing and the tools-suite restore
(C11, H2) change no requirement either: they change the files that gate
the tree.

The packages changed by this release, and the tags on record that cover
them: the manifest parsers and the dependency graph (`HLR-MANIFEST`), the
SBOM they feed (`HLR-SBOM`), the dashboard server routes and its API
(`HLR-SERVER`), the tldr installer (`HLR-TLDR`), the differential-mode VCS
abstraction (`HLR-DIFF`), and the task gates (`HLR-ARCH`).
