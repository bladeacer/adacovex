# adacovex 1.40.0

Date: _2026-08-30_

Version bumped 1.39.0 -> 1.40.0.

## Changes

### C1: The manual now builds with Sphinx and the Furo theme

The user documentation under `docs/` is now a **Sphinx** project, not an
mdBook one. `docs/conf.py` selects the **Furo** HTML theme
(https://github.com/pradyunsg/furo) and the **MyST Markdown parser**
(`myst_parser`), so the docs stay written in Markdown exactly as they were --
there is no conversion to reStructuredText. Furo is a clean, modern theme
with light/dark support and no external assets, so the offline manual stays
self-contained. The build dependencies are pinned in a new top-level
`requirements.txt` (`sphinx` + `myst-parser` + `furo`), and
`.readthedocs.yaml` now points at `docs/conf.py` and installs those deps, so
the Read the Docs deploy that broke under mdBook builds cleanly again.

### C2: Offline manual bundling rebuilt around Sphinx

`tools/gen-docs.py` (wired as `make book`, run inside `make build`) now runs
`sphinx-build` over `docs/` and bundles the built site -- every page,
stylesheet, script, and badge -- into `src/adacovex-docs_template.ads` as a
path-keyed asset table, the bundled offline manual the `--serve` server serves
at `/docs`. The mdBook search/print machinery (`elasticlunr`, `mark`,
`print.html`) is gone; Sphinx's own searchable site is bundled instead.
`tools/check-book-links.py` (`make book-links-check`) verifies every link in
the bundle against a fresh `sphinx-build` from a temp copy of `docs/`, so a
stale local Sphinx build product can never mask a broken link.

### C3: Navigation driven by hidden toctrees

Sphinx sidebar navigation comes from `:toctree:` directives, so `docs/index.md`
now ends with hidden toctrees that pull in `usage/`, `contributing/`,
`api-docs/`, `changelogs/`, `proof/`, `compliance/`, and `badges/`. The retired
mdBook files `docs/book.toml` and `docs/SUMMARY.md` are deleted, and the old
`docs/book/` build output is no longer tracked (its Sphinx replacement builds
into `docs/_build/`, now gitignored). Pages not reachable from a toctree are
not auto-discovered; new doc pages must be linked from one.

### C4: Build and source tooling updated

The Makefile `book` / `book-links-check` targets, the `make help` text, the
`complexity-check` source-walk excludes (`.venv/` and `docs/_build/` added), the
manifest tool registration (`sphinx-build` replaces `mdbook`), and the SBOM
fixture/tests all reference the Sphinx toolchain. The generated `sbom.json`,
`docs/api-docs`, the modern-dashboard prose, and `tools/agents-tree.map` were
regenerated or updated in step so the tree stays internally consistent.

### C7: Python requirements resolve as pypi SBOM dependencies

`sphinx-build` is a Python package entry point, not a system binary, so it is
no longer registered as a `pkg:generic/*` system-tool dependency. The root
project's `requirements*.txt` entries (sphinx, myst-parser, and any others)
now register as **dev-scope `pkg:pypi/*` dependencies** with their language
set to Python. Versions are resolved from the package registry (`pip index
versions <pkg>`) when the requirements line pins none; a missing pip or an
offline machine keeps the name-only entry -- no version or licence is ever
guessed. `tools/gen-docs.py` and `tools/check-book-links.py` also now find
`sphinx-build` inside the repo's own `.venv/bin` when it is not on PATH, so
`make check` runs the docs gates (and the tools unit tests) on any machine
that has the venv, instead of silently skipping them.

### C5: Python is now a documented build-time dependency

The manual is built at compile time and bundled into the released binary, so
Python 3 is now a **build-time** requirement: `tools/gen-dashboard.py` and
`tools/gen-docs.py` (the latter needing `sphinx` + `myst-parser` + `furo`
from `requirements.txt`) embed the dashboard and offline manual into the
binary as generated Ada string constants. The released binary itself still
has **no runtime Python dependency**. The README, developer guide,
requirements table, Makefile help, and `THIRD_PARTY_NOTICES` all state this
clearly.

### C8: Offline manual bundle served gzip-compressed

The 184,507-line god-object spec is gone. `tools/gen-docs.py` now gzip-
compresses every Sphinx asset at build time and stores a **compact base64
chunk per asset** in `src/adacovex-docs_template.ads`: the spec shrank from
184,507 lines / 7.6 MB to about 20,000 lines / 1.7 MB (160 assets, 1.4 MB
compressed from 4.7 MB of source). The `--serve` server sends the raw gzip
stream with `Content-Encoding: gzip`, so the browser inflates it. The binary
still needs only the GNAT runtime -- no inflate routine, no Python or JS
runtime dependency. A small base64 decoder in the `Docs_Template` body
reconstructs each compressed chunk for the streaming send path.

### C9: Language support documented with explicit tiers

`target-projects.md` now explains the language support instead of the
"watch for updates" placeholder. The tiers are: **first-class**
(Ada/SPARK: scanning, docstrings, complexity, proof, DAL);
**manifest-aware ecosystems** whose manifests build the SBOM dependency
graph; **extension-detected languages** used for component language
detection, `complexity` scoring, and test-dependency classification; and the
**flexible `requirements*.txt`** handling (a literal `requirements.txt` wins;
adacovex falls back to the first `requirements*.txt` glob in the directory).

### C10: Third-party notices link Sphinx, MyST, Furo, and Playwright

`THIRD_PARTY_NOTICES.md` renders the documentation-build tools -- Sphinx,
MyST-Parser, and Furo -- and the Playwright test dependency as **clickable
links** to their upstream projects, matching the bundled-asset components
that already link out.

### C11: Manual index is now a top-level sidebar entry

The documentation index page could not be found in the sidebar: Furo's
navigation tree comes only from the root document's toctrees, and the root
document cannot reference itself (Sphinx rejects it), so only the sidebar
brand linked to the front page. A small, contained Sphinx hook in
`docs/conf.py` now prepends a labelled "adacovex Documentation"
"Documentation index" link to the navigation tree on every page, so the
index is a clickable top-level sidebar entry. The hook runs after Furo
computes the tree (priority 800), reuses Sphinx's own caption/toctree
markup, and works identically for the Read the Docs build and the bundled
offline manual.

### C6: Sphinx, Furo, MyST, and Read the Docs credited

The third-party notices (`THIRD_PARTY_NOTICES.md`) and the dashboard **Credits**
tab now credit **Sphinx**, **Furo** and **MyST-Parser** as the documentation
build tools and **Read the Docs** as the online hosting service. Furo's own
footer self-promotion block ("Made with Sphinx and @pradyunsg's Furo") is
stripped from the bundled manual (`tools/gen-docs.py`); the copyright notice
stays, and Sphinx and Furo are credited in the notices instead.

## Fixes

### H1: Read the Docs deploy becomes reproducible

The 1.39 Read the Docs deploy passed validation but still failed to render.
Migrating the manual to Sphinx fixes the root cause: Read the Docs builds
`docs/conf.py` natively with a pinned Python toolchain and `requirements.txt`
deps, so the site deploys without depending on a separately installed mdBook
binary.

## Test Suite

The native suite grows to 1213 tests across 17 categories: the SBOM tests add
assertions that `sphinx-build` is never registered as a system tool, and that
root `requirements*.txt` entries (sphinx, myst-parser) register as dev-scope
`pkg:pypi/*` dependencies with a registry-resolved version. The docs
serving path still streams through the existing server-routing tests (41 pass);
no native assertions were added for the gzip encode/decode, which is
non-SPARK runtime data plumbing (the base64 decoder lives in the
`Docs_Template` body and is rounded-trip tested by the served pages in `make
e2e`).

## Proof Results

Platinum, 0 unproved, 0 justified, 725 VCs (725 proved) under gnatprove
16.1.0. The edited Ada units (the manifest parser subtrees, the
`Docs_Template` body base64 decoder, and the HTTP server's gzip header and
chunk-decoding path) are all plain runtime bodies -- none opt into
`SPARK_Mode On` -- so no verification conditions were added and the totals are
unchanged.

## Traceability

- No new HLRs. The release touches documentation and build infrastructure
  only.
- `HLR-DOC` -- C1 the Sphinx project, C2 the rebundled offline manual, C3 the
  toctree navigation, C4 the tooling updates, C5 the Python build dependency,
  C6 the Sphinx/Furo/MyST/Read the Docs credits, C7 the pypi SBOM
  dependencies, C8 the gzip-compressed offline bundle, C9 the documented
  language-support tiers, C10 the clickable third-party links, C11 the
  sidebar index entry, and H1 the Read the Docs fix.