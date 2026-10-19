# adacovex work plan

The live queue is the two sections below: v1.62.0 (the next release) and
v1.63.0. Every item is a check box: tick it when the code, the tests,
and the docs exist. Done work is removed as it lands; the release
history lives in `docs/changelogs/` and the performance history in
`docs/contributing/perf/`. Everything here was investigated on
2026-10-12 on the EndeavourOS machine (x86_64, 12 logical cores,
gnatprove 16.1.0).

## State of the tree (2026-10-12)

- `make check` is green on this machine: 28/28 gates PASS.
- v1.61.0 is shipped and consistent everywhere: manifests, binary,
  generated version spec, `sbom.json`, changelog, the proof ledger
  (1022/1022 VCs, Platinum, 0 unproved, 0 justified), and the native
  suite at 1821/1821.
- Fixed in the working tree with this pass (ships in v1.62.0):
  - `Scan_Project_Cached` skips `.` and `..` on its
    direct-enumeration fallback. Since the v1.61.0 perf commit lowered
    `Max_Dir_Entries` to 64, every directory with more than 64 entries
    takes that fallback, and without the guard the walker climbed into
    `..` and back down into the same subdirectory forever
    (`src/parsers/../parsers/../...`) until the path overflowed. This
    failed the `SBOM` and `SPARK proof` gates and crashed `covex sbom`
    against ocd, surge, seiri, and DankMaterialShell.
  - The `Max_Path` 64x -> 256x word-size change is consistent again:
    the types test expects `256 * System.Word_Size`, and the
    `Adacovex.Types` docstring and `docs/contributing/architecture.md`
    name 16384.
  - `test_runner` exits non-zero on a red suite, so `just test` and
    the `native tests` gate can actually fail (the red
    1820/1821 run of the perf commit had reported PASS).
  - `perf-analysis.md` is pure ASCII (the `ASCII` gate failure).
  - Test counts re-synced tree-wide after the suite went 1821/1821.
  - Commit conventions adopted kibtab-style: the full type table,
    component scope table, rules, and suggest-workflow live in
    `docs/contributing/commits.md` (published on Read the Docs);
    `CONTRIBUTING.md` links the deployed page and `AGENTS.md` links
    the relative path.

## Recorded: `make check` does trigger the OAuth workflow

Sampled twice per second during the 2026-10-12 `make check` run. At
18:29:37 the `native tests` gate's `bin/test_runner` spawned
`alr show libbase` (the SBOM test-fixture crate). `libbase` is not in
Alire's local index, so alr refreshed the crate index over git, which
invoked the `git-credential-oauth` helper: it listened on
`127.0.0.1:34063` and opened the GitHub OAuth consent page in the
browser. Every other localhost listener in the run was expected: the
cli-e2e serve tests (adacovex on two free loopback ports) and the
system CUPS port 631. The hermetic-test fix is v1.62.0 item 1.

## v1.62.0

- [x] **1. Hermetic tests: no network or credential flow during `make check`**

  - Implemented, see [changelog](docs/changelogs/adacovex-1.62.0.md) (`C1`).
  - Exit criterion met: `make check` and `just test` run with the
    network unplugged, no `git-credential-oauth` process appears, and no
    browser opens.

- [x] **2. Structural dependency parsing (replace the blind word/regex scan)**

  - Implemented, see [changelog](docs/changelogs/adacovex-1.62.0.md) (`C2`,
    `C3`, `H1`).
  - False positives closed (package subpackages and source trees,
    workspace path names); false negative closed (declared npm and Go
    dependencies with no install tree); `air` is curated now.
  - Accuracy fixtures: the expected component sets are pinned in the
    e2e suite, so a parsing regression fails a gate instead of a manual
    run.

- [x] **3. adacovex as a dependency of other projects**

  - Implemented, see [changelog](docs/changelogs/adacovex-1.62.0.md) (`C4`,
    `C5`).
  - `adacovex` and `covex` are curated table entries, but their
    reference registers the running binary under the canonical name
    `adacovex` (bundled version, `pkg:generic/adacovex`) from the
    reference alone -- no PATH probe decides it, because the tool being
    run is the dependency.
  - Classification rule: the self graph never carries adacovex as a
    component; a manifest declaration keeps its own scope (`base` from
    `alire.toml`, `dev` from `alire-dev.toml`); otherwise
    `Adacovex.Install.Detect` decides -- a source checkout is `dev`, an
    Alire global install or a binary on `PATH` is `system`.
  - `adacovex status` reports the method and the binary path: text row,
    JSON `install_method` / `install_path`, and the same two metric
    keys.
  - Tests in both directions: 15 new SBOM checks (reference, self, and
    manifest-declared fixtures) plus the 23-check `Install method`
    category for the classifier, the scope rule, and the filesystem
    walk.

- [x] **4. HTTP server metrics, objects, and info**

  - Implemented, see [changelog](docs/changelogs/adacovex-1.62.0.md) (`C6`).
  - `GET /health` is the script probe (`{"status": "ok"}`); `GET /api/info`
    serves version, target, standard, port, workers, uptime,
    result-cache counters, assessment time, and per-route 200 / 404
    counters from a protected store shared by the worker tasks.
  - `/api/metrics` stays assessment-shaped. Both routes join the
    `/api/endpoints` catalog, the native suite (routing, counters,
    payload) and the end-to-end serve checks, with rows in
    `docs/usage/dashboard.md` and `docs/usage/dashboard-api.md`.
  - SPARK discipline held: 0 unproved, 0 justified, no new
    `SPARK_Mode (Off)`.

- [x] **5. `adacovex tldr` - client-agnostic install into the local tldr index**

  - Implemented, see [changelog](docs/changelogs/adacovex-1.62.0.md) (`C7`).
  - `docs/tldr/adacovex.md` stays the single source: `tools/gen-tldr.py`
    bundles it into `src/adacovex-tldr_template.ads` (run by `just build`),
    and `just tldr-check` fails when the committed spec drifts from the page.
    `Adacovex.Renderers.Tldr` detects the client, writes the page byte for
    byte, and answers `--check` / `--force`.
  - The injector is client agnostic: tealdeer's custom pages directory comes
    from `tldr --show-paths` (annotation stripped), a base client's cache
    pages tree (the spec directory, or the Node client tree when it exists)
    gets the common and platform page, and an unknown or absent client makes
    the command print the page on stdout. 42 native checks and 7 e2e checks
    pin the detection, the paths, and the round trip; no network and no real
    client is used.
  - Optional follow-up (not done): upstream the page to tldr-pages. The
    shallow clone at `../tldr` is the pages repository.

- [x] **6. Documentation: SARIF, notices, and conciseness**

  - Implemented, see [changelog](docs/changelogs/adacovex-1.62.0.md) (`C10`).
  - `gnatprove.sarif` now has user-facing documentation: the
    `spark-coverage` section of the CLI reference and a section in the
    proving guide, cross-linked both ways, covering what the file is, where
    it lives (`<target>/obj/gnatprove/gnatprove.sarif`), and how to open
    it outside adacovex (editor SARIF viewers, GitHub code scanning).
  - OASIS SARIF joined the CycloneDX and SPDX rows in
    `docs/THIRD_PARTY_NOTICES.md` as a referenced, never-vendored
    specification, and **SARIF** plus `gnatprove.sarif` entered the STE100
    Technical Name dictionary before first use.
  - The conciseness pass landed on the five longest pages with context and
    meaning preserved: `sbom-resolution` -168 words, `dashboard-html` -91,
    `cli-reference` -30, `architecture` -28, and the pre-existing prose of
    `cli-reference-flags` trimmed by roughly what its new SARIF section
    added. The docs gates stay green (docs check, coverage, links,
    paragraph rule, changelog format).

- [x] **7. Python environment and dependency single-sourcing**

  - Implemented, see [changelog](docs/changelogs/adacovex-1.62.0.md) (`C11`,
    `H2`).
  - `pyproject.toml` (`[project].dependencies`) single-sources the docs
    dependencies; the new `tools/update-requirements.py` renders the
    committed `requirements.txt` (header marked generated, dependency lines
    unchanged for `.readthedocs.yaml`), `just requirements` regenerates it,
    `CHECK=1` verifies it, and the new `requirements sync` gate in
    `just check` fails on drift with a unified diff.
  - Bootstrap order implemented and tested in all three branches: `uv` when
    present, else `install.sh --python-venv` (the new install.sh mode that
    creates `.venv` and pip-installs `requirements.txt`), else
    `python3 -m venv` + pip. Absolute `venv-bin` path and the Windows
    `sys.prefix` RuntimeWarning fix untouched; the order is documented in
    the contributor guide and pinned by tests.
  - Blocker found on the way in and fixed (H2): commit `7a5a283` had
    replaced `tools/tests.py` with a 141-line scratch script, so
    `just tools-check` ran zero tests. The 178-test suite is restored and
    now runs 186 tests with the new checks.

## v1.63.0

Delivered; see [the 1.63.0 changelog](docs/changelogs/adacovex-1.63.0.md)
(`C3`, `C4`, `C5`) and `docs/contributing/perf/` for the recorded figures.
The three items are marked done per this file's rule; the phase collation
itself is the last open implementation item below the release bar, and it
is already collated (representative `1.62.0`) with the deferred pieces
streamed into
`docs/contributing/perf/v1.63-backlog.md`.

- [x] **P1. Cold `just build` and cold `prove` down to the bare minimum**

  - Implemented: `tools/build.py` runs its five independent pre-build
    steps concurrently and checks every exit code before the compile;
    `tools/build.py --steps-only` exists for `just bench`; and `just bench`
    gained a per-step build-phase breakdown that reads its step list from
    `tools/build.py` so the bench cannot measure a step the build no longer
    runs. Measured on the release profile: pipeline cold and warm and the
    other per-step figures are in `docs/contributing/perf/benchmarks-timings.md`,
    with the verdict that the toolchain sync fetches nothing on a synced tree,
    the docs phase is a fingerprint hit (76-90 ms, no Sphinx), and the
    compile and solver are gprbuild's and gnatprove's own work.

- [x] **P2. Dir_Cache cache-friendliness**

  - Implemented: packed 66-byte entries (a 64-byte name, a one-byte length,
    a one-byte kind), a 128-byte memo key, a 128-entry cap, and an insert-path
    probe. `Max_Dir_Entries = 128` now clears the self tree's two densest
    scanned directories (78 and 84 entries), which were rejected by the old
    64-entry cap, and the 33-64 character entry name that used to fail the
    whole read with `OK = False` is stored whole. Delivery: `src/core/`
    `adacovex-dir_cache.ads`/`.adb`, `src/tests/adacovex_dir_cache_tests.adb`
    (29 checks), the SVG badge refreshed, and the SVG badge marker style
    gate. Delivery cost: 29`/2017 -> 2024`, SPARK and badges unchanged.

- [x] **P3. Prove-timing phase for v1.61.0 onwards**

  - Implemented: `docs/contributing/perf/prove-timing.md` closes
    `1.57.0-1.60.0` (representative `1.58.0`), opens `1.61.0-` (representative
    `1.62.0`), retires `1.48.0-1.54.0` into the "Across every phase" notes
    after moving its doc-bundling methodology and the warm syscall floor there,
    and records `1.61.0` and `1.63.0` beside the column. The representative is
    the last pre-`1.63.0` version whose cold/warm proof rows were measured at
    the phase's lowest load (load 0.78 for the cold sample, load 2.83 for the
    warm sample), at `1054 VCs` with 0 unproved and 0 justified; its pipeline
    and syscall sets are measured on a fresh `v1.62.0` checkout so they share
    the other version's tree-state convention. The `1.61.0` set is complete and
    sits beside the column, the `1.63.0` memo is a reading note, and the
    deferred pieces are in `docs/contributing/perf/v1.63-backlog.md`.

  - State: the phase is already collated. The remaining work is only to measure
    the three candidate worktrees in one quiet window (one load for all three)
    and, if that window has a quiet cold period, give `1.63.0` its own cold
    sample. The page does not promise those weighings right now; they are the
    deferred item in the backlog.

## Release bar

Each release ships when `just check` reports 29/29 PASS on this
machine, `just prove` is Platinum with 0 unproved and 0 justified, the
native suite is green (and `test_runner` exits non-zero when it is
not), the version is consistent across every source, and the changelog,
user docs, docstrings, and generated artifacts are updated in the same
change.

## v1.63.0 implementation backlog

The only open item under this release is proof-timing finish work that the
current machine state cannot do cleanly: see
`docs/contributing/perf/v1.63-backlog.md`. The open `1.61.0-` phase is
already collated with representative `1.62.0`; the deferred items do not
block `v1.63.0`.
