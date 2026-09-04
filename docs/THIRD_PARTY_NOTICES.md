# Third-Party Notices

adacovex itself is Apache-2.0 (see `LICENSE`) and depends only on the GNAT runtime. It declares no library or tool dependencies. The following third-party components are used as tools or bundled artifacts. Their own licences cover them.

## GNAT / GNATprove toolchain

| Component | Version | Licence | Used for |
|-----------|---------|---------|----------|
| GNAT compiler (GNAT Community / FSF GNAT) | toolchain-managed | GPL-3.0-or-later (with GCC Runtime Library Exception for runtime) | Compiling adacovex and target projects |
| GNATprove | toolchain-managed | GPL-3.0-or-later | SPARK proof analysis (`covex prove`) |
| Python 3 | toolchain-managed | PSF-2.0 | Build-time only: `tools/gen-docs.py` bundles the offline manual into the binary |

Python 3 is required at **build time** to bundle the docs into the binary, but the shipped binary itself has no Python dependency -- the manual is embedded as generated Ada string constants. Sphinx, MyST and Furo (below) run inside Python to produce that manual; Python itself is not bundled or redistributed.
| Z3 / Alt-Ergo / CVC5 solvers | bundled with GNATprove | MIT / CeCILL-C / Apache-2.0 respectively | Satisfying SPARK verification conditions |

The GNAT toolchain is **not** embedded in the adacovex release bundle. gnatprove is **not** a declared dependency of the `covex` crate. adacovex resolves gnatprove at run time. `covex prove` prefers the own gnatprove dependency of the target project when the alire.toml / alire-dev.toml of the target project declares one. It deploys only the pinned gnatprove binary crate into `~/.adacovex/toolchain/` via `alr -n get` and runs the deployed binary directly (one-time per version; later runs reuse it). adacovex itself then requires only `alr` on `$PATH`. If no dependency is declared, it falls back to a globally pinned version, then a gnatprove on `$PATH`. Then it falls back to a cached `~/.adacovex/toolchain/bin/gnatprove`.

Finally it falls back to a platform toolchain download. This download is a GPL-licensed GNAT/gnatprove distribution. Distributing it requires the end user to accept the GPL for that component.

## SBOM specifications

The proof-aware SBOMs that adacovex emits conform to these open specifications:

| Specification | Version | Licence | Reference |
|---------------|---------|---------|-----------|
| CycloneDX Software Bill of Materials | 1.5 | Apache-2.0 | https://github.com/CycloneDX/specification |
| SPDX (Software Package Data Exchange) | 2.3 | CC0-1.0 | https://spdx.dev |

The CycloneDX 1.5 JSON and SPDX 2.3 JSON schemas are referenced for validation only. adacovex does not vendor or redistribute them.

## Bundled web assets

| Component | Version | Licence | Used for |
|-----------|---------|---------|----------|
| nomnoml | 1.7.0 | MIT | Dependency hierarchy diagram alternative view in the dashboard (`resources/nomnoml.js`, inlined into the served dashboard) |
| graphre | 0.1.3 | MIT | Graph layout engine for nomnoml (`resources/graphre.js`, inlined; required by the UMD wrapper of nomnoml) |
| FlexSearch | 0.7.31 | Apache-2.0 | Client-side search indexing for packages, HLRs and dependencies in the dashboard (`resources/flexsearch.js`, inlined into the served dashboard) |
| yace | 1.1.0 | MIT | JSON / code tokenizer highlighter for the API playground (`resources/yace.js`, inlined into the served dashboard) |
| Charts.css | not bundled (inspiration) | MIT | Inspiration for the hand-rolled dashboard charts |

[nomnoml](https://github.com/skanaar/nomnoml) is bundled under `resources/nomnoml.js` (71 KB, MIT). It is inlined into the dashboard page shell. It renders the dependency hierarchy as a UML-style diagram. The diagram appears in the alternative view of the **Dependencies** tab (Tree / Diagram toggle).

The MIT licence text is preserved in the bundle header comment.

[graphre](https://github.com/cytoscape/graphre) is bundled under `resources/graphre.js` (38 KB, MIT). It is inlined before nomnoml. It provides the `graphre.graphlib` and Dagre layout that the UMD wrapper (`global.graphre`) of nomnoml requires. Without it, `nomnoml.draw` throws `graphlib is undefined`.

The MIT licence text is preserved in the bundle header comment.

[FlexSearch](https://github.com/nextapps-de/flexsearch) is bundled under `resources/flexsearch.js` (16 KB, Apache-2.0). It is inlined into the dashboard page shell. It provides the global search box (packages, HLRs, dependencies). The search box uses an in-memory forward-tokenized index.

The index loads from `/__GRAPH_JSON__` at page load. The Apache-2.0 licence text is preserved in the bundle header comment.

[yace](https://github.com/petersolopov/yace) is a tiny, zero-dependency code editor component (under 2 KB) by Peter Solopov. adacovex vendors its `code()` tokenizer highlighter (`src/highlighters/code.ts`, MIT) as `resources/yace.js`. The tokenizer logic is unchanged: rules are tried in order at every position, and tokens are emitted as `<span class="yace-tok yace-tok--<type>">` elements with no built-in colours.

The highlighter is adapted from ESM/TypeScript to a single plain-script binding that exposes `window.YaceTok`, so the dashboard can use it without a build step. The dashboard supplies the token colours via CSS. The API playground uses it to syntax-highlight the prettified JSON responses of the `/api/*` endpoints; a JSON-key rule (`"name":`) runs ahead of the built-in string rule so object keys colour differently from string values. The MIT licence text is preserved in the header comment of `resources/yace.js`.

[Charts.css](https://chartscss.org/) is **not** bundled or redistributed with adacovex. The dashboard charts were originally rendered with the vendored Charts.css framework (1.2.0, MIT); adacovex now ships its **own patched version** of those charts, hand-rolled with plain CSS and SVG and driven by the theme's CSS variables. Charts.css is credited for inspiration, and its MIT licence terms are acknowledged here.

## Documentation build tools

| Component | Version | Licence | Used for |
|-----------|---------|---------|----------|
| [Sphinx](https://www.sphinx-doc.org) | toolchain-managed | BSD-3-Clause | Building the manual from `docs/` (Furo theme + MyST) for the deployed site and the bundled offline manual |
| [MyST-Parser](https://github.com/executablebooks/MyST-Parser) | toolchain-managed | MIT | Reading the `docs/*.md` pages unchanged inside Sphinx (no reStructuredText conversion) |
| [Furo](https://github.com/pradyunsg/furo) | toolchain-managed | MIT | The Sphinx HTML theme used by the manual (light/dark, no external assets) |

Sphinx, MyST-Parser and Furo are build-time tools (pinned in `requirements.txt`, installed into the Python venv). They compile the Markdown manual; their output is embedded into the binary as Ada strings. They are not bundled or redistributed with adacovex. The user-facing documentation, and the offline manual served at `/docs`, credit Sphinx as the docs generator and Furo as the theme.

## Site hosting

| Service | Used for |
|---------|----------|
| Read the Docs (https://readthedocs.org) | Hosting the deployed online manual at `https://adacovex.readthedocs.io` |

The online manual is hosted on Read the Docs, a free documentation service. The same Sphinx project also builds into the offline manual bundled with the binary.

## Development and testing tools

| Component | Version | Licence | Used for |
|-----------|---------|---------|----------|
| [Playwright](https://github.com/microsoft/playwright) | test dependency | Apache-2.0 | End-to-end dashboard layout tests (`make e2e`) |

Playwright (https://github.com/microsoft/playwright) is a development dependency of the e2e fixture (`tests/e2e/package.json`, `devDependencies`). It runs automated browser tests of the dashboard. adacovex classifies it as a **test** dependency: the package name `@playwright/test` carries the test label. It is not vendored or redistributed with adacovex releases.

## Performance-engineering tools

These tools profile adacovex during development. adacovex does not
redistribute or depend on any of them; `make bench` and `make perf-bench`
degrade gracefully when they are missing.

| Component | Website / source | Licence | Used for |
|-----------|------------------|---------|----------|
| [perf](https://perfwiki.github.io/main/) (Linux `tools/perf`) | https://www.kernel.org/ (shipped with the [Linux kernel](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/)) | GPL-2.0 | CPU profiling and hardware-counter sampling (`make perf-bench`: cache-miss rates, per-symbol wall clock) |
| [strace](https://strace.io/) | https://github.com/strace/strace | LGPL-2.1-or-later | Syscall tracing of warm/cold runs (`make perf-bench`: the `newfstatat`/`openat`/`getdents64` profiles that drove the walk-skip and stamp-store work) |
| [hyperfine](https://github.com/sharkdp/hyperfine) | https://github.com/sharkdp/hyperfine | Apache-2.0 OR MIT | Statistical command benchmarking (`make bench`: cold/warm pipeline and prove timings with mean +/- sigma) |

The design of the persistent stat-stamp store (1.44.0) was informed by
two projects studied for their incremental-processing techniques; neither
is linked into adacovex:

| Project | Website / source | Licence | What adacovex learned |
|---------|------------------|---------|----------------------|
| [Ada Language Server](https://github.com/AdaCore/ada_language_server) | https://github.com/AdaCore/ada_language_server | GPL-3.0-or-later (with GNAT runtime exception for its runtime) | Persistent indexed file sets and cross-session dirty tracking: re-parse only files whose on-disk state changed (see `docs/contributing/perf.md`, optimisation history 1.44.0) |
| [tree-sitter](https://tree-sitter.github.io/) | https://github.com/tree-sitter/tree-sitter | MIT | Reusable single-buffer parse input (`TSInput`) and incremental re-parse cost modelling |

The size/mtime stamp validation additionally follows the same shape as
git's index dirty tracking, including the racy-clean guard against files
modified within the same second as the record: [git](https://git-scm.com/)
(https://github.com/git/git, GPL-2.0).

## Acknowledgments

- The Ada_CRDT audit target (`../Ada_CRDT`) is used solely as a dogfood target.
- gnatdoc (for `make doc`), gnatformat (for `make fmt`), Alire (`alr`), and Playwright (for `make e2e`) are external tools. They are used during development only.

Full licence texts are available at:
- GPL-3.0-or-later: https://www.gnu.org/licenses/gpl-3.0.html
- GCC Runtime Library Exception: https://www.gnu.org/licenses/gcc-exception-3.1.html
