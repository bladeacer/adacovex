# Architecture: outputs and formats

This page covers the output formats, the build and documentation gates, and the reading contract.  The dependency and proof-level design is on [Architecture Decisions](architecture.md); the IR, DAL, scanning, and patch system are on [Architecture: verification and proof patches](architecture-verification.md); the pipeline order, the platforms, and the delivery channels are on [Architecture: pipeline, platforms, and delivery](architecture-pipeline.md).

## Output Formats

adacovex supports multiple output formats:

- **ANSI terminal report**: Colour-coded summary for interactive use.
  Colour is suppressed under CI, `NO_COLOR`, or `TERM=dumb`, so CI logs
  stay plain (see `Adacovex.Ansi` and its pure decision function
  `Colour_Allowed`)
- **SVG badges**: `spark.svg`, `tests.svg`, `docs.svg`, plus `do178c.svg` /
  `iso26262.svg` / `iec62304.svg` compliance badges (`--standard=all` emits all
  three) for CI badges
- **Markdown reports**: `VERIFICATION.md` and `TRACE.md` for compliance documentation
 - **HTML dashboard**: Interactive web dashboard with JSON API (`--serve`).
   It is standard-aware (defaults to all standards like `sbom`) with light/dark
   theme support (toggle button, respects `prefers-color-scheme`). The static
   page shell (CSS, header, theme script) is a real HTML file,
   `resources/dashboard.html`, bundled into the binary at build time.
   `tools/gen-dashboard.py` assembles the authored CSS (`resources/css/dashboard.css`),
   the authored JS (`resources/js/*.js`), and the vendored JavaScript
   libraries at the `resources/` root (`graphre.js`, `nomnoml.js`,
   `flexsearch.js`, `yace.js`) into a single minified page shell. The layout
   separates dependency JavaScript (`resources/` root) from authored dashboard
   JavaScript (`resources/js/`), which is also how the SBOM asset scanner
   tells vendored components from the project's own modules.

   The tool regenerates `src/adacovex-dashboard_template.ads` (a String
   constant, committed and byte-identical when unchanged).
   
   The Ada compiler includes that constant in the final binary. Every released
   binary - whether a GitHub release artifact or an Alire crate binary - carries
   the complete dashboard with no external file dependencies.
   
   At runtime, `Adacovex.Renderers.HTML.Render_Dashboard_Internal` only builds
   the dynamic card markup and injects it at the `__CARDS__` placeholder, filling
   the `__THEME__` initial-theme marker. The result is a single self-contained
   HTML document: no CDN, no network requests, works offline.
- **SBOM**: CycloneDX 1.5, SPDX 2.3, or Markdown format with proof, standard,
  and DAL/level properties

## Testing

adacovex uses a native zero-dependency test framework (`Adacovex.Test_Support`) with 1607 tests across 25 categories. No external test framework (AUnit, and more) is required. Test results are written to `docs/test_result.md` in a parseable Markdown table format.

## Complexity check

The `complexity` subcommand walks the whole target and scores many languages
(C, C++, C#, Go, Java, JavaScript, TypeScript, Python, Ruby, PHP, Rust,
Shell, Kotlin, and the YAML/JSON/TOML/XML/Markdown/reStructuredText
families) alongside Ada.  Per-subprogram analysis stays Ada-specific; the
other languages contribute file-level lines of code and decision counts.
`--excludes=EXT,EXT` skips listed file extensions and is rejected unless the
`complexity` subcommand is given, so it can never run on its own.  `make
complexity-check` gates the tree through the same thresholds.

## Timezone resolution

adacovex honours the operating system's timezone by default.  The resolved
offset comes from `Ada.Calendar.Time_Zones.UTC_Time_Offset`, the standard
Ada runtime, which reads the `TZ` variable and the system timezone through
the C library, so the default is always the operator's wall clock
(DST-aware).  `status` reports the effective timezone, the current date and
time in it, and how many dated release changelogs the target carries under
`docs/changelogs`.

`--tz` / `--timezone` override the display zone for one invocation.  The
value is either a well-known IANA name (for example `Asia/Singapore`) or a
fixed `UTC`/`GMT` offset (`UTC+8`, `GMT+8`, `UTC+08`, `GMT+08`,
`UTC+08:30`).  adacovex ships no timezone database, so a named zone
resolves from a built-in table of common IANA names and their standard-time
offsets.  A zone that may observe daylight saving time (marked in the
table), or one the table lacks, is probed against the platform tzdata
(`zdump` validates the name, `date +%z` reads the current offset, both
through one shell command) for the DST-correct offset; the table offset is
the fallback when the probe is unavailable.  The date/time rendering
compensates for GNAT's local-time calendar accessors, so the displayed wall
clock is correct in every zone.  `HLR-TZ` covers this behaviour.

## Build and documentation gates

Two cheap Python gates keep the dashboard and the hand-written docs in
step with the code, and both run inside `make check`:

- `tools/csslint.py` (`make csslint-check`) enforces the dashboard spacing
  convention: every `margin`, `padding`, and `gap` pixel length is a
  multiple of 4px.  It also runs inside `make build`.
- `tools/check-docs.py` (`make docs-check`) fails when any paragraph in the
  user docs, README, or human changelogs exceeds four sentences, and it
  rejects em dashes and Latin abbreviations (`i.e.`, `e.g.`, `etc.`).
  `tools/para-split.py` rewraps over-long paragraphs to comply.  Pages are
  also kept under 250 lines; a reference dictionary or historical record can
  opt out of the line cap (never the paragraph rule) with a
  `no-covex-docs-loc` HTML comment near the top of the file.

The generated `docs/api-docs` pages are excluded from the paragraph rule;
its source docstrings carry the same rule.

## Read Only

adacovex itself is read-only. It merely scans your codebase for target docstrings and proofs.

It does not make edits in place or on your behalf.

## Flexible

adacovex lets you write proofs and decide where proofs are pointless (for
example code that has to involve manual memory management). You just have to
justify your rationale. The tool is not rigid. It does not expect 100% proving
for all use cases.

You write the proofs yourself, so there is no magic or hidden abstractions here.

The pipeline execution order, the supported platforms, the delivery channels,
the build-time linker output, and the LLVM compiler swap are on [Architecture:
pipeline, platforms, and delivery](architecture-pipeline.md).
