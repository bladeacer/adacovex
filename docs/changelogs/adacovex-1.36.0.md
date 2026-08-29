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

## Test Suite

The tools suite gains 4 assertions (now 42 in `tools/tests.py`): the
minifier keeps a `//` inside a regular expression, keeps a character class
that contains quote marks, still drops a real `//` line comment, and the
assembled page leaves no placeholder behind. The native Ada suite is
unchanged at 1157 tests.

## Proof Results

Platinum, 0 unproved, 0 justified. The dashboard builder is a build-time
Python tool and adds no analysed Ada, so the VC total stays at the
Platinum bar and `make proof-status` is unchanged.

## Traceability

- `HLR-DASH` / `HLR-ARCH` -- H1 bundled dashboard JavaScript minification
  fix and the `tools/gen-dashboard.py` regular-expression aware minifier.

See `docs/dashboard.md` and `docs/architecture.md`.
