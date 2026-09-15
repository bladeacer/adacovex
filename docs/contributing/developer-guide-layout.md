# Contributor guide: repository layout and generated artifacts

This page is the layout half of the [contributor guide](developer-guide.md):
the source tree, the execution pipeline, where a change belongs, and which
artifacts are generated rather than edited.  Setup, testing, and the proof
discipline are on the [contributor guide](developer-guide.md) itself.

## Repository tour

```
src/
|-- adacovex_main.adb              -- CLI entry point: parse -> pipeline -> render -> exit
|-- adacovex.ads                   -- Version constant
|-- core/                          -- config parsing, types, cache, VCS, GNATprove runner, diff
|-- parsers/                       -- input parsing: Ada source, gnatprove.out, tests, manifest, HLR/LLR
|-- renderers/                     -- output: ANSI, HTML dashboard, Markdown, SVG badges, SBOM, man page
|-- compliance/                    -- DO-178C DAL assessment logic
|-- server/                        -- HTTP/1.1 server (4-worker task pool) for --serve
|-- ir/                            -- bounded IR types + future-use synthesiser
`-- tests/                         -- the native test suite (test_runner entry point)
resources/dashboard.html           -- the served dashboard's page shell (plain HTML, bundled at build time)
resources/js/book-nav.js           -- the offline manual's shared-sidebar injector (bundled as _static/adacovex-nav.js)
tools/*.py                         -- pure-stdlib Python: doc sync, count sync, generators, validators
docs/                              -- all documentation (this guide, CLI reference, standards, and more)
```

The **execution pipeline** (`adacovex_main.adb`) is the spine of the tool:

```
parse CLI -> scan .ads sources -> apply docstring patches -> compute doc metrics
-> parse gnatprove.out -> parse test results -> assess DAL -> render ANSI report
-> emit SVG badges -> emit Markdown reports -> emit SBOM -> serve dashboard (if --serve)
-> exit code (0 = Achieved)
```

A handful of modes exit before the pipeline: `--help`, `--version`, `man`,
`status`, the differential modes (`--compare-base` / `--coverage-delta`), and
`sbom`.

### Where things live

| You want to... | Look at |
|----------------|---------|
| Understand the CLI flags | `src/core/adacovex-config.ads/.adb` (parser + `help` topics) |
| Add a new flag | Parse it in `adacovex-config.adb`, store it in `CLI_Config`, add a contextual `help` topic |
| Change source scanning | `src/parsers/adacovex-parsers-source.ads/.adb` |
| Add a parser for a new input | New file under `src/parsers/`, wired into the pipeline in `adacovex_main.adb` |
| Add an output format | New renderer under `src/renderers/`, called from the pipeline |
| Change the dashboard page | Edit `resources/dashboard.html` (plain HTML/CSS/JS), then run `tools/gen-dashboard.py` to regenerate `src/adacovex-dashboard_template.ads` |
| Change the offline manual's sidebar | Edit `resources/js/book-nav.js`, then run `make book` to bundle it as `_static/adacovex-nav.js` |
| Change assessment criteria | `src/compliance/adacovex-compliance-dal.adb` (+ the DAL levels doc) |
| Add tests | `src/tests/` -- see the [contributor guide](developer-guide.md#testing) |
| Regenerate API docs | `make doc` (gnatdoc -> `tools/rst2md.py` -> `docs/api-docs/`) |
| Regenerate the offline manual | `make book` (Sphinx -> `tools/gen-docs.py` -> `src/adacovex-docs_template.ads`) |
| Sync test counts | `make test-count` (reads `docs/test_result.md`, rewrites every anchored count) |
| Sync proof metrics | `make proof-status` |
| Regenerate AGENTS.md blocks | `make agents-tree` (src tree) and `make doc-links` (docs list) |
| Verify markdown links | `make link-check` |

### API docs and cross-links

`make doc` regenerates `docs/api-docs/` from the `.ads` docstrings via gnatdoc + `tools/rst2md.py`. It produces one page per package plus `index.md`. The six hand-written reference pages are never regenerated. They are the docstring spec, the test formats, the SPARK levels, and the DAL, ASIL, and Class level pages.

Cross-links between the generated package pages and the reference pages live in `tools/rst2md.py`. `GUIDE_PAGES` builds the index's "Guides" section. `PACKAGE_GUIDES` builds the per-package "See also" lines. They do **not** live in the `.ads` comments: gnatdoc parses comment text as RST and drops markdown link URLs. To add a package cross-link, extend `PACKAGE_GUIDES` in `tools/rst2md.py`. Then run `make doc` and `make link-check`.

### Offline manual and Read the Docs

`docs/` is a Sphinx project (`docs/conf.py` with the Furo theme, using the MyST parser so every page stays Markdown). Read the Docs builds the public site from it (`.readthedocs.yaml`, `sphinx.configuration: docs/conf.py`); the same docs are bundled into the binary as the offline manual. When you add, move, or rename a doc page, update the relevant `{toctree}` in `docs/index.md` in the same change. Then run `make book` (regenerates `src/adacovex-docs_template.ads`), `make link-check`, and `make docs-check`. `make book-serve` builds with Sphinx and serves the built site locally; `make docs-serve` serves the raw Markdown over plain HTTP.

### Building the manual

- `make book` runs `tools/gen-docs.py`, which first runs `sphinx-build -b
  html docs docs/_build/html` (when sphinx-build is on PATH) and then bundles
  the built site into `src/adacovex-docs_template.ads` (keeping Sphinx's own
  search machinery -- searchindex.js, searchtools.js, the stemmers -- so the
  bundled manual is searchable offline and the committed spec never churns
  its asset names).  The docs build dependencies (sphinx + myst-parser) are
  the Read the Docs installation requirements in `requirements.txt`.  The
  pages are never converted to reStructuredText.
- Every asset body is gzip-compressed, then base85-encoded (the quote-free
  Z85 alphabet, which packs 4 bytes into 5 characters where base64 needs
  5.33) into one or more Ada string constants.  The server sends the gzip
  bytes with `Content-Encoding: gzip`, so the browser inflates them and the
  binary needs no inflate routine.
- The Furo sidebar is stored once per branch under `_nav/` and every page
  keeps a stub that `resources/js/book-nav.js` fills in, so the same 8 kB
  toctree is not repeated in all 184 pages.
- The bundled manual is served by `--serve` at `/docs`.
- `make book-links-check` fails when a link in the bundled manual does not
  resolve (checked against a fresh `sphinx-build`, so a stale local
  `docs/_build/html` cannot mask a broken link);
  `python3 tools/gen-docs.py --check` (also in `make check`) fails when the
  committed spec is stale.

### Generated outputs

- `docs/compliance/VERIFICATION.md`, `docs/compliance/TRACE.md`,
  `docs/compliance/HLR.md`, and `docs/compliance/LLR.md` are generated per
  target.  Run `make compliance` to refresh the first two for the self tree
  after a metric change; the target stays out of `make prove` so the
  bundled report cannot invalidate the cached proof.
- `docs/badges/*.svg` are regenerated by `make run-self` and `make prove`.
- `docs/api-docs/` is regenerated by `make doc`.
- `docs/_build/` is the Sphinx build output and is **not** committed (it is
  gitignored, so the generated `_sources/` copies and `.doctrees/` side-car
  files never pollute git); regenerate it locally with `make book` whenever
  `docs/` changes.  The committed artifact is the generated spec
  `src/adacovex-docs_template.ads`.

Do not edit generated files by hand; regenerate them instead.
