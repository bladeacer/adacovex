# The bundled offline manual

The `--serve` server serves the **bundled offline manual** at `/docs` (both
spellings, with and without the trailing slash, reach the same page). This
page covers what is bundled, how it is compressed and encoded, and how its
navigation works. Using the served dashboard and its endpoint table is on
[Web dashboard](dashboard.md).

## What gets bundled

The manual is the same Markdown source that powers the Read the Docs site
(`docs/`, a Sphinx project with `docs/conf.py` + MyST); at build
time `tools/gen-docs.py` runs `sphinx-build` and bundles the resulting site
into the binary (`src/adacovex-docs_template.ads`) as a lookup table plus
static string constants: every page, stylesheet, script, and badge, keyed
by site-relative path (each constant stays small -- a single multi-megabyte
blob would overflow the gnatprove frontend stack, so the search index is
split into chunks and the server streams them).

Sphinx's own search machinery (searchindex.js, searchtools.js, the
stemmers) is bundled and the search box works exactly as on the online
site. The PNG screenshots are dropped (they show as notes), the
`_sources/` page-source links are stripped, and the bundled HTML stays pure
ASCII (non-ASCII glyphs are encoded as UTF-8 byte values in the Ada
source). The header **Documentation (offline manual)** link and the API
playground's `/docs` endpoint both open it.

## Reading the manual and the dashboard

The manual and the dashboard share one server, so the two are one click
apart. When you read this manual inside a running `--serve` server, open
`/` (the server root) to see the live metrics for the target. The online
manual carries no live data: run adacovex on your project first, then open
the dashboard to see its metrics.

## Compression and encoding

The manual is served **pre-compressed**: every asset is gzip-compressed at
build time in `tools/gen-docs.py`, base85-encoded into the generated spec,
and sent with `Content-Encoding: gzip`, so the browser inflates it and the
binary carries no inflate routine. base85 (the quote-free Z85 alphabet)
replaced base64 in 1.50.0: it packs 4 bytes into 5 characters instead of
5.33, which took the encoded payload from 1.72 MB to 1.61 MB.

LZ4 was measured again and rejected. On the self tree the bundled site is
about 5.49 MB of source; gzip compresses it to about 1.29 MB (ratio 0.23)
and `lz4 -9` to about 1.63 MB (ratio 0.31). LZ4 is therefore about 32%
larger than gzip here, which would add about 0.5 MB to the embedded blob.

Two further points settle it: the Ada runtime has no LZ4 decompressor (a
roll-your-own decoder would add code and SPARK proof surface), and gzip
needs no decoder at all in the binary because the browser inflates the
stream. gzip stays.

The result cache also stays uncompressed -- its blobs are tiny per-unit
records where compression costs more than it saves.

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

The full composition of the bundled site, and the other size options
measured, are on [Benchmarking adacovex -- bundled offline
manual](../contributing/perf/benchmarks-binary-size.md#bundled-offline-manual).

## See also

- [Web dashboard](dashboard.md) -- using the served dashboard.
- [The dashboard document and its dependency
  views](dashboard-html.md) -- the tabs and the dependency views.
- [The dashboard JSON API, playground, and themes](dashboard-api.md) --
  the JSON API and the themes.
