# Binary size and the bundled manual

`make bench` reports the raw and stripped binary sizes.  The bundled offline
manual is the largest single payload, so its composition is measured through
the generator's own pipeline.  The machine and the harness are on
[Benchmarking adacovex](benchmarks.md).

## Binary size

The debug-symbol-carrying build is ~14.0 MiB at `-O2` on the 1.50.0 tree
(it was ~11.6 MiB at the `-O0` default; optimisation unrolls and inlines,
which costs binary size in the symbol-carrying build).  Stripping (`strip
bin/adacovex`) yields ~5.3 MiB (~62% smaller, and ~17% smaller than
1.46.0's stripped ~6.5 MiB) without affecting behaviour.  That is below
1.47.0's ~5.4 MiB: the 1.50.0 manual encoding (see below) gave back more
than the code added since.  GNAT keeps symbols by default for debugging;
release artifacts are stripped.  `make bench` reports both, so a size
regression is visible in the same command as the timings.

## Bundled offline manual

The offline manual is the largest single payload in the binary, so it was
measured on the 1.50.0 tree through the generator's own pipeline.  The
bundled site holds 226 assets over 191 pages (about 5.49 MB of source);
gzip compresses it to about 1.29 MB, base85 spreads that to about 1.61 MB of
Ada text, and the generated spec is 1.93 MB.  That is 17.3% smaller than the
2.34 MB spec of 1.49.0, for a saving of about 0.41 MB in the stripped
binary (the spec is about 34% of it).  No two assets share their content, so
what remains is dense.

Two changes made the reduction, and both are in the generator.

- **base85 instead of base64.**  The quote-free Z85 alphabet packs 4 bytes
  into 5 characters where base64 needs 5.33, so the payload drops from
  about 1.72 MB to 1.61 MB of characters: about 107 kB, 6.3% of the payload.
  The browser still inflates gzip; only the ASCII wrapper changed, and the
  small decoder in `src/adacovex-docs_template.adb` is plain runtime code
  with no proof surface.
- **One shared sidebar per tree.**  The Furo global toctree is about 8 kB of
  markup, and Furo wrote a full copy into all 191 pages.  Each page now keeps
  a stub and the tree is stored 12 times under `_nav/` (once per branch, at a
  few kB each), which the deferred `_static/adacovex-nav.js` injects.  The
  stored asset is the container's inner markup, so the injected tree replaces
  the stub's children in place and the sidebar keeps its own scrollbar.
  Navigation therefore needs JavaScript, as the manual's search already did.

The figures are rounded, because this page is itself a bundled asset: an
edit here shifts the payload by well under one percent.  The shares below
are the stable part of the measurement, and each is rounded to 0.1%.

| Group | Assets | gzip size | Share |
|-------|--------|-----------|-------|
| Changelogs (history) | 52 | 384 kB | 29.9% |
| API reference (generated) | 75 | 321 kB | 25.0% |
| Contributing pages | 27 | 184 kB | 14.3% |
| Usage pages | 22 | 158 kB | 12.3% |
| Search index | 1 | 97 kB | 7.6% |
| Root, theme, compliance, proof, badges, shared sidebar | 49 | 142 kB | 11.0% |

The generator compresses each asset on its own, because the server sends one
asset per URL with its own `Content-Encoding: gzip` header.  The LZ4
comparison used the same basis: `lz4 -9` gives about 1.63 MB, about 32% more
than gzip, and the Ada runtime has no LZ4 decompressor.  A single shared
stream would compress better (about 0.97 MB for the whole site), but one
stream cannot be cut into independently decodable per-URL bodies.

Two further shrink options were measured and rejected.

- **A stronger compressor (brotli or zstd class, about 15% smaller)**: about
  0.29 MB saved, but the compression runs at build time and the pure Python
  tools must stay stdlib-only (brotli is not in the standard library).  A
  browser can inflate both, but the build dependency breaks the
  zero-dependency tooling rule, and brotli output varies by version, so the
  committed spec would stop being byte-reproducible.
- **Dropping the changelog history (29.9%) or the generated API reference
  (25.0%)**: the only large reductions available, but Sphinx's search index
  covers every page, so a removed page leaves a clickable search result that
  leads nowhere offline.  Stale cross-links would also need rewriting to an
  absolute site URL.

The bundle therefore stays as it is: gzip-max compression, base85 in the Ada
source, one shared sidebar per tree, and a fully working offline manual with
search.

## See also

- [Benchmarking adacovex](benchmarks.md) -- the machine and the harness.
- [Pipeline and prove timings](benchmarks-timings.md) -- the timing table.
- [Server throughput and latency](benchmarks-server.md) -- the served
  dashboard.
