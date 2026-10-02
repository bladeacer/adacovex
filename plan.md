# adacovex 1.55.0 implementation plan

Status: **plan only**. No code in this change.

Target version: **1.55.0** (minor bump from 1.54.0, released 2026-09-28).
Never a major increment: no CLI flag removal, no output-format break, no
cache-schema break that a consumer must act on. Every item below is additive
or internal.

## Scope

Seven work items, in the order they should land:

| # | Item | Kind | Primary area |
|---|------|------|--------------|
| 1a | Stale tool fingerprints never refreshed (permanent re-probe) | **Bug fix** | `src/parsers` |
| 1b | Redundant build-file reads on the assessment path | Perf | `src/parsers`, `src/core` |
| 2 | Golang SBOM resolution (git-server-agnostic) | Feature | `src/parsers` |
| 3 | gnatprove v16 verification gate | Fix + gate | `tools/`, CI |
| 4 | base85 decoder unit tests | Tests | `src/tests`, `tools/gen-docs.py` |
| 5 | Remove the duplicated Sphinx build in `make check` | Perf | `tools/`, `Makefile` |
| 6 | Split documentation pages over the 250-line cap; enforce the cap | Docs | `docs/`, `tools/` |
| 7 | Additional unit tests across under-covered categories | Tests | `src/tests` |

Item 1 was one item when this plan was drafted. Measurement split it: 1a is
a **correctness and latency bug** worth 976 ms to 57 ms on an unchanged
tree, found while baselining, and it must land before 1b.

## Design principles (binding on every item)

- **Zero library dependency.** Only the GNAT runtime. No new Ada package
  outside `Ada.*`, no vendored C, no Python at run time.
- **Git-server-agnostic.** No design decision may hard-code `github.com`.
  A GitLab, Gitea, Codeberg, or self-hosted forge must work through the same
  code path. Anything forge-shaped is derived at run time from data the
  target already carries, or not resolved at all.
- **Table-driven, not branch-driven.** A new ecosystem is a table row, as
  `Resolve_Ecosystem_Metadata` and `Read_Vendor_Manifest` already are. Do
  not add an `if ecosystem = ...` chain.
- **Best-effort resolution, never a guess.** A missing registry, an offline
  machine, or a missing tool leaves the field empty. adacovex never invents
  a licence, a version, or a website.
- **SPARK-safe.** New code is `SPARK_Mode On` and fully proved unless it
  touches a non-formal container. No new `pragma SPARK_Mode (Off)`: the
  only two exempt packages stay `Types.Implementation` and `Complexity`
  (`make spark-off-check` enforces this).
- **Bounded buffers.** Path and line buffers fail loudly (skip the file,
  `Skipped_Ct` increments, DAL becomes `Unmet`). Semantic fields clamp and
  record the recorded length. No truncation-then-continue.
- **Cache-correct.** Any change to a cache key or to what a cache covers is
  a `Cache_Schema` bump, and the schema constant is the single place the
  version lives.

## Proof and SPARK impact budget

Baseline to preserve, per `docs/proof/16.1.0-ledger.md` and AGENTS.md:

- Platinum, **878 VCs, 0 unproved, 0 justified**, 66 analysed units, under
  **gnatprove 16.1.0** at `--level=4`.
- 0 `pragma Assume` / `pragma Annotate` justifications.
- `SPARK_Mode (Off)` in exactly two packages.

Per item:

| # | Proof impact | Notes |
|---|--------------|-------|
| 1 | **0 new VCs expected** | Restricting which files are hashed is inside `Adacovex.Parsers.Manifest` and `Adacovex.Prove`, both `SPARK_Mode On`. If the change removes a branch, the count may drop; update the ledger and AGENTS.md in the same change. |
| 2 | **New VCs expected (+N)** | New parsing and table rows in `Adacovex.Parsers.Manifest`. All must prove. If the network path forces an unbounded buffer or a non-formal construct, it does not belong here; keep the parse bounded. |
| 3 | 0 | `tools/` only. No Ada change unless the gate needs a new CLI surface (it does not). |
| 4 | 0 | Test bodies are not analysed by `make prove` (`tests/` is in the prove skip set and `-u` excludes the units). |
| 5 | 0 | `tools/` and `Makefile` only. If a gate is re-ordered so a build step runs earlier, no Ada change. |
| 6 | 0 | Docs only. Regenerated `docs/api-docs` are excluded from the line cap. |
| 7 | 0 | Test bodies only. |

After every item: `make prove` must still report 878 (or the newly stated
number) proved, 0 unproved, 0 justified, and `make proof-status` must be
re-run so `AGENTS.md`, `docs/proof/index.md`, and the ledger agree.

## Documentation sync required by every item

Per AGENTS.md, a change that touches behaviour, flags, tools, or output must
update, in the same change:

- the relevant user doc under `docs/`;
- the Ada docstrings that feed `docs/api-docs` (then `make doc`);
- `docs/changelogs/adacovex-1.55.0.md` plus the list in
  `docs/changelogs/index.md`;
- `docs/contributing/perf/prove-timing.md` when a version joins or opens a
  phase (item 5);
- `docs/contributing/ste100/index.md` when a new Technical Name enters the
  docs (item 2 introduces "module proxy", "vanity import path", and
  possibly "forge");
- `AGENTS.md` when the source tree, flags, SBOM behaviour, or dashboard
  features drift.

Then the sync gates, in this order: `make docs-check`,
`make action-parity-check`, `make docs-coverage-check`, `make agents-tree`
(when `src/` changed), `make doc-links`, `make link-check`,
`make book-links-check`, `python3 tools/gen-docs.py --check` (and `make book`
first, because `docs/` changed).

## Test-registration checklist (four places)

Any new test, or any change to a category count, registers in **all four**,
or the count-sync gates fail:

1. `src/tests/test_runner.adb` - the `with` clause, the runner object
   declaration, the `Row (...)` in **both** totals tables, the
   `Adacovex_Xxx_Tests.Run (R_Xxx)` call, and the `Total_Passed` /
   `Total_Failed` summations.
2. `tools/update-test-count.py` - the `CATEGORY_KEY` entry mapping the
   `docs/test_result.md` category name to the `tools/agents-tree.map` key.
3. `tools/agents-tree.map` - the source-file entry with its one-line
   description. `tools/gen-agents-tree.py` **rejects a source file with no
   entry**.
4. `CONTRIBUTING.md` - the "Unit tests" category table row, and the totals
   in the prose above it (`1657 tests across 25 categories`).

A **new** category also needs `docs/test_result.md` written by `make test`
and the AGENTS.md architecture tree updated by `make agents-tree`. Items 4
and 7 both add to **existing** categories (Server routing, SBOM generator,
Prove runner, Cache, Complexity check), so no new category is expected.

Run `make test-count` and `make proof-status` after `make test` / `make prove`.
---

## Item 1: Stop the redundant YAML reads on the prove and assessment path

### What the tree actually does today

Verified findings, because the item as raised is partly a misdiagnosis and
the plan must correct it rather than act on the premise:

- **The prove input hash never reads YAML.**
  `Compute_Prove_Input_Hash` in `src/core/adacovex-prove.adb` walks the tree
  but hashes only files whose extension is `ads` or `adb`
  (`adacovex-prove.adb`, the `E2 = "ads" or else E2 = "adb"` test inside
  `Walk`). `.readthedocs.yaml` at the dogfood target root, or in
  `../Ada_CRDT`, is therefore **not** an input to `Prove_Cache_Key`. There is
  no redundant YAML parse on the proof path to remove.

- **There are no YAML references in Ada source.** `grep` over
  `src/**.ads` and `src/**.adb` finds `yaml` only in comments, in
  `Scanned_Ext` (`src/core/adacovex-complexity.adb`, the `yaml` / `yml`
  rows), and in the `Should_Scan` extension test and
  `Is_Owner_Manifest` name list in `src/parsers/adacovex-parsers-manifest.adb`.
  adacovex does not parse YAML anywhere. YAML files are *word-scanned* and
  *hashed*, never parsed.

- **The real redundancy is a double read of every scan-eligible build file.**
  `Discover_System_Dev_Deps` computes `K := Tools_Key (Target_Dir)` before it
  scans. `Tools_Key` calls `Source_Tree_Hash`, which does its own full
  directory walk and calls `Adacovex.Cache.Hash_File` on every
  `Should_Scan` file (`.sh`, `.gpr`, `.yml`, `.yaml`, `.toml`). When the
  tools-set cache then misses, the *second* walk runs and `Scan_File` opens
  and reads every one of those files again line by line
  (`adacovex-parsers-manifest.adb`, `Tools_Key` at ~line 1121,
  `Source_Tree_Hash` at ~line 1171, the miss-path walk at ~line 1367, and
  `Scan_File` at line 1065). So on a tools-cache miss each eligible file is
  opened twice and hashed once; on a hit it is opened once and hashed once.

  The stat-stamp index inside `Hash_File` (`src/core/adacovex-cache.adb`)
  makes the second *hash* cheap on warm runs, but `Scan_File` has no stamp
  short-circuit: it always reads.

- **A third walk hashes the npm lockfile again.** `Is_Owner_Manifest`
  (`adacovex-parsers-manifest.adb`, ~line 1791) lists `pnpm-lock.yaml`,
  `package-lock.json`, and `yarn.lock`, and the graph-key walk hashes them
  independently of the tools-key walk.

- **The complexity scan reads YAML a fourth time**, but only when the
  `complexity` subcommand runs, so it does not affect `make prove` or a
  plain assessment.

So: no YAML *parse* is redundant, but every eligible build file (the 11 YAML
files in this tree, including `.readthedocs.yaml`, `action.yml`,
`.github/workflows/*.yml`, `.github/ISSUE_TEMPLATE/config.yml`,
`.github/FUNDING.yml`, and `tests/e2e/pnpm-lock.yaml`) is read twice per
uncached tools-set run.

### Scope

**This item is now two independent changes. Land 1a first, on its own.**

#### 1a. Persist the refreshed fingerprints on a re-probe (bug fix, do first)

The measured root cause (see the baselines section): the store block is
guarded by `if not From_Cache`, but the re-validation branch runs only
`if From_Cache`. A hit that re-probes therefore never writes the corrected
fingerprints back, so the stale blob survives and re-probes on **every**
subsequent run. Measured cost: **976 ms against 57 ms** for the identical
command, and it never self-heals.

The fix: track whether any re-validation changed a fingerprint, and persist
the set when it did, regardless of `From_Cache`. Concretely, set a local
`Refreshed : Boolean := False` in the re-probe branch and widen the store
guard to `if (not From_Cache or else Refreshed) and then Key_Len > 0`.

Two properties must be preserved:

- an **unchanged** toolchain still stores nothing on a hit, so a warm run
  stays at 1 `execve` and no spawns;
- a **changed** toolchain re-probes once, stores, and is fast from the next
  run onward.

Add a test that pins both: a cache hit with a matching fingerprint does not
re-store; a cache hit with a stale fingerprint re-probes **and** leaves a
blob whose fingerprints match the live binaries, so a third run spawns
nothing. That test is the regression pin for this bug.

This is also the fix for a **latent correctness issue**: today the stored
version string for a replaced binary can persist indefinitely while the
probe re-runs every time, so the graph holds a version that is re-derived
but never refreshed in the cache.

#### 1b. Make the tools-set key and the scan share one walk and one read

1. **Exclude `index/` from the tools-key walk.** Measured: the walk descends
   into `index/ad/covex/` and hashes **16** vendored Alire index `.toml`
   files, contributing 16 of the 171 extra opens on a cold run. The prove
   `Skip` list already excludes `index` for exactly this reason. Add it to
   the tools-key exclusion list and record why.
2. **Single-pass tools scan.** Replace the `Tools_Key`-then-scan sequence
   with one walk that, per file, computes the SHA-256 and runs
   `Note_Referenced_Tools` from the same buffer. The key is then the digest
   of exactly the bytes the scan consumed, which is what the existing
   docstring already claims ("walks the same directories and files that
   `Discover_System_Dev_Deps` scans").
3. **Stamp short-circuit for `Scan_File`.** When the per-file stamp from the
   key pass says the file is unchanged since the stored digest *and* the
   scan is only collecting whole-word tool names, serve the prior scan
   result instead of re-reading. This needs a per-file record of "which tool
   names this file contributed", so weigh it against the single-pass change:
   item 1b step 2 alone removes the double read without a new cache record,
   and is the recommended landing. Treat the stamp short-circuit as a
   follow-up only if measurements still show `openat` dominating.
4. **Share the Dir_Cache snapshot between the key walk and the scan walk.**
   `Source_Tree_Hash` currently uses its own `Start_Search` loop, while the
   scan walk uses `Adacovex.Dir_Cache.Snapshot`. Routing the key walk through
   the memo removes one enumeration per directory.
5. **Keep the lockfile in both keys.** `pnpm-lock.yaml` is deliberately in
   the graph key (an edit changes scope classification) and is also a
   `Should_Scan` file for the tools key. Do **not** remove it from either;
   deduplicating it is not worth the correctness risk.

### Target files

- `src/parsers/adacovex-parsers-manifest.adb` - `Tools_Key`,
  `Source_Tree_Hash`, `Discover_System_Dev_Deps`, `Scan_File`.
- `src/core/adacovex-dir_cache.ads/.adb` - only if the key walk needs a new
  entry point.
- `src/core/adacovex-cache.ads` - only for a `Cache_Schema` decision; see
  the note below.
- `src/tests/adacovex_sbom_tests.adb` - the tool-set cache tests.
- `docs/contributing/architecture.md` (result-caching section),
  `docs/contributing/architecture-outputs.md`,
  `docs/contributing/perf/prove-timing.md`, `docs/usage/sbom-resolution.md`.

### Cache-schema note

Bumping `Cache_Schema` (`src/core/adacovex-cache.ads`, currently `s11`)
invalidates every cached scan, proof, graph, and tool set for every user.
Decide explicitly and record the decision in the changelog: if the new key
derives from the same file set as the old one, the digest changes anyway
(the key becomes a hash of a different byte order), so a stale blob can
never be served and **no bump is needed**. Prefer no bump. Bump only if the
serialized layout changes.

### Pre-implementation research steps

1. Measure before changing anything: `make perf-bench` and
   `strace -c -f ./bin/covex --target=../Ada_CRDT --no-sbom` to get the
   `openat` / `read` / `newfstatat` counts, plus a run with
   `strace -e trace=openat -f` filtered to `.yaml` / `.yml` to confirm the
   double read in the wild.
2. Confirm the key equivalence: dump the file list `Source_Tree_Hash` hashes
   and the list `Discover_System_Dev_Deps` scans, and prove they are the
   same set (same `Should_Scan`, same exclusion list, same depth). They are
   written separately today, so drift is possible; the merge must reconcile
   them first.
3. Check the exclusion lists agree: `Source_Tree_Hash` skips
   `.git .jj .hg .svn obj tests config .adacovex alire gnatprove __pycache__
   node_modules .venv .headroom .lccst _build`; the prove `Skip` list adds
   `.fslckout _FOSSIL_ bin dist index resources docs`; the complexity
   `Skip_Dir` list adds `_darcs .alire build book test-results
   playwright-report media skills`. Decide which list is canonical for the
   tools scan and record the decision in a comment.
4. Verify the complexity subcommand is never on the `make prove` path
   (`grep` for `Complexity` in `adacovex_main.adb`), so its YAML read is out
   of scope.

### Proof / SPARK

`Adacovex.Parsers.Manifest` is `SPARK_Mode On`. Merging two walks removes
branches; the merged walk introduces at most the loop-invariance conditions
that already prove today. Expect the VC count to **drop** or hold. If it
drops, update `docs/proof/16.1.0-ledger.md`, `docs/proof/index.md`, and the
three AGENTS.md figures in the same change, and run `make proof-status`.

### Tests

Extend the SBOM generator category: the tools-set cache still serves a hit
on an unchanged tree, still misses after an edit to a `.yml` file, and the
single-pass key equals the two-pass key for the same tree (a regression
fixture comparing a stored digest). Add a case pinning that a
`.readthedocs.yaml`-shaped file at the target root neither breaks the walk
nor changes the tool set.

---

## Item 2: Golang SBOM resolution, git-server-agnostic

### What the tree does today

- `Read_Vendor_Manifest`
  (`src/parsers/adacovex-parsers-manifest-read_vendor_manifest.adb`) has
  row 3 for `go.mod`: `Kind => "golang"`, `Lang => "Go"`, `Reader => R_Go`.
- The `R_Go` branch (line ~153) sets **only** `Info.Name`, from
  `Go_Module_Path`
  (`src/parsers/adacovex-parsers-manifest-go_module_path.adb`, which reads
  the first `module <path>` line). It never sets `Info.Version` or
  `Info.License`. So a vendored Go component has a name, a language, and a
  PURL, but no version and no licence.
- `Resolve_Ecosystem_Metadata`
  (`src/parsers/adacovex-parsers-manifest-resolve_ecosystem_metadata.adb`)
  has row 6
  with `Kind => "go"`, `KLen => 2`, and **`Tool => (others => ' ')`**,
  `TLen => 0`. `Resolve_One` returns immediately on `TLen = 0`, so the row
  is a documented no-op: the package's own docstring says "Ecosystems with
  no reliable registry CLI (for example go) carry an empty tool so the
  resolver returns quietly".
- `docs/usage/sbom-resolution.md` states this as intended behaviour: "**go**
  and other ecosystems with no portable, reliable registry query keep an
  empty licence".
- The result cache for these answers already exists:
  `Adacovex.Cache.Get_Meta` / `Put_Meta`, keyed by target directory plus
  ecosystem plus package name, 7-day TTL, shared with the system-tool probe
  cache. The resolver returns from it before spawning anything.

### The naming defect to fix first

`Read_Vendor_Manifest` sets the PURL kind to `"golang"` (6 chars) but the
resolver table row is keyed `"go"` (2 chars). The resolver's non-JavaScript
dispatch matches on
`Table (I).KLen = Ecosystem'Length and then Table (I).Kind (...) = Ecosystem`,
so `"golang"` never matches row 6. **The Go resolver row is dead code
today.** Fixing the key is a prerequisite for any resolution work and is
independently testable.

### Design: no forge is hard-coded

The requirement is GitLab / Gitea / Codeberg / GitHub parity with one code
path. The only Go mechanism that satisfies this is the **module proxy
protocol**, because `go` itself resolves it and adacovex never constructs
a host name:

- `GOPROXY` may be any module proxy (the public one, a private Athens /
  Artifactory instance, a corporate mirror). adacovex does not name it.
- `GOPRIVATE` / `GONOSUMDB` / `GONOSUMCHECK` / `GOPROXY=direct` are honoured
  by `go`, so a private forge resolves through the local VCS credential and
  the module cache.
- The Go toolchain, not adacovex, decides which forge answers. adacovex only
  spawns `go` and reads what `go` prints.

**Explicitly rejected:** `curl https://api.github.com/repos/<owner>/<repo>`,
and any URL template containing a forge host. That hard-codes GitHub,
requires HTTP (and a TLS stack) inside a tool whose whole design is "spawn
the ecosystem's own CLI", and breaks on every non-GitHub forge. The same
applies to a `github.com/<owner>/<repo>` PURL guess.

### Scope

1. **Fix the ecosystem key.** Align `Read_Vendor_Manifest`'s `go.mod` row
   and the resolver table row on one token (`"go"`), keeping `pkg:golang` as
   the PURL type in the renderer. This is a pure dispatch fix.
2. **Read version and licence offline from `go.mod`.** Extend
   `Go_Module_Path` into a `Go_Module_Info` that also returns the resolved
   version from a `require` / `require (` block (the version token is
   `v1.2.3`, optionally followed by `// indirect`), and reads a
   `LICENSE` / `COPYING` / `LICENCE` file next to the manifest for the
   licence text. This gives a correct, fully offline answer for a vendored
   tree, matching how `Gemfile` and `pom.xml` readers already work
   (`Gem_Entry`, `Xml_Tag_Value`). It is also the git-server-agnostic
   answer: the licence ships in the repository, so it does not matter which
   forge the repository lives on.
3. **Resolve through `go` when the manifest is silent.** Fill the `go` row
   of `Resolve_Ecosystem_Metadata` with `Tool => "go"`, one spawn per
   component, reading version from `go list -m -json <mod>@latest` (or the
   `@v/list` + `@latest` proxy endpoints through the same `go`). Fields:
   - version from the `Version` field;
   - licence from a `LICENSE` file in the module cache directory `go list
     -m -json` reports (`Dir`), falling back to the offline read. **Measured:
     `Dir` is absent until the module is downloaded**, so a missing `Dir`
     must fall through cleanly and must never trigger an implicit
     `go mod download` per component;
   - website: leave empty, by decision (see Q1 in the resolved-decisions
     section). `go list -m -json` has no website field, and its `Origin.URL`
     is a forge-specific *VCS endpoint* (`go.googlesource.com` for
     `golang.org/x/text`, a forge host for everything else), so surfacing it
     would be both wrong and forge-dependent.
4. **Vanity import paths.** A module path whose first element is not a
   known forge host (for example `golang.org/x/...`, `gopkg.in/...`,
   `k8s.io/...`, `example.com/...`) must not be turned into a URL. The
   offline licence read covers these; the `go` path resolves the rest.
5. **PURL.** Keep `pkg:golang/<escaped module path>@<version>`. The existing
   dashboard regex (`pkg:golang\/([^@]+)`) already handles it, so no
   dashboard change is needed.

### Target files

- `src/parsers/adacovex-parsers-manifest-resolve_ecosystem_metadata.adb` -
  the `go` row.
- `src/parsers/adacovex-parsers-manifest-go_module_path.adb` - extend, or
  add a sibling `...-go_module_info.adb` if the function grows past the
  complexity gate.
- `src/parsers/adacovex-parsers-manifest-read_vendor_manifest.adb` - the
  `R_Go` branch and the `go.mod` row.
- `src/parsers/adacovex-parsers-manifest-discover_generic_vendored.adb` -
  no change expected; it already prefers the local manifest over the
  registry answer.
- `src/tests/adacovex_sbom_tests.adb`.
- `docs/usage/sbom-resolution.md` (rewrite the "go" bullet), `docs/usage/sbom.md`
  (the manifest-ecosystem table already lists `go.mod` / `pkg:golang`),
  `docs/CREDITS.md` and `docs/THIRD_PARTY_NOTICES.md` only if a new
  third-party component is added (none is: `go` is a Go toolchain component,
  already covered by the GNAT/toolchain rows only if it is genuinely used -
  decide and record).
- `docs/contributing/ste100/index.md` - new Technical Names if the docs
  introduce "module proxy", "vanity import path", or "forge".

### Pre-implementation research steps

1. Confirm the dead row empirically: build a fixture project with a
   `vendor/<mod>/go.mod` and assert the resolved version and licence are
   empty today, then that the key fix alone changes the dispatch.
2. Prototype `go list -m -json <mod>@latest` by hand against three module
   paths: a GitHub one, a GitLab one, and a vanity one
   (`golang.org/x/text`). Record exactly which fields each returns, and
   whether `Dir` is populated for a module already in the cache versus one
   that needs a download. The answer decides whether step 3 needs a
   `go mod download` at all.
3. Check `GOPROXY` / `GOPRIVATE` handling in the same prototype: confirm
   `GOPROXY=off` produces a clean failure that leaves the fields empty
   rather than a partial answer.
4. Decide the time budget. `go list` boots the Go tool and can take a second
   on a cold cache. The 7-day meta cache already absorbs repeats, so the cost
   is paid once per component per week. If that is judged too slow for a
   large Go tree, add a per-run memo so a module path is resolved once per
   process even when several components share it.
5. Check whether `go.sum` should be added to `Is_Owner_Manifest`. It pins
   the resolved versions, so an edit to it changes the correct answer, and
   the same argument that put the npm lockfiles in the graph key applies.
   Add it if the resolution depends on it.

### Proof / SPARK

New parsing in `Adacovex.Parsers.Manifest` adds VCs. All must prove at
`--level=4`. The `go list -m -json` output is JSON; the existing
`Json_Value` helper in the resolver is a bounded substring scan and already
proves, so reuse it rather than writing a parser. If the `Dir` + licence
read needs path arithmetic that will not prove cleanly, keep the offline
`go.mod` / `LICENSE` read as the primary path and treat the `go` spawn as a
best-effort enrichment, so the proved surface stays small.

### Tests

SBOM generator category: the ecosystem-key fix; a `require` block with and
without `// indirect`; a missing `LICENSE`; a `gopkg.in` path; a version
resolved from `go list` when `go` is on `PATH` and skipped when it is not;
and a fixture asserting no forge host appears in the SBOM JSON for a
GitLab-sourced module.

---

## Item 3: Verify gnatprove 16.1.0 across the codebase and CI, and gate it

### Audit result (done at planning time)

The tree is already consistently on 16.1.0. Every occurrence of an older
pin is either historical or an example, and none of them is a live pin:

| Location | Value | Verdict |
|----------|-------|---------|
| `.github/workflows/ci.yml` (3 jobs), `pr-check.yml`, `release.yml` | `gnat-version: 16.1.0` | live, correct |
| `action.yml` | `gnat-version` input, default `16.1.0` | live, correct |
| `alire/alire-dev.toml` | `gnatprove = "^16.1.0"` | live, correct (dev manifest only) |
| `alire.toml` | no `gnatprove` pin | correct: it must stay undeclared so the released crate declares no tool dependency |
| `src/core/adacovex-prove.adb` | no hard-coded version; resolved from the target manifest, then a global pin, `PATH`, the toolchain cache, then a download | correct |
| `docs/proof/16.1.0-ledger.md` | the evidence record | correct |
| `docs/api-docs/adacovex-prove.md`, `src/core/adacovex-prove.ads:19`, `adacovex-prove.adb:913` | `^15.1.0`, `~15.1.0` as **examples** of a version-set expression in a docstring | cosmetic only; consider refreshing the example to `^16.1.0` so a reader is not left thinking 15 is current |
| `src/tests/adacovex_prove_tests.adb:388` | comment: "gnatprove 15.1.0 and 16.1.0 produce (verified against both)" | correct, historical note |
| `docs/changelogs/adacovex-1.6.0.md`, `-1.8.0.md`, `index/ad/covex/covex-1.5.0.toml`, `alire/releases/covex-1.5.0.toml` | 15.1.0 | archived history, must not be rewritten |

So the audit finds **no defect**. The remaining work is to make the
consistency mechanical so it cannot drift, which is what actually protects
the requirement.

### Scope

1. **Extend `tools/check-version-consistency.py` (or add a sibling gate)
   with a gnatprove dimension.** The gate already compares the version across
   the two manifests, the generated spec, the built binary, and
   `sbom.json`. Add the gnatprove pin as one more source: assert that every
   live `gnatprove` constraint in `alire-dev.toml`, every `gnat-version:`
   default in `.github/workflows/*.yml` and `action.yml`, and the version
   recorded in `docs/proof/index.md` and the ledger filename agree with the
   pinned version. A mismatch fails `make check` and the
   `version-consistency` CI job.
2. **Keep the gate blind to history.** The checker must whitelist
   `docs/changelogs/`, `docs/archive/`, and `index/` / `alire/releases/`.
   A 15.1.0 reference in a 1.6.0 changelog is correct history and a gate that
   flags it would be deleted on sight.
3. **Refresh the docstring examples** in `src/core/adacovex-prove.ads` (and
   the generated `docs/api-docs/adacovex-prove.md`) from `^15.1.0` to a
   16.x example, so the API page does not read as if 15 is current. Keep the
   `Bare_Version` test comment as-is (it documents that both forms were
   verified).
4. **Record the resolution order in the docs.** `Resolve_GNATprove`'s five
   priorities (target manifest, global pin, `PATH`, toolchain cache,
   download) are documented in `docs/usage/installation.md` and
   `docs/usage/configuration.md`; confirm the wording still matches the code
   after item 1's neighbour edits, and state that the pin is a **minimum**,
   not an exact match, because the manifest constraint is a caret range.

### Target files

- `tools/check-version-consistency.py` - the new gnatprove comparison.
- `tools/tests.py` - cases for each branch (consistent, drifted workflow,
  drifted manifest, history correctly ignored).
- `Makefile` - only if a separate target name is preferred over folding it
  into `version-consistency-check` (recommendation: fold it in, so the gate
  list does not grow).
- `src/core/adacovex-prove.ads` - the docstring example.
- `docs/usage/installation.md`, `docs/usage/configuration.md`,
  `docs/proof/index.md`.

### Pre-implementation research steps

1. Read `src/core/adacovex-prove.adb` `Resolve_GNATprove` end to end and
   write down the five priorities as the code has them, then diff that list
   against `docs/usage/installation.md` and
   `docs/usage/configuration.md`. Any divergence is the real finding of this
   item.
2. Read `File_GNATprove_Version` and `Bare_Version` and confirm the
   constraint `^16.1.0` reduces to `16.1.0`, and that `>=16.0.0` reduces to
   something `alr -n get` accepts. The existing tests cover this; confirm
   they still pass before adding the gate.
3. Enumerate every `gnat-version` and `gnatprove` occurrence in the repo
   with `grep -rn` including hidden directories, and classify each as live,
   historical, or example, so the gate's whitelist is complete on the first
   run.

### Proof / SPARK

None. `tools/` and docstrings only; docstrings are excluded from the proof
input hash only for the two generated bundle specs, so a docstring change in
`adacovex-prove.ads` **will** invalidate the cached proof and cost one
gnatprove session. Batch it with other prove-affecting edits in the same
change rather than landing it alone.

### Tests

`tools/tests.py` (the `TestVersionConsistency` class) gains cases per
branch. No native test change.

---

## Item 4: base85 decoder unit tests

### What exists today

`src/adacovex-docs_template.adb` carries a hand-written `Base85_Decode`
(Z85 alphabet: digits, lower case, upper case, then the punctuation run
`.-:+=^!/*?&<>()[]{}@%$#`; four bytes to five characters, big-endian; a short
final group of 1..3 bytes is padded with the highest alphabet value and
yields `Gone - 1` payload bytes). The generated spec
`src/adacovex-docs_template.ads` exposes `Body_Bytes`, `Content`, and
`Find`, but **not** `Base85_Decode`, which lives in the body.

`src/tests/adacovex_server_tests.adb` (48 tests) already pins the decoder
against real data: it walks all 246 bundled assets and asserts
`Asset_Count > 100`, zero decode failures, every body carries the gzip magic
`0x1F 0x8B`, and every decoded length matches the base85 packing
(`(L / 5) * 4`, plus `(L mod 5) - 1` for a short final group). That is a
strong end-to-end pin, and it is **data-dependent**: it proves the decoder
against whatever `make book` last produced, not against a hand-computed
vector.

### Gaps

1. **No synthetic vectors.** A bug that happens to round-trip through the
   real assets (for example a short final group, which only the smallest
   assets exercise) would not be caught by a round-trip test.
2. **No negative or degenerate cases.** `Val` maps any unexpected character
   to 0. Nothing pins that behaviour, and nothing pins the empty string, a
   single character, or a two-, three-, or four-character final group.
3. **No test for the non-gzip path.** `Body_Bytes (B, False)` returns the raw
   body verbatim; `Assets (I).Gzip` is `True` for every current asset, so
   that branch is unexercised.
4. **`Find` normalisation is only partly covered** (`index.html`,
   `_nav/0.html`, `_static/adacovex-nav.js` are checked for presence; the
   extensionless-leaf and directory-index fallbacks are not).

### Scope

Expose the decoder for testing without breaking the zero-dependency and
generated-spec constraints:

1. **Add a `Base85_Encode` oracle in the test file**, not in the shipped
   body. The test re-implements the encoder in the test package and asserts
   `Base85_Decode (Encode (B)) = B` for every length 0..64 and for a set of
   byte patterns (all zeros, all `0xFF`, every single byte value, a
   randomised-but-seeded pattern). This needs no production change and gives
   a real oracle.
2. **Hand-computed golden vectors.** Encode three known byte strings by hand
   (for example `"Man "`, `"Hello, World!"`, a 3-byte string) with an
   independent implementation, pin the expected base85 text in the test, and
   assert the decoder produces the exact bytes. This is the check that would
   catch an alphabet-order change, which a round-trip cannot.
3. **Degenerate inputs.** `""`, one character, two, three, four, five, six.
   Assert the decoded lengths are 0, 0, 1, 2, 3, 4, 4 and that no exception
   is raised.
4. **The `Val` fallback.** Assert that a character outside the Z85 alphabet
   decodes to zero rather than raising, so the documented lenient behaviour
   is pinned and a future "strict" change is a deliberate break.
5. **`Body_Bytes (B, False)`.** Assert the verbatim path returns the stored
   body unchanged. Needs a non-gzip body in the table, or a test that calls
   `Body_Bytes` with `Is_Gzip => False` on an existing body (the raw body is
   the base85 text, so the assertion is that it equals
   `Asset_Bodies (...)`).
6. **`Find` fallbacks.** `/usage/cli-reference` ->
   `usage/cli-reference.html`, `/usage/` -> `usage/index.html`,
   `/_nav/0` -> `_nav/0.html`, and a path that must return 0.

**Visibility decided (see Q4): promote `Base85_Decode` into the generated
spec.** It is absent from `src/adacovex-docs_template.ads` today, so a test
cannot feed it a chosen byte string and can only observe it through whatever
`make book` last generated, which is the weakness item 4 exists to remove.
Add the declaration in `tools/gen-docs.py` next to `Body_Bytes` (the same
emission block, around line 1167) with a docstring, then `make book`
regenerates the spec and `python3 tools/gen-docs.py --check` must pass. A
private test hook is rejected: it would be a declaration no generator
covers.

### Target files

- `src/tests/adacovex_server_tests.adb` - the new cases.
- `src/adacovex-docs_template.adb` - only if a test hook is needed (it is
  hand-written and stable; the generated `.ads` is not touched).
- `tools/gen-docs.py` (the `Base85_Decode` declaration, next to
  `Body_Bytes`) and the regenerated `src/adacovex-docs_template.ads`;
  `make book` then `python3 tools/gen-docs.py --check`.
- `docs/contributing/architecture-outputs.md` if the encoding contract is
  restated there (it is, in the AGENTS.md tooling note; check for drift).

### Pre-implementation research steps

1. Read `tools/gen-docs.py`'s encoder (the z85 alphabet and the short-group
   rule) and confirm it matches `Base85_Decode` **symbol by symbol**,
   including the punctuation run and its order. A one-character alphabet
   mismatch would still round-trip through real data only if the encoder has
   the same bug, which is exactly the case a golden vector catches.
2. Confirm whether any bundled asset currently has a short final group, and
   if so which one. If none does, the short-group path in the decoder is
   untested today and item 4 closes a real gap.
3. Check the complexity gate before adding ~150 lines to
   `adacovex_server_tests.adb` (the file is 222 lines; the complexity gate
   scores per-file LOC and per-function cyclomatic complexity). Keep each
   new case a separate small local procedure rather than one long `Run`.

### Proof / SPARK

None. `Adacovex.Docs_Template` is `SPARK_Mode => Off` (generated string
data), and test bodies are not analysed. A test-only change to
`src/tests/` does not touch the proof input (the prove `Skip` list excludes
`tests`).

### Tests

This item **is** the tests. Category: **Server routing** (the existing
category, no new registration beyond the four-place checklist for the count).
Expected additions: roughly 40-60 assertions across the vectors, the
degenerate lengths, the alphabet fallback, `Body_Bytes`, and `Find`.

---

## Item 5: Reduce `make check` and `make build` wall time

### Where the time goes today

`make check` runs, in order: the cheap static gates (ascii, complexity,
csslint, spark-off, changelog, action-parity, docs-coverage, tools, cli-e2e,
version, version-consistency, doc-links, link, docs-check, para-split,
book-links), then `build`, `test`, `prove`, `fmt`, `doc`, `book`, `sbom`,
then the count-sync checks. The measured costs, from
`docs/contributing/perf/prove-timing.md` and
`docs/contributing/perf/benchmarks-timings.md`:

| Step | Cost | Note |
|------|------|------|
| `make prove` on an unchanged tree | ~1.0 s wall | almost all of it the no-op `alr build`; the adacovex run is ~55 ms |
| prove cold (result cache + session wiped) | 61-88 s | solver-bound; nothing adacovex does reduces it |
| `alr build` no-op | ~0.3 s | already cheap |
| `gen-docs.py --check` no-op | ~0.3 s | already cached by SHA-256 since 1.51.0 |
| Sphinx incremental, one-page prose edit | ~1.2 s | was ~7 s |
| Sphinx navigation change (page move) | ~5.5 s | full `-a` rewrite of every page |
| pipeline warm / cold | 46 ms / 73 ms | the I/O floor is ~6.9k `newfstatat` |
| native test suite | not recorded here | 1637 tests; measure before assuming |

So the two big-ticket items (`prove` cold, Sphinx rebuild) are already
optimised and are solver/build-tool costs, not adacovex costs. The
remaining, realistically addressable time is in the **gate orchestration**
and the **duplicate work between gates**.

### Scope

**Re-scoped by measurement.** The original draft assumed three Sphinx
builds per `make check` and proposed parallelising the cheap gates. Both
assumptions are now measured and both are wrong in detail:

- `tools/gen-docs.py --check` correctly **skips** Sphinx when the sources
  are unchanged (0.8-1.4 s, 0 `sphinx-build` execs), so it is not a third
  build;
- `make check` performs the identical full Sphinx build **twice**: once in
  the `book-links-check` gate (17.6-31.8 s) and once inside `tools-check`,
  in `TestCheckBookLinks.test_fresh_build_produces_whole_book` (18.57 s of
  the 20.6 s the whole 137-case suite takes). Both call
  `check_book_links.sphinx_build_into`;
- every other gate is under 0.5 s, and the 13 of them sum to about 3.5 s, so
  parallelising them could save at most ~2 s and is not worth the
  complexity or the new failure modes.

So item 5 is **one change**: remove the duplicated Sphinx build. The stamp
cache and the parallel gate fan-out are dropped.

1. **Deduplicate the two identical Sphinx builds.** Two viable shapes:
   - have `tools/check-book-links.py` keep its own fresh build (its
     docstring is explicit that a stale local `docs/_build` must never mask a
     broken link) and make the **test** reuse it, by having the gate expose
     the freshly built directory (an env var or an argument) and the test
     read it; or
   - keep the test self-contained and have `make check` run the build once
     into a temp directory that both the gate and the test consume.

   Prefer the first: the gate is the authority, and the test then asserts
   against the same artifact the gate validated rather than a second copy.
   Whichever is chosen, the test must still skip when `sphinx-build` is
   unresolvable, as it does today.
2. **Share one Sphinx build.** The cleanest win: have
   `tools/check-book-links.py` consume the output that `tools/gen-docs.py`
   just produced, instead of running its own build. The script's own
   docstring says it runs "against a fresh `sphinx-build` from a temp copy of
   `docs/`, so a stale local Sphinx build output can never mask a broken
   link" - that safety property must be preserved. The way to preserve it
   *and* remove a build is to have `gen-docs.py` hand the verified build
   directory to the link checker through an explicit argument, so the
   checker still validates the **fresh** tree it was given rather than
   whatever is on disk. Record the contract change in the script docstring.
3. **Reorder so nothing runs before a gate that would make it redundant.**
   `make fmt` runs after `test` and `prove`; if `gnatformat` rewrites a
   source, the build and proof it just did are stale. Move `fmt` **before**
   `build`, so a formatting change is picked up by the single build that
   follows. This is both a time win (one build instead of two) and a
   correctness win (the proof is against the shipped bytes).
4. **Do not attempt to speed up prove cold.** The docs are explicit that it
   is solver-bound and tracks the VC count. If a future VC count rises, the
   cost rises; that is the cost of the guarantee.

### Target files

- `Makefile` - the `check` recipe order and any `-j` fan-out.
- `tools/check-book-links.py` - accept a prebuilt directory.
- `tools/gen-docs.py` - expose the verified build directory.
- `tools/tests.py` - update
  `TestCheckBookLinks.test_fresh_build_produces_whole_book` to consume the
  gate's build instead of making its own; all other cases unchanged.
- No new tool script: the stamp cache was rejected in Q2.
- `docs/contributing/perf/index.md`, `docs/contributing/developer-guide.md`,
  `AGENTS.md` (the `check` row of the Makefile table).

### Pre-implementation research steps

1. **Measure the gate list, do not guess.** Wrap each gate with
   `tools/perf-bench.py`-style timing (or a plain `time` loop) over three
   consecutive `make check` runs and record per-gate seconds. Expect Sphinx
   to dominate the documentation gates; confirm before optimising.
2. Confirm the three-Sphinx-builds claim by counting `sphinx-build`
   invocations in one `make check` (`strace -f -e trace=execve`, or
   temporarily echo in each script). If `book-links-check` and
   `gen-docs --check` really each build, that is the first target.
3. Check `gnatformat` behaviour: does `make fmt` rewrite files, or only
   report? If it rewrites, item 3 is a correctness fix, not only a speed fix.
4. Check whether `make check` is run in CI with a cold `obj/` and a cold
   cache. If CI always runs cold, the stamp cache (item 5) helps only local
   iteration; say so in the docs rather than claiming a CI win.
5. Decide the flag surface. A stamp cache must never let a gate pass in CI
   that did not run. Recommendation: stamps are enabled only when
   `CI` is unset, so CI always runs every gate from scratch, and
   `make check --force-gates` (or `make clean`) bypasses them locally.

### Proof / SPARK

None. `tools/` and `Makefile` only. The one Ada-adjacent risk is item 3
(`fmt` before `build`): if formatting changes bytes, the proof must run
after `build` regenerates, which the new order guarantees. Verify
`make prove` still reports the ledger numbers after the reorder.

### Tests

`tools/tests.py`: the one Sphinx-build case is rewritten to reuse the gate's
build (it must still skip when `sphinx-build` is unresolvable), and the
`check-book-links.py` cases must keep passing when no prebuilt directory is
passed, so the script stays usable standalone. Add a case asserting the gate
still rejects a broken link in a freshly built tree, so deduplication cannot
weaken the check.

---

## Item 6: Split the documentation pages over the 250-line cap

### Current state (measured)

`tools/check-docs.py` sets `MAX_LOC = 250` and currently only **prints** a
warning to stderr for an over-cap page; it is not added to the error list,
so it does not fail the gate. The opt-out is a `no-covex-docs-loc` HTML
comment near the top of the file (`has_loc_opt_out` scans the first
`LOC_MARKER_SCAN` lines). `docs/api-docs` is excluded entirely.

Hand-written pages and root files at or near the cap:

| File | Lines | Status |
|------|-------|--------|
| `docs/index.md` | 248 | **at the edge**; any addition trips the warning |
| `README.md` | 250 | **exactly at the cap** |
| `docs/contributing/perf/prove-timing.md` | 219 | grows every version that joins a phase |
| `docs/contributing/ste100/tooling-terms.md` | 212 | grows with every new Technical Name (item 2 adds some) |
| `docs/contributing/proving-patches.md` | 208 | |
| `docs/usage/cli-reference.md` | 203 | grows with every flag (item 3 may add none) |
| `docs/usage/dashboard-api.md` | 203 | |
| `docs/usage/cli-reference-flags.md` | 200 | |
| `docs/usage/sbom.md` | 193 | grows with item 2 |
| `docs/contributing/architecture-verification.md` | 178 | |

Changelogs over the cap: `adacovex-1.38.0.md` (382), `-1.50.0.md` (365),
`-1.49.0.md` (250, exactly at), `-1.33.0.md` (242), `-1.28.0.md` (237),
`-1.15.0.md` (230). The first two already carry the `no-covex-docs-loc`
opt-out, which is the sanctioned outcome for a dated record. The rest are
under the cap.

So no page is *currently failing*. The work is to remove the pressure before
1.55.0 makes it acute: `prove-timing.md` gains a phase column and a 1.55.0
entry, `sbom.md` and `sbom-resolution.md` gain the Go section, and
`tooling-terms.md` gains Technical Names.

### Scope

1. **Split the pages that 1.55.0 itself pushes over**, choosing splits that
   follow the existing toctree grouping so no page is orphaned:
   - `docs/contributing/perf/prove-timing.md` (219) -> keep the phase tables
     and the reading notes; move the SIMD / optimisation-candidate review
     (the `## SIMD and other optimisation candidates (1.46.0)` section,
     ~50 lines) into the existing `docs/contributing/perf/optimisation-history.md`
     or a new `prove-optimisation-review.md` under the performance
     toctree. This is the natural split: a dated review is history, and the
     history page is where dated reviews live.
   - `docs/usage/sbom.md` (193) -> move the long `### Extension-based
     inference` table (28 supported extensions, ~35 lines) into
     `docs/usage/sbom-resolution.md`, which is the resolution page and is
     only 136 lines. That leaves `sbom.md` with the subcommand contract and
     `sbom-resolution.md` with detection and resolution.
   - `docs/contributing/ste100/tooling-terms.md` (212) -> only if item 2 pushes
     it over; the lexicon pages are a natural family, so split by category
     only when forced.
   - `docs/index.md` (248) and `README.md` (250) -> **do not add to these in
     this release.** Any new page goes into an existing toctree entry, and
     any index row that duplicates a page's own content is removed, following
     the 1.54.0 C5 precedent.
2. **Promote the line cap from a warning to a gate (decided, see Q3).**
   Add the over-cap condition to `errors` in `tools/check-docs.py` so it
   fails `make docs-check`, while keeping the `no-covex-docs-loc` opt-out
   for dated records (changelogs, archives, reference lexicons). Verified
   safe: `python3 tools/check-docs.py` currently prints no over-cap warning
   for any page, so promoting the condition fails nothing today. A soft cap
   has already let `docs/index.md` sit at 248 and `README.md` at exactly
   250, one edit from tripping.
3. **Verify the opt-out list stays minimal.** Today it is applied to
   `docs/contributing/architecture-outputs.md`,
   `docs/contributing/developer-guide.md`, and six changelogs. Confirm each
   is genuinely a dated record or a reference dictionary, and that none is an
   opt-out taken to avoid a split.
4. **Keep every split honest.** `tools/check-docs-coverage.py` requires every
   hand-written `docs/usage/` and `docs/contributing/` page to be named by a
   `{toctree}` in `docs/index.md`, so a new page must be added to the right
   toctree or the gate fails. `tools/check-links.py` must resolve every moved
   link, including from `README.md`, `CONTRIBUTING.md`, `AGENTS.md`, and the
   changelogs (which are historical and may link forward). Then
   `make book` regenerates `src/adacovex-docs_template.ads` and
   `python3 tools/gen-docs.py --check` plus `make book-links-check` must pass.

### Target files

- `docs/contributing/perf/prove-timing.md`, plus the destination page and
  the performance `{toctree}` in `docs/index.md`.
- `docs/usage/sbom.md` and `docs/usage/sbom-resolution.md`.
- `docs/index.md` (toctree entries only; **no new prose**).
- `tools/check-docs.py` - the gate promotion.
- `tools/doc-links.map` if the AGENTS.md documentation block changes.
- `src/adacovex-docs_template.ads` - regenerated by `make book`.

### Pre-implementation research steps

1. Run `python3 tools/check-docs.py` and record every page it currently
   warns about, so the before-state is known and the after-state can be
   compared. Confirm the list matches the table above.
2. Grep for inbound links to each page being split, across `docs/`,
   `README.md`, `CONTRIBUTING.md`, `AGENTS.md`, and `.github/`, so no link
   is broken by the move.
3. Check the `AGENTS.md` documentation block (`tools/doc-links.map`): if a
   page is split, the block needs a new entry, which means `make doc-links`
   rewrites AGENTS.md and the architecture tree may need
   `make agents-tree`.
4. Confirm the changelogs are excluded from any promotion decision: a
   changelog is append-only history, so an over-cap changelog is correct and
   keeps its opt-out.

### Proof / SPARK

None. Docs only. Regenerating `src/adacovex-docs_template.ads` does not
change the proof surface (`Is_Proof_Input` excludes both generated bundle
specs, and `Adacovex.Docs_Template` is `SPARK_Mode => Off`), so the cached
proof survives a docs-only change. That property is what makes this item
free of proof cost; do not break it.

### Tests

No new native tests. The gates are the tests: `make docs-check`,
`make para-split-check`, `make docs-coverage-check`, `make link-check`,
`make doc-links`, `make book-links-check`, `python3 tools/gen-docs.py
--check`, and `tools/tests.py` if `check-docs.py` behaviour changes (add a
case pinning that a `no-covex-docs-loc` page still passes and a non-opted
out over-cap page now fails).

---

## Item 7: Additional unit tests

### Baseline

1657 tests across 25 categories (`CONTRIBUTING.md`, `docs/test_result.md`).
Per-category counts:

| Category | Tests | Category | Tests |
|----------|-------|----------|-------|
| Types conversions | 67 | Proof patches | 35 |
| DAL compliance | 16 | ANSI terminal report | 28 |
| Source scanner | 89 | CPU and jobs | 24 |
| GNATprove parser | 72 | HLR/LLR parsing | 33 |
| Test-result parser | 50 | Completion scripts | 24 |
| CLI config | 349 | Man page renderer | 18 |
| SVG renderer | 161 | VCS support | 29 |
| HTML/Markdown renderers | 58 | Result cache | 33 |
| SBOM generator | 288 | Server routing | 48 |
| IR synthesis | 42 | Opt-out markers | 16 |
| Dir cache | 22 | Diff reports | 36 |
| Complexity check | 12 | Prove runner | 24 |

### Scope, by measured weakness

Order these by risk covered per test, not by count.

1. **Complexity check (12 tests for a multi-language analyser) - the
   biggest gap.** `src/core/adacovex-complexity.adb` scores 32 extensions and
   20+ languages, honours `--excludes` and `--skip-path` and the
   `no-covex-complexity-scan` marker, and gates the tree in
   `make complexity-check`, yet has 12 tests. Target: the per-language
   decision counting (one representative fixture per language family), the
   exclusion list precedence, the skip-path substring match, the marker
   opt-out, the LOC and percentage-of-codebase caps, and the boundary at
   exactly the threshold (at cap passes, one over fails).
2. **DAL compliance (16).** The four criteria and the A-E level matrix. Pin
   each criterion in isolation (untraced HLR, orphan tag, failing test,
   insufficient SPARK level) and the per-level threshold from
   `Min_SPARK_For` (A=Gold, B=Silver, C=Bronze, D=Stone, E=none), including
   the E case where tests are not required.
3. **Opt-out markers (16).** Four markers
   (`no-covex-complexity-scan`, `-docstrings`, `-spark-proof`, `-analysis`)
   detected in the leading comment block. Pin that a marker in the **body**
   of a file is not honoured, and that the combined `-analysis` marker
   disables all three analyses.
4. **Man page renderer (18).** The man page embeds the version and
   `man --check` distinguishes "matches" from "newer available" from "none
   installed". Pin all three exit codes, the mandb-missing warning path, and
   the `--dir` override layout (`<dir>/man1/`).
5. **VCS support (29).** Marker-file detection for git, hg, svn, fossil, and
   jj; the command-probe fallback; the recommended-conversion note for svn
   and fossil; and a base-snapshot failure that must not touch the working
   tree. Add cases for the less common paths (fossil `open` on a copied DB,
   jj via its internal git store) since these are the hardest to get right
   and are least exercised.
6. **Prove runner (24).** `Append_Unit_List` with
   `no-covex-spark-proof` markers (the `-u` path), option string assembly
   (every flag in `Build_Option_String`, including the `--steps 10000`
   default and the `--no-loop-unrolling` always-on behaviour), and the
   `.gpr` root discovery.
7. **CLI config (349).** Already large; add only for behaviour this release
   touches. If item 2 or 3 introduces a flag, this is where its parse and
   reject paths go (and then `action.yml` plus the `docs/usage/ci-cd-action.md`
   inputs table must follow, per the parity gate).
8. **Server routing and the decoder** are item 4, not repeated here.

### Target files

- `src/tests/adacovex_complexity_tests.adb`
- `src/tests/adacovex_dal_tests.adb`
- `src/tests/adacovex_opt_outs_tests.adb`
- `src/tests/adacovex_man_tests.adb`
- `src/tests/adacovex_vcs_tests.adb`
- `src/tests/adacovex_prove_runner_tests.adb`
- `src/tests/test_runner.adb` (only the totals, since no new category)
- `tools/update-test-count.py`, `tools/agents-tree.map`, `CONTRIBUTING.md`
  (the four-place checklist)
- `docs/test_result.md` (written by `make test`)

### Pre-implementation research steps

1. Read `src/core/adacovex-complexity.adb` end to end and list every
   decision-counting rule per language, then check which has a fixture. The
   gap list drives the work; do not guess from the count.
2. Read `src/compliance/adacovex-compliance-dal.adb` and confirm the 16
   existing tests cover the four criteria or only the level matrix.
3. For VCS, list the five backends and the snapshot command each issues, then
   check which the 29 tests actually execute. A backend that is only
   detected, never snapshotted, is the gap.
4. Confirm the per-file and per-function complexity caps before adding code
   to the test bodies: `make complexity-check` scores `src/tests/` too, so a
   test file that grows past its LOC cap fails the gate. Split a test file
   into a sibling (`..._tests.adb` plus a second unit) only with a new
   `tools/agents-tree.map` entry and a new category row.

### Proof / SPARK

None. Test bodies are excluded from the proof (the prove `Skip` list has
`tests`), and the complexity package is one of the two `SPARK_Mode (Off)`
exemptions. Keep it that way: **no** new test file may need
`SPARK_Mode (Off)`, and `make spark-off-check` must still pass.

### Tests

This item is the tests. Target roughly 120-180 new assertions across the six
categories, weighted to Complexity check (item 1), DAL compliance (item 2),
and VCS (item 5). After `make test`, run `make test-count` so
`CONTRIBUTING.md` and `docs/test_result.md` agree, and update the three
AGENTS.md figures (`1637` in the dogfood target list, the `test_runner.adb`
line, and the Verification table).

---

---

## Measured baselines (2026-10-02, this machine)

### Re-baseline taken with the 1.55.0 work (evening session)

Recorded after the three changes landed, with `/proc/loadavg` beside every
figure. The box was busier in the evening than in the morning (load
reached 21.9), which is exactly why the load is part of each row.

| Shape | Command | Result | Load | Note |
|-------|---------|--------|------|------|
| Prove warm | `bin/covex prove` (hyperfine n=15) | **58.2 ms +/- 7.7 ms** | 2.8 | 47.1-68.5 ms; within noise of the phase's 55 ms |
| Pipeline warm | `bin/adacovex --no-svg --no-md` (n=15) | **44.1 ms +/- 3.2 ms** | 2.8 | 39.8-50.2 ms; phase figure 46 ms |
| Pipeline cold | same, result cache wiped (n=10) | **75.5 ms +/- 4.1 ms** | 2.8 | 70.3-81.6 ms; phase figure 73 ms |
| **Prove fully cold** | `bin/covex prove --no-cache`, `obj/gnatprove/` + result cache wiped | **80.2 s** | 7.2 | 878 VCs, 0 unproved, 0 justified |
| **Prove fully cold** | same, repeated | **81.7 s** | 2.3 | agrees with the 80.2 s sample within 2% |
| **Prove fully cold** | same, repeated | **120.6 s** | 21.9 | 50% slower on the same binary; load, not code |
| `make prove` warm | unchanged tree, 3 runs | **2.3-2.5 s** | 3.8 | not the prove short-circuit: it also regenerates the manual and dashboard |
| Warm syscalls | `strace -f -e newfstatat` | **8,844** | 3.7 | phase floor is ~6.9k |
| Stripped binary | `strip` copy of `bin/adacovex` | **5.47 MiB** | - | phase figure 5.3 MiB |
| Manual spec | `src/adacovex-docs_template.ads` | **1.97 MiB** | - | phase figure 1.93 MiB |

**The fully cold row is the answer the phase table could not give.** The
existing "prove cold" column wipes the result cache *and* the session store
but was measured as three hyperfine repetitions at an unstated load. This
session measured the same shape three times with the load recorded: the two
low-load samples agree within 2 percent, so **80-82 s is the idle-machine
figure and 121 s is the heavy-load figure**. Any published cold number on
this box without a load column is not comparable.

**Nothing else moved.** Warm prove, warm pipeline, cold pipeline, and the
stripped size all sit on the 1.50.0 phase column within noise, so 1.50.0
keeps the representative slot and 1.55.0 folds into the open phase. The
three code changes are off the measured shapes: the probe-cache fix returns a
corrupted-fingerprint run to the healthy warm floor (976 ms / 11 spawns to
57 ms / 1 spawn), the Sphinx dedup takes the book-links gate from ~18.6 s to
0.44 s warm, and Go resolution adds two offline file reads per vendored Go
component, invisible in the warm pipeline because the result cache
short-circuits before the walk.

### Morning session (item 1 baseline)

Machine: 12 logical cores, Linux, GNAT toolchain via Alire, gnatprove 16.1.0
(resolved into `~/.adacovex/toolchain/`), Sphinx 9.1.0, Python 3.14.7,
hyperfine 1.20.0, strace 7.2. Tree: `adacovex` self at v1.54.0 (binary
`bin/adacovex`, unstripped dev build). All figures are the **self tree**
unless stated.

**Read the load column.** This machine was shared during the session
(load average ranged 1.4 to 6.0). A load-6 sample of the same warm run read
**2.4 s**; the same command at load 2.0 reads **75 ms**. A 30x swing from
load alone. Every number below was taken at load <= 5 and cross-checked
against adacovex's own `Completed in` line, which is immune to process
scheduling noise. **Any future benchmark on this box must record
`/proc/loadavg` alongside the figure, or it is not comparable.**

### Pipeline (item 1 baseline)

| Shape | Command | Result | Note |
|-------|---------|--------|------|
| Warm | `adacovex --target=. --no-svg --no-md` | **72-81 ms** (3 runs, hyperfine n=20) | internal `Completed in` 36-54 ms; the rest is process start |
| Cold | same, `--cache-dir=<fresh>` | **216 ms** (hyperfine n=12) | full rescan; the machine-local probe and meta stores still serve |
| Warm, no SBOM | `--no-sbom` added | **89 ms** | the SBOM graph build costs ~30 ms warm |

Syscall profile, warm (`strace -f -c`): **7,114 `newfstatat`**, 312
`openat`, 533 `read`, 224 `getdents64`, 8,183 total. The 7.1k stat count
matches the ~6.9k floor documented in `prove-timing.md`, so the I/O layer is
still at its floor after this measurement. `execve`: **1** (only the initial
process; no subprocesses on a warm run).

### Item 1 confirmed: the double read is real

`openat` counts per file, same command, warm vs fresh cache dir:

| File | Warm | Cold | Extra opens on a miss |
|------|------|------|----------------------|
| `.readthedocs.yaml` | 1 | 2 | +1 |
| `.github/workflows/ci.yml` | 1 | 2 | +1 |
| `.github/workflows/pr-check.yml` | 1 | 2 | +1 |
| `.github/workflows/release.yml` | 1 | 2 | +1 |
| `.github/ISSUE_TEMPLATE/config.yml` | 1 | 2 | +1 |
| `.github/FUNDING.yml` | 1 | 2 | +1 |
| `tests/e2e/pnpm-lock.yaml` | 1 | 2 | +1 |
| `install.sh` | 1 | 2 | +1 |
| `index/ad/covex/*.toml` (16 files) | 1 each | 2 each | +16 |

Total `openat`: **656 warm vs 827 cold (+171)**, and **every** scan-eligible
build file is opened exactly twice on a miss. This is the predicted defect,
measured. The 16 `index/ad/covex/*.toml` files are the surprise: the
tools-key walk descends into `index/`, which the prove `Skip` list excludes.
Item 1's scope should therefore also add `index` to the tools-key exclusion
list (it is a vendored Alire index, never a place a project names its own
build tools).

### NEW FINDING (not in the original item 1): a permanent cache-miss bug

While measuring, a warm run was found to take **975 ms against 57 ms** for
the identical command. Root cause, confirmed by reading the code and
reproducing it:

`Discover_System_Dev_Deps` caches the referenced-tool set with each probe's
binary-identity fingerprint. On a cache hit, each fingerprint is
re-validated against the installed binary
(`Tool_Fp_Digest`); a mismatch means "this tool was upgraded", so the tool
re-probes. That is the designed behaviour and it is correct.

The bug is the **store guard**. The re-probe branch runs only
`if From_Cache`, but the block that persists the refreshed set is guarded by:

```ada
--  Store the freshly scanned set ... On a cache hit nothing is stored
--  (the entry is still current and complete).
if not From_Cache and then Key_Len > 0 then
   Adacovex.Cache.Put_Cached (Key_Img (1 .. Key_Len), S, OK);
end if;
```

So when a hit triggers a re-probe, the **corrected fingerprints are never
written back**. The stale blob survives, so the mismatch is detected again
on the next run, and again on every run after that. The state is
**permanently self-re-infecting** and never self-heals.

Measured A/B on the identical tree and command (hyperfine n=20 / n=12):

| State | Warm run | `execve` | Subprocess spawns |
|-------|----------|----------|------------------|
| Fingerprints match (healthy blob) | **57 ms** | 1 | none |
| Blob carrying 3 stale fingerprints | **976 ms** | 11 | `pnpm --version`, `git --version`, `perf --version` |

The three culprits on this machine were `git`, `perf`, and `pnpm`, whose
binaries changed after the blob was written on 2026-09-28. Confirmed by
recomputing `Tool_Fingerprint` for all 23 referenced tools in Python: 20
match, 3 mismatch, and those 3 are exactly the 3 that spawn. The version
probe itself costs ~1.09 s for `pnpm` alone (measured directly:
`pnpm view nomnoml version license homepage --json` = 1.089 s wall).

Deleting the one stale blob (`~/.adacovex/cache/1.54.0/s11/to/tools:<key>`)
and running once heals the state: the next run is 45 ms with 1 `execve` and
no spawns. This is a **one-line fix** (persist the set whenever a
re-validation changed something, not only on a miss) and it is worth more
than every other item 1 optimisation combined. It also means the
`prove-timing.md` warm figures were measured on a machine that may have been
in the broken state, so the historical 46-55 ms numbers should be treated as
"healthy-cache" figures and re-taken after the fix.

**Item 1 must be split**: the fingerprint-persistence fix is a *correctness
and latency bug fix* and should land first, on its own, ahead of the
single-pass walk. They are independent changes.

### Gate timings (item 5 baseline)

Measured individually (`date +%s.%N` around each recipe), load 3.5-5.2:

| Gate | Time | Note |
|------|------|------|
| `tools/check-book-links.py` | **17.6-31.8 s** | **the single most expensive gate** |
| `tools/tests.py` (`tools-check`) | **28.9 s** | 20.6 s of it is one test case |
| `tools/gen-docs.py --check` | 0.8-1.4 s | skipped (no Sphinx) when unchanged |
| `tools/check-docs.py` | 0.5 s | |
| `tools/check-links.py` | 0.4 s | |
| `tools/csslint.py --check` | 0.16 s | |
| `tools/check-changelogs.py` | 0.17 s | |
| `tools/check-version-consistency.py` | 0.21 s | |
| `tools/update-doc-links.py --check` | 0.13 s | |
| `tools/para-split.py --check` | 0.14 s | |
| `tools/spark-off-check.py` | 0.11 s | |
| `tools/check-docs-coverage.py` | 0.20 s | |
| `tools/check-action-parity.py` | 0.15 s | |

Two findings:

1. **One test case is 90% of `tools-check`.** Timing all 137 cases
   individually: `TestCheckBookLinks.test_fresh_build_produces_whole_book`
   = **18.57 s**; the next slowest is 0.72 s; the remaining 136 total 2.0 s.
   That test calls the same `sphinx_build_into` helper the gate calls, so
   **`make check` performs the identical full Sphinx build twice**: once in
   the `book-links-check` gate and once inside `tools-check`. That is
   18-32 s of pure duplication. The original plan's "three Sphinx builds"
   hypothesis was wrong in detail (gen-docs correctly skips when unchanged)
   but right in kind: **two identical builds**, and they are the two most
   expensive things in `make check`.

2. **Every other gate is under 0.5 s.** The 13 gates excluding
   `book-links-check` and `tools-check` sum to roughly 3.5 s. Parallelising
   them (item 5 step 4) can save at most ~2 s and is not worth the
   complexity. **Item 5 should be re-scoped to the Sphinx duplication
   alone**, which is worth 18-32 s, and drop the parallelisation idea.


## Sequencing and dependencies

1. **Item 1a** (the fingerprint-persistence bug fix) **first, alone**. It is
   a one-line guard change with a 17x measured effect on a warm run, it is
   independent of everything else, and every later benchmark is invalid while
   it is unfixed. Land it with its regression test, and re-take the warm
   baseline afterwards.
2. **Item 3** (gnatprove gate) next: tools-only, no proof surface. It needs a
   docstring edit to `adacovex-prove.ads`, so batch it with 1b (the other
   proof-affecting change) or accept one gnatprove session.
3. **Item 6** (docs split and cap enforcement) before **Item 2** (Go docs),
   so the Go section lands in pages that have room. Item 6 runs `make book`,
   which warms the doc bundle for everything after it.
4. **Item 1b** (single-pass tools scan) next. Measure before and after with
   `make perf-bench` and `strace`, and record the numbers in
   `docs/contributing/perf/prove-timing.md` as a fold into the open
   1.48.0-1.52.0 phase (extend it to 1.55.0 in the same edit, keeping 1.50.0
   as the representative unless the methodology shifts). **Re-take the warm
   pipeline and prove-warm figures after 1a**: the historical 46-55 ms
   numbers were measured on a machine that may have been in the broken state,
   so they should be re-baselined on a healthy cache and the phase's
   representative reconsidered if the methodology shifted.
5. **Item 2** (Go resolution) next: the largest Ada change and the one that
   adds VCs. Proof it, sync the ledger, and run the full `make check`.
6. **Item 4** and **Item 7** together (tests), then `make test` and
   `make test-count` once, so the four-place registration happens once.
7. **Item 5** (the Sphinx duplication) last: its measurement is already in
   hand (17.6-31.8 s plus 18.57 s), so it can be implemented at any point,
   but doing it last means the recorded `make check` wall time describes the
   tree that actually ships.

## Version scope statement

1.55.0 is a **minor** release and stays minor. No item introduces a breaking
change:

- no CLI flag is removed, renamed, or given a different default;
- no SBOM or Markdown output field changes shape (item 2 only fills values
  that were previously empty);
- `Cache_Schema` is expected **not** to be bumped (see item 1); if a bump is
  unavoidable it is a cache-only invalidation, which is not a user-visible
  API break, and it must be called out in the changelog;
- `make check` gains no new gate and loses no existing target; item 5 only
  removes duplicated work inside two existing ones.

## Resolved decisions (measured 2026-10-02, no longer open)

Each question below was decided against evidence gathered on this machine,
not preference. The evidence is reproducible with the commands quoted.

### Q1. The Go website field: leave it empty (decided)

**Decision: a Go dependency's website stays empty by design. No flag, no
heuristic.**

`go list -m -json golang.org/x/text@v0.21.0` was run directly. It returns:

```
{ "Path": "golang.org/x/text", "Version": "v0.21.0",
  "Time": "2024-12-04T16:04:30Z",
  "GoMod": ".../@v/v0.21.0.mod", "GoVersion": "1.18",
  "Origin": { "VCS": "git", "URL": "https://go.googlesource.com/text",
              "Hash": "d42948e...", "Ref": "refs/tags/v0.21.0" } }
```

There is **no website field**. The closest thing is `Origin.URL`, and it is
a *VCS endpoint*, not a project home page: for `golang.org/x/text` it is
`go.googlesource.com`, for a GitHub module it would be `github.com`, for a
GitLab module `gitlab.com`. Adacovex must not render a clone URL as a
project website, because the value differs by forge and the user asked for
forge-agnostic behaviour. A heuristic mapping vanity prefixes to URLs would
also be a guess, which the "never guess" principle forbids.

So: **version yes, licence yes, website no.** That is an honest, defensible
answer and it is consistent with the existing npm/pnpm row, where
`homepage` is frequently empty because the registry omits it.

The licence answer was also verified and is the strongest part of the
design. After `go get golang.org/x/text@v0.21.0`, `go list -m -f
'{{.Dir}}'` yields `/home/data/go/pkg/mod/golang.org/x/text@v0.21.0`, and
that directory contains a `LICENSE` file whose first line is
`Copyright 2009 The Go Authors.` (a BSD-3-Clause notice). Reading the
licence from the module cache is exactly how it works for a vendored tree,
so **one code path serves both the vendored and the resolved case**, and it
is forge-agnostic because the licence ships inside the module.

Important caveat found by measurement: `Dir` is **absent** until the module
is actually downloaded (`go list -m -json` on a not-yet-fetched module
returns no `Dir`), so the resolver must treat a missing `Dir` as "no
licence available" and fall back cleanly. It must not run an implicit
`go mod download` for every component, which would turn a fast path into a
multi-second one.

### Q2. The item 5 stamp cache: local only, never in CI (decided)

**Decision: stamps are enabled only when `CI` is unset. CI always runs
every gate from scratch.**

Reasoning is now measured rather than assumed. The gate breakdown shows
that only two gates are slow (`book-links-check` 17.6-31.8 s and one test
case inside `tools-check` at 18.6 s); the other 13 sum to about 3.5 s. A
per-gate stamp cache is therefore the wrong tool: it would add a stamp file,
a digest computation, and a bypass path to save at most ~3.5 s, while
introducing the exact class of bug this release just found (state that
silently never refreshes). Item 5 is re-scoped to the Sphinx duplication
instead, which is a 18-32 s win with no new caching state.

The `CI` guard is recorded here anyway so the decision survives if a stamp
cache is ever reintroduced: a gate that did not run must never be reported
as passed, in CI or locally.

### Q3. Promote the line cap to an error: yes, it is safe today (decided)

**Decision: add the over-cap condition to `errors` in
`tools/check-docs.py`, keeping the `no-covex-docs-loc` opt-out.**

Verified: `python3 tools/check-docs.py` currently prints **no** over-cap
warning for any page, so promoting the condition to an error fails nothing
today. The page list in item 6 is the evidence: every page at or near the
cap is under it, and the only over-cap files are two dated changelogs that
already carry the opt-out.

This turns a silent convention into a gate, which is exactly the property
the release needs: `docs/index.md` sits at 248 and `README.md` at exactly
250, so both are one edit from tripping. The 4-sentence paragraph rule and
the single-space rule stay hard errors as they are; only the line cap
changes from advisory to enforced.

### Q4. `Base85_Decode` visibility: promote it to the generated spec (decided)

**Decision reversed from the original recommendation. Promote
`Base85_Decode` into the generated spec.**

The original recommendation was a private test hook, on the theory that
`Content` already reaches the decoder. Measurement shows that is not
sufficient: `Base85_Decode` is absent from
`src/adacovex-docs_template.ads` (only `Body_Bytes`, `Content`, and `Find`
are declared there), so a test **cannot** feed it a chosen byte string. It
can only observe the decoder through bodies `make book` happened to
generate, which is exactly the data-dependent weakness item 4 exists to
remove.

The cost is small and known: add the declaration in `tools/gen-docs.py`
next to `Body_Bytes` (around line 1167, the same emission block), then
`make book` regenerates the spec. The generator is the single source of
truth, so the declaration cannot drift. Because
`Adacovex.Docs_Template` is `SPARK_Mode => Off` and is excluded from the
proof input hash by `Is_Proof_Input`, neither the regeneration nor the new
declaration costs a proof session.

The hook is rejected: it would add a declaration that exists only for tests
and would not be covered by the generator, which is the pattern the repo
already uses `make book` to avoid.

