# The bundled offline manual

The `--serve` server serves the **bundled offline manual** at `/docs` (both
spellings, with and without the trailing slash, reach the same page). This
page covers what is bundled, how it is compressed and encoded, and how its
navigation works. Using the served dashboard and its endpoint table is on
[Web dashboard](dashboard.md).

## What gets bundled

The manual is the same Markdown source that powers the Read the Docs site.
Every page, stylesheet, script, and badge is bundled, and the search box works
exactly as it does online because Sphinx's own search machinery travels with
it. The PNG screenshots are dropped and show as notes. The header
**Documentation (offline manual)** link and the API playground's `/docs`
endpoint both open the manual.

> **For contributors:** `docs/` is a Sphinx project (`docs/conf.py` + MyST),
and `tools/gen-docs.py` runs `sphinx-build` and writes the site into
`src/adacovex-docs_template.ads` as a path-keyed lookup table. Each constant
stays small, because one multi-megabyte blob would overflow the [gnatprove](../glossary/ste100/identifiers.md#technical-name-gnatprove)
frontend stack, so the [search index](../glossary/ste100/web-terms.md#technical-name-search-index) is split into chunks the server streams.
The `_sources/` page-source links are stripped, and the bundled HTML stays
pure ASCII: non-ASCII glyphs are encoded as UTF-8 byte values in the Ada
source.

## Reading the manual and the dashboard

The manual and the dashboard share one server, so the two are one click
apart. When you read this manual inside a running `--serve` server, open
`/` (the server root) to see the live metrics for the target. The online
manual carries no live data: run adacovex on your project first, then open
the dashboard to see its metrics.

## Compression and encoding

The manual is served **pre-compressed**: every asset is compressed when the
binary is built and sent with `Content-Encoding: gzip`, so the browser inflates
it and the binary carries no inflate routine. A reader sees no difference: the
pages arrive as normal HTML.

> **For contributors:** `tools/gen-docs.py` gzip-compresses each asset and
[base85](../glossary/ste100/identifiers.md#technical-name-base85)-encodes it into the generated spec. base85 (the quote-free Z85
alphabet) packs 4 bytes into 5 characters against base64's 5.33, which took
the payload from 1.72 MB to 1.61 MB. LZ4 was measured again and rejected: on
the self tree it produced 1.63 MB against gzip's 1.29 MB, about 32% larger.
The Ada runtime has no LZ4 decompressor either, so gzip also needs no decoder
in the binary. The [result cache](../glossary/ste100/tooling-terms.md#technical-name-result-cache) stays uncompressed, because its per-unit
blobs are too small for compression to pay.

## Sidebar navigation

Each page keeps only a stub for the Furo sidebar; the toctree itself is
stored once per branch under `_nav/` and a small deferred script fills the
stub in. That removed 191 copies of the same 8 kB markup.

The stored tree is the sidebar container's inner markup, so the injected
tree replaces the stub's children in place. The single
`.sidebar-container` therefore stays Furo's flex-stretched drawer column:
the sidebar sticks while the page scrolls, and `.sidebar-scroll` keeps its
own scrollbar. Navigation needs JavaScript, exactly as the search box
already did.

The injector also scrolls the open page's entry into the drawer. The tree
is taller than the drawer now that the manual is a page per section, so the
entry a reader clicks sits below the drawer's fold on the page it lands on,
and Furo reveals its right-hand table of contents only. The drawer moves
alone: the page itself stays at its own top, and an entry that is already
in view leaves the drawer where it is.

That reveal is the manual's behaviour on both surfaces, online and offline.
The online manual (Read the Docs) has the inline Furo toctree, so
`docs/_static/sidebar-reveal.js` moves the drawer there, and the bundled
manual ships the same file, so the two never drift apart. On an offline
page the tree is injected after that file has run, so it finds no tree and
the injector owns the drawer. Both use the same rule: the drawer moves, the
page does not.

Every page a reader can reach from the sidebar has an entry to reveal, so
each `{toctree}` line sits at the left margin. An indented line becomes a
child toctree of the entry above it, and `:maxdepth: 1` then hides the whole
subtree from the sidebar.

The full composition of the bundled site, and the other size options
measured, are on [Benchmarking adacovex -- bundled offline
manual](../contributing/perf/benchmarks-binary-size.md#bundled-offline-manual).
The current size and the cost of each rebuild shape are on [Docs bundle size
and cost](../stats/bundle.md).

## Rebuilding the manual

The build records one content-addressed stamp at
`docs/_build/.adacovex-docs-sources`. It holds the bundle fingerprint, every
output path, and the digest of every input, so it is the manifest the next
build reads.

The rebuild decision tree is short:

1. The committed spec carries the bundle fingerprint of the sources it was
   built from. When that fingerprint matches the current sources, Sphinx does
   not run and the committed spec is kept (the cold-tree shape).
2. A changed source rebuilds incrementally, and the result is verified
   against the page set. A stale doctree cannot survive, because the changed
   pages' mtimes are refreshed before Sphinx reads them.
3. A page added or removed, or a `{toctree}` edit, rewrites every page, so no
   sidebar keeps a stale entry. The removed page's outputs are swept.
4. A verification failure falls back to a clean rebuild. `--fresh` forces one
   by hand.
5. With no Sphinx [toolchain](../glossary/ste100/tooling-terms.md#technical-name-toolchain), the committed spec is kept and the build prints
   the reason. A missing build directory never produces a partial bundle.

The encoder caches each body's gzip+base85 result by SHA-256 under
`obj/adacovex-docs-encode/`, so a docs edit re-encodes only the pages it
touched, and the uncached bodies encode in parallel across the cores. Both
are pure speed-ups: the emitted spec is byte-identical either way.

## See also

- [Web dashboard](dashboard.md) -- using the served dashboard.
- [The dashboard document and its dependency
  views](dashboard-html.md) -- the tabs and the dependency views.
- [The dashboard JSON API, playground, and themes](dashboard-api.md) --
  the JSON API and the themes.
- [Docs bundle size and cost](../stats/bundle.md) -- the measured size and
  rebuild timings.
