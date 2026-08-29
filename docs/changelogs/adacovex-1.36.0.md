# adacovex 1.36.0

Date: _2026-08-29_

Version bumped 1.35.0 -> 1.36.0.

## Fixes

### H1: Bundled dashboard JavaScript survives minification

The dashboard builder minified the authored JavaScript with a comment
stripper that did not understand regular-expression literals. A slash pair
inside a regular expression, for example the `//` in `/^https?:\/\//i`, was
read as a line comment. The stripper then deleted the rest of that line.

The deleted text was the dependency link check in `details.js`:

```
if (d.website && /^https?:\/\//i.test(String(d.website))) {
```

The minifier rewrote it to `if (d.website && /^https?:\/`, an unterminated
statement that broke the dependency detail panel. The fault lived in the
generated `src/adacovex-dashboard_template.ads`, so every built binary
carried the broken page. Releases on GitHub and the Alire crate were both
affected, because the dashboard is bundled into the binary as one string
constant.

`tools/gen-dashboard.py` now scans a regular expression literal to its
closing slash before it strips comments. The previous significant token
decides whether a slash opens a regular expression or a division, so
embedded `//` and `/*` text stays intact. The vendored graph libraries are
still inlined byte for byte and are not minified. The regenerated template
passes `tools/gen-dashboard.py --check` and every inlined script passes a
JavaScript syntax check.

### H2: Dashboard proof guidance uses the adacovex CLI

The Proof tab told users to run `make prove` after each change. The dashboard
and command help are user-facing output; developer-only make targets do not
belong there. The text now reads `adacovex prove`, matching the actual
user-facing subcommand.

### H3: Dashboard credits show actual third-party versions

The Credits tab listed Playwright as `test / Apache-2.0` and Charts.css as
`inspiration / MIT`. Both now carry their actual vendored versions: Playwright
`1.62.1 / Apache-2.0` and Charts.css `1.2.0 / MIT` (credited for inspiration,
as the dashboard charts are hand-rolled CSS/SVG).

### H4: Fast hover tooltips for dependency scope and tree

The dependency tree and the nomnoml diagram used the native SVG `<title>`
tooltip, which browsers delay by one to two seconds. A custom `DepTooltip`
now appears immediately on `mouseover` and follows the cursor. The polar
scope ring already used a native `<title>`; the same fast tooltip is wired
to its segments.

### H5: System-tool discovery skips source files

`Discover_System_Dev_Deps` scanned every file whose extension looked like code
(`ads`, `adb`, `c`, `cpp`, `rs`, `go`, `js`, `ts`, ...). That produced false
positives: Ada source contains the word `ada`, Rust source contains `go`, and
C source contains `make`. The scanner now reads only build-facing files
(Makefile variants, shell scripts, GNAT project files, CI workflows, and
build manifests). Prose and source text are never scanned for tool names.

### H6: AGENTS.md expanded

The `make check` target description now explains that it is the single
everything-check entry point and that it resolves `gnatprove` automatically.
A new bullet records the SPARK discipline policy: new code must be fully
SPARK-proven, and `SPARK_Mode (Off)` is permitted only in the two
irreducible container packages (`Types.Implementation` and `Complexity`).

## Test Suite

The native Ada suite is unchanged at 1157 tests. The renderer test that
asserted the Playwright credit text was updated to expect the actual version
string.

## Proof Results

Platinum, 0 unproved, 0 justified. The dashboard and manifest scanner changes
are build-time or I/O-bound code that adds no analysed Ada, so the VC total
stays at the Platinum bar.

## Traceability

- `HLR-DASH` / `HLR-ARCH` -- H1 bundled dashboard JavaScript minification
  fix and the `tools/gen-dashboard.py` regular-expression aware minifier.
- `HLR-DASH` -- H2 dashboard proof guidance text, H3 credits versions, H4
  fast hover tooltips.
- `HLR-SBOM` -- H5 system-tool discovery false-positive fix.
- `HLR-DOC` -- H6 AGENTS.md expansion.

See `docs/dashboard.md` and `docs/architecture.md`.
