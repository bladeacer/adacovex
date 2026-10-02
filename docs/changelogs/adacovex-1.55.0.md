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
`Have_License` parameters. Without this, giving the Go row a live tool made
the resolver spawn `go list -m` once per vendored component and discard the
answer, because the offline read had already supplied both fields. Measured
on a synthetic tree with 100 vendored Go modules (cold result cache, no
`go` on `PATH` needed for the offline path):

| Build | Cold run | `go` spawns |
|-------|----------|-------------|
| 1.54.0 (base) | 39.5 ms +/- 3.9 ms | 0 |
| 1.55.0 before the skip | 561 ms +/- 32.5 ms | 100 |
| 1.55.0 after the skip | 40.9 ms +/- 3.5 ms | 0 |

The remaining difference from the base is 100 extra `newfstatat` and 200
extra `openat` calls across 100 components: one `modules.txt` probe and two
licence-file probes per component, which is the cost of answering offline.
All 100 components still report both a version and an SPDX licence.

### C2: Timing re-baseline, including the fully cold prove run

`docs/contributing/perf/prove-timing.md` carries a new reading note for the
fully cold shape: the result cache, the gnatprove session store, and the
proof summary all absent, which is the shape a first run on a new checkout
sees. Measured three times with the machine load recorded beside each
figure, the fully cold `prove` run reads **80.2 s at load 7.2, 81.7 s at load
2.3, and 120.6 s at load 21.9**, all at 878 VCs with 0 unproved and 0
justified. The two low-load samples agree within 2 percent, so the idle
figure is 80-82 s and the heavy-load figure is 121 s; the spread is the
shared machine, not the tool.

The phase table now reads 1.48.0-1.55.0. 1.50.0 keeps the representative
slot because every re-baselined shape sits on its column within noise: prove
warm 58.2 ms, pipeline warm 44.1 ms, pipeline cold 75.5 ms, stripped binary
5.47 MiB. The page also records that `make prove` on an unchanged tree costs
about 2.3-2.5 s where `./bin/covex prove` alone costs 58 ms, so neither
number is mistaken for the other.

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
1.54.0: the two new source files and the Go branch add proved subprograms
whose checks were already covered, and no assertion, contract, or runtime
check was added or removed. No `pragma SPARK_Mode (Off)` was added; the only
two packages that carry one remain `Types.Implementation` and `Complexity`.

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