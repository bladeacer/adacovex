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

  - Implemented (2026-10-12); see
    [adacovex-1.62.0.md](docs/changelogs/adacovex-1.62.0.md) (`C1`).
  - Exit criterion met: `make check` and `just test` run with the
    network unplugged, no `git-credential-oauth` process appears, and no
    browser opens.

- [x] **2. Structural dependency parsing (replace the blind word/regex scan)**

  - Implemented (2026-10-13); see
    [adacovex-1.62.0.md](docs/changelogs/adacovex-1.62.0.md) (`C2`,
    `C3`, `H1`).
  - False positives closed, by name: an installed package's own
    subpackages and source trees reported as components (`lib`, `dist`,
    `src`, `v4-mini`, `v4`, `v3`, `mini`, `locales`), and workspace
    path names reported as components.
  - False negative closed: a project's declared npm and Go
    dependencies never registered when it ships no install tree.
  - `air` is curated now, so a project that references it registers it
    as a system tool when it is installed.
  - Accuracy fixtures: `covex sbom` was checked against the sibling
    projects and the expected component sets are pinned in the e2e
    suite, so a parsing regression fails a gate instead of a manual
    run.

  - `Scan_File` / `Note_Referenced_Tools` word-match a curated tool
    table over build files, and the supported-language manifest readers
    are pattern-driven. Known false-positive shapes on real projects:
    - lccst registers pnpm workspace path names as components (`lib`,
      `dist`, `src`, `v4-mini`, `v4`, `v3`, `mini`, `locales`) although
      its `package.json` declares only `@modelcontextprotocol/sdk`,
      `zod`, `@types/node`, `esbuild`, `tsx`, and `typescript`;
    - the reported `air` component (false positive on a real-project
      run) does not reproduce on the current tree against kibtab, ocd,
      swag, lccst, yams, surge, seiri, quickshell-docs,
      obsi-scss-template, Persona-Quickshell, neetcode-stuff,
      DankMaterialShell, or Ada_CRDT. Capture the exact project and
      command the next time it appears and pin it in the fixture set;
      the same pass should decide whether tools such as `air` are
      curated (kibtab, ocd, and swag all reference it from their
      Makefiles and air configs, yet it is never registered).
  - Parse manifests structurally (TOML/JSON sections, lockfile importer
    blocks), never by substring. Keep the curated word scan for tool
    references only, with whole-word matching on both sides of every
    match.
  - Real-project accuracy fixtures: check `covex sbom` against kibtab,
    ocd, and swag (Go), lccst (pnpm workspace), and the other projects
    in the parent directory, and pin the expected component sets in the
    e2e suite so a parsing regression fails a gate instead of a manual
    run.

- [ ] **3. adacovex as a dependency of other projects**

  - When adacovex audits another project that references `adacovex` or
    `covex` (Makefile, workflow, manifest), it registers as a dev-scope
    dependency of that project; when it audits itself it is the root and
    never a component of its own graph. Add the curated reference, the
    classification rule, and a test in each direction.

- [ ] **4. HTTP server metrics, objects, and info**

  - Current surface (every route the server dispatches on): `/`
    (dashboard), `/api/metrics` (docstring/proof/tests/DAL JSON),
    `/api/deps`, `/api/spark`, `/api/endpoints`, the five
    `/badge/*.svg` routes, and `/docs/*` (the bundled manual). The
    server binds 127.0.0.1 only.
  - Missing and worth exposing: server runtime info - version, target
    path, port, worker count, uptime, request counters per route (200
    and 404), keep-alive connections, result-cache hits and misses,
    selected standards, and the assessment generation time; plus a
    `/health` probe for scripts.
  - Plan: add `/api/info` (server and run metadata, including the
    counters) and keep `/api/metrics` assessment-shaped. Land each new
    route with native server-route tests and a row in
    `docs/usage/dashboard-api.md` (the docs-coverage gate checks both).
    SPARK discipline applies: 0 unproved, 0 justified, no new
    `SPARK_Mode (Off)`.

- [ ] **5. `adacovex tldr` - client-agnostic install into the local tldr index**

  - The page source already exists and is gated: `docs/tldr/adacovex.md`
    (`just tldr-check`, optional `tldr-lint`). It becomes a single
    source embedded in the binary (the same pattern as the man page),
    so the install works offline.
  - The injection must be **client agnostic**: it works for the base
    tldr clients that follow CLIENT-SPECIFICATION.md and for tealdeer.
    The spec defines only the CLI and the zip-cache download; it defines
    no custom-pages location, so each client family gets its own
    injection target, chosen by detecting the installed client (`tldr
    --version`, and `tldr --show-paths` where the client supports it):
    - tealdeer (verified live on this machine, 1.9.0): write the custom
      page to `<XDG_DATA_HOME>/tealdeer/pages/adacovex.page.md` (flat,
      `.page.md` suffix). It renders with `tldr adacovex` and lives
      outside the cache (`~/.cache/tealdeer/`), so `tldr --update` can
      never remove it. The file is installed on this machine as proof.
    - base/reference clients (the C client, the Node client, the Python
      client, and friends): inject into the client's extracted cache
      pages tree (`<cache>/pages/common/adacovex.md`, plus the detected
      platform directory). Cache extraction overlays the zip without
      deleting extra files on every mainstream client, so the entry
      survives `tldr --update` in practice; `adacovex tldr` is
      idempotent and re-injects when a client rebuild wipes it.
    - unknown client, or none: render the bundled page directly (or
      pipe it through `tldr -f`), so the command is never useless.
  - Command shape: `adacovex tldr` (so `covex tldr` works too),
    modelled on `adacovex man`: install or refresh the entry, `--check`
    exits 0 when the installed entry matches the bundled page (1 when
    missing or stale) so a shell-prompt hook can keep it fresh after
    `tldr --update`, and a warning when no supported client is found.
  - Optional follow-up: upstream the page to tldr-pages. The shallow
    clone at `../tldr` is the pages repository; the page already follows
    CLIENT-SPECIFICATION.md, and an upstream merge means `tldr --update`
    carries it with no local install at all.
  - Tests: native tests for the client detection and target-path
    selection per client family (with a fake home/cache tree), and an
    e2e check that installs the page and renders it back through the
    bundled page content; no network, no real client required.

- [ ] **6. Documentation: SARIF, notices, and conciseness**

  - SARIF for users: document `gnatprove.sarif` - what it is, that the
    assessment and `adacovex spark-coverage` read it beside
    `gnatprove.out`, where it lives
    (`<target>/obj/gnatprove/gnatprove.sarif`), and how to view it
    (editor plugins, GitHub code scanning). Home: the spark-coverage
    section of `docs/usage/cli-reference-flags.md` plus a paragraph in
    `docs/contributing/proving.md`, cross-linked.
  - Add SARIF to `docs/THIRD_PARTY_NOTICES.md` beside the CycloneDX
    row: OASIS SARIF, specification reference only, not vendored - the
    same shape as the CycloneDX and SPDX rows.
  - Conciseness pass over the user docs, context and meaning preserved.
    Start with the longest pages: `sbom-resolution` (~1970 words),
    `cli-reference-flags` (~1900), `dashboard-html` (~1650),
    `cli-reference` (~1590), `architecture` (~1530). Every gate stays
    green (docs coverage, links, para-split, STE rules, British
    spelling).

- [ ] **7. Python environment and dependency single-sourcing**

  - Single-source the docs dependencies: add a `pyproject.toml` and
    generate `requirements.txt` from it with a stdlib tool script. The
    committed `requirements.txt` stays, because `.readthedocs.yaml` and
    the docs venv consume it, and a sync gate keeps the two identical
    (same pattern as the description sync).
  - Bootstrap order for the Python tooling environment: `uv` when
    present, else `install.sh` when the project provides one, else
    `python3 -m venv`. Document it in the developer guide and keep the
    justfile behaviour consistent with it (absolute venv-bin paths, the
    Windows `sys.prefix` RuntimeWarning fix).

## v1.63.0

- [ ] **P1. Cold `just build` and cold `prove` down to the bare minimum**

  - Current cold costs on this machine (v1.61.0): a cold build pays the
    alire workspace sync that fetches three binary crates
    (`gnatdoc_bin`, `gnatformat_bin`, `gnatprove` 16.1.0), the full
    Sphinx bundle build when the docs changed, and a full gprbuild of
    about 300 units plus the `test_runner` link. A cold `prove` is
    60-72 s at 1022 VCs, solver-bound, after toolchain resolution.
  - Profile each cold phase first (extend `just bench` with build-phase
    scenarios; hyperfine plus strace), then cut what is not needed:
    the toolchain fetch (cache or document the host-side cache), the
    doc regeneration (the fingerprint is already incremental - prove a
    cold tree cannot rebuild it needlessly), the compile (flags and
    unit count), and the solver (VC reduction, job count).
  - Bar: every remaining cold-phase cost is either measured-necessary
    or removed, and the numbers are recorded in
    `docs/contributing/perf/`.

- [ ] **P2. Dir_Cache cache-friendliness (from the v1.61.0 perf analysis)**

  - The warm pipeline spends about 14k `newfstatat` calls and shows a
    13 percent L1 dcache-miss rate, largely from the `Dir_Cache` slot
    layout (1024-byte path image per slot, 128-byte entry records).
    Shrink the per-slot footprint, tighten `Dir_Entry_Rec`, and
    reconsider `Max_Dir_Entries = 64`: directories over the cap now take
    the correct but unmemoised fallback on every walker, so the self
    tree re-enumerates `src/parsers` repeatedly.
  - SPARK bar unchanged: 0 unproved, 0 justified, no new
    `SPARK_Mode (Off)`.

- [ ] **P3. Prove-timing phase for v1.61.0 onwards**

  - 1.61.0 begins its own phase, because the v1.62+ and v1.63 perf work
    changes the implementation methodology. When the perf fixes land:
    close the current open phase at 1.60.0 (keeping 1.58.0 as its
    representative), open `1.61.0-` seeded with the v1.61.0 complete
    metric set from `perf-analysis.md` (pipeline warm 41.7 ms and cold
    about 72 ms; prove warm about 53 ms and cold 60-72 s; 14,106 warm
    `newfstatat`; 5.9 MiB stripped), retire the 1.48.0-1.54.0 phase
    after moving any figure-explaining note into "Across every phase",
    and update the AGENTS.md phase-list sentence and every page that
    names the range.
  - Every figure is measured on this machine with `/proc/loadavg`
    recorded beside it, per the established rule.

## Release bar

Each release ships when `just check` reports 28/28 PASS on this
machine, `just prove` is Platinum with 0 unproved and 0 justified, the
native suite is green (and `test_runner` exits non-zero when it is
not), the version is consistent across every source, and the changelog,
user docs, docstrings, and generated artifacts are updated in the same
change.
