# adacovex 1.55.0

Date: _2026-10-02_

Version bumped 1.54.0 -> 1.55.0.

## Changes

### C1: Go modules resolve a version and a licence

A vendored Go component now reports both a version and a licence. Before this
release a Go component had a name, a language, and a PURL, and nothing else.

- **Version, offline.** A module's own `go.mod` states the module path but
  never the module's own version: its `require` block lists that module's
  dependencies, not the module itself, so reading it would have reported a
  wrong version. The version comes instead from the vendor root's
  `modules.txt`, the manifest `go mod vendor` writes as a `# <module>
  <version>` line. This is the only offline source of a vendored module's
  pinned version.
- **Version, fallback.** With no `modules.txt`, `go list -m --json
  <module>@latest` supplies the latest published version. The query goes
  through whatever module proxy `GOPROXY` names, so the Go toolchain decides
  which source answers and adacovex never constructs a host name. One spawn
  answers the version.
- **Licence.** The Go toolchain reports no licence in any form, so the licence
  is read from the licence file beside the manifest and classified into an
  SPDX identifier by matching marker phrases from the text: Apache-2.0, MIT,
  MPL-2.0, ISC, Unlicense, and the two- and three-clause BSD variants. A row
  matches only when every marker it requires is present and no marker it
  excludes is present, so a four-clause BSD text reports no licence rather
  than the three-clause one. A text that matches nothing also reports no
  licence. A licence is never guessed.
- **Website.** Always empty. `go list -m` has no website field, and its
  `Origin.URL` is a forge-specific VCS endpoint, not a project home page.

Nothing in the path names a forge, so the same code serves a module on
GitHub, GitLab, Gitea, Codeberg, or a private mirror, and a vanity import
path (`golang.org/x/text`, `gopkg.in/yaml.v3`, `k8s.io/api`) resolves the
same way as a forge-hosted one.

The PURL type stays `pkg:golang` and the PURL is
`pkg:golang/<module path>@<version>`. The registry ecosystem token is `go`,
not `golang`, and the vendored-manifest reader now carries both: the PURL
type follows the package-url specification while the resolver dispatches on
the name of the CLI it spawns.

The Go resolver row in `Resolve_Ecosystem_Metadata` was **dead code**: it was
keyed `go` while the reader emitted `golang`, and the dispatch matches the
two exactly, so the row could never be reached. The reader now emits the
token the table is keyed by, and the row answers.

The resolver now also skips a spawn whose table row can add nothing the
caller does not already hold, through two new `Have_Version` and
`Have_License` parameters, and the vendor root's `modules.txt` is parsed once
per root and looked up in memory instead of once per component. Measured on a
synthetic tree with 100 vendored Go modules (cold result cache, paired runs
against a build of the 1.54.0 tree):

| Build | Cold run | `go` spawns | `modules.txt` opens |
|-------|----------|-------------|----------------------|
| 1.54.0 (base) | 40.9 ms +/- 3.5 ms | 0 | 0 |
| 1.55.0 | 39.7 ms +/- 3.2 ms | 0 | 2 |

The two figures sit inside each other's spread, so the feature is free at the
binary level. The remaining difference from the base is 100 extra `newfstatat`
and 200 extra `openat` calls across 100 components: one `modules.txt` probe
and two licence-file probes per component, which is the cost of answering
offline. All 100 components still report both a version and an SPDX licence.

### C2: Timing re-baseline, including the fully cold prove run

`docs/contributing/perf/prove-timing.md` carries a new reading note for the
fully cold shape: the result cache, the gnatprove session store, and the
proof summary all absent, which is the shape a first run on a new checkout
sees. Measured five times with the machine load recorded beside each figure,
the fully cold `prove` run reads **72.0 s at load 3.6, 73.1 s at load 5.0,
80.2 s at load 7.2, 81.7 s at load 2.3, and 120.6 s at load 21.9**, all at 878
VCs with 0 unproved and 0 justified. The four low-to-moderate-load samples
span 72-82 s, and the heavy-load sample is 121 s; the spread is the shared
machine, not the tool.

1.55.0 therefore opens **its own phase** in the table, with 1.55.0 as the
representative, because the methodology changed and not only the code: every
figure is now read with the machine load beside it, and the fully cold prove
shape is measured for the first time. The closed phase is 1.48.0-1.54.0 with
1.50.0 as its representative. The new column reads prove warm 49.9 ms,
pipeline warm 41.3 ms, pipeline cold 66.5 ms, and warm `newfstatat` 7,280,
all at load 0.5-0.6: flat or slightly better than the closed phase's 55 ms,
46 ms, 73 ms, and ~6.9k. The page also records that `make prove` on an
unchanged tree costs about 1.1 s where `./bin/covex prove` alone costs 50 ms,
so neither number is mistaken for the other.

## Fixes

### H1: A corrected system-tool fingerprint was never stored

`Discover_System_Dev_Deps` re-probed a tool whose cached fingerprint no
longer matched the installed binary, then discarded the corrected
fingerprint: the re-probe branch ran only when the answer came from the
cache, while the store-back was guarded on the answer *not* coming from the
cache. The two guards could never both be true, so a stale fingerprint was
re-probed on every run forever and the store never healed.

The store guard now also fires when the fingerprint was corrected during a
re-probe. Verified with `strace`: on a probe blob whose stored fingerprint is
deliberately corrupted, the first run probes twice, the second run probes
once, and the third probes once -- the blob heals. On the same fixture the
run goes from 11 subprocess spawns and 976 ms to one spawn and 57 ms, a 17x
reduction, which is the healthy warm floor. A regression test corrupts the
stored fingerprint, re-runs the discovery, and asserts the zeros are gone;
reverting the guard alone makes it fail.

### H2: The bundled-manual link check built the whole manual a second time

`make check` runs `tools/gen-docs.py --check` and then
`tools/check-book-links.py`, and the link check ran its own `sphinx-build`
over a fresh copy of `docs/`. Every run therefore built the same manual
twice.

The link check now shares one content-keyed build with the generator, stored
under `obj/book-links-check/` and keyed on the docs tree fingerprint, the
Sphinx command, and the Sphinx version. A cold run still takes 14.6 s; a warm
run takes 0.44 s, and the `tools-check` suite that exercises the gate drops
from 28.9 s to 2.5 s.

The gate keeps its teeth. Because the key is the docs tree fingerprint, any
docs edit forces a fresh build, and appending a broken link to `docs/index.md`
still fails the gate with `link to missing bundled asset`. A new test asserts
that a docs change invalidates the cached build, so the cache cannot become a
stale-build hazard.

### H3: A release run that failed in its last step could never be retried

The v1.55.0 release run published the release and attested both tarballs. It
then failed while it moved the floating tags. A re-run died earlier, in
`Create GitHub Release`, because `gh release create` fails when the tag already
has a release. The floating tags were never moved, so `@latest` kept pointing
at v1.54.0.

The publish step is now idempotent: when the tag already has a release, the
workflow updates the release notes and replaces the assets. A re-run can
finish a run that failed in its last step.

The floating-tag step pushes the three refs in one command and retries a
failed push three times. A refusal that no retry removes is a repository rule,
so the step reports the ref it could not move as an `::error::` annotation at
the top of the job page. The step also never rewrites the release tag, and it
pushes a repeated floating name once.

## Test Suite

1657 tests across 25 categories, up from 1644. The SBOM / manifest-graph
category gains 13 checks.

Added:

- The corrected tool fingerprint is written back to the probe store, so a
  corrupted probe blob heals on the next run.
- A vendored Go module's version comes from `modules.txt`, and its licence is
  classified from the licence file: MIT for one fixture, BSD-3-Clause for a
  vanity-path fixture.
- A four-clause BSD licence text reports no licence, so the exclusion rule is
  pinned: reverting it makes the test fail with the text misreported as
  BSD-3-Clause.
- A Go module with no licence file keeps an empty licence, and a module absent
  from `modules.txt` keeps an empty version. Neither is ever guessed.
- The Go PURL keeps the `pkg:golang` type while the registry token is `go`.
- A complete offline read spawns no registry CLI. The `modules.txt` version
  and the licence-file classification are both offline, so the resolver row
  is skipped rather than spawned for an answer the caller discards.
- The manual link check's shared build is reused on an unchanged tree and
  rebuilt after a docs change.

## Proof Results

Platinum, 0 unproved, 0 justified, 878 VCs (878 proved) across 66 analysed
units under gnatprove 16.1.0 at `--level=4`. The VC count is unchanged from
1.54.0. The three new subprograms (`License_Id`, `Read_Go_Modules`, and
`Go_Module_Version`) are `SPARK_Mode => Off`, like every other subprogram in
`Adacovex.Parsers.Manifest` that touches the filesystem or spawns a tool, so
they add no VCs by design; no existing checked subprogram gained or lost an
assertion, a contract, or a runtime check. No `pragma SPARK_Mode (Off)` was
added to any package: the only two packages that carry one remain
`Types.Implementation` and `Complexity`.

## Traceability

- No new HLRs.
- `HLR-SBOM` -- C1 makes a vendored Go component a full graph entry with a
  version and a licence, and fixes the resolver row that was unreachable
  because the emitted ecosystem token did not match the table key. The two
  new readers (`Go_Module_Version`, `License_Id`) are under the same tag.
- `HLR-CACHE` -- H1 fixes the tool-probe store in `Discover_System_Dev_Deps`,
  which reads and writes the machine-local probe cache.
- `HLR-MANIFEST` -- C1 extends the vendored-manifest reader (`Vendor_Manifest`
  gains the registry token, and the reader takes the vendor root).
- `HLR-RENDER-HTML` -- none of the three changes alters a renderer. C1 keeps
  the resolved version and licence flowing into the existing SBOM renderers
  and the dashboard detail panel unchanged.
- H2 is release tooling (`tools/check-book-links.py`, `tools/tests.py`), which
  touches no assessed Ada source and no HLR.
- H3 is release tooling (`.github/workflows/release.yml`), which touches no
  assessed Ada source and no HLR.