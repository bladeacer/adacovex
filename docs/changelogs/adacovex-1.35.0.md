# adacovex 1.35.0

Date: _2026-08-29_

Version bumped 1.34.0 -> 1.35.0.

## Changes

### C1: Configurable dashboard worker count

`--serve-workers=N` sets the HTTP server task-pool size for `--serve`
(default 4).  Raise it to serve more concurrent dashboard requests; lower it
to use less memory.  The value is rejected unless `--serve` is also given, so
a silent no-op is impossible.  The bound is `Positive`; the pool still caps at
its internal maximum.

### C2: CSS 4px spacing gate and build-time minification

`tools/csslint.py` enforces the dashboard spacing convention: every
`margin`, `padding` and `gap` pixel length must be a multiple of 4px.  It runs
as a cheap static gate inside `make build` and `make check`.  The authored
CSS and JavaScript are minified at build time by `tools/gen-dashboard.py`
(comments stripped, whitespace collapsed) before they are bundled into the
served dashboard.  The vendored graph libraries are already minified and are
inlined byte-for-byte.

### C3: Four-sentence paragraph gate for hand-written docs

`tools/check-docs.py` (wired as `make docs-check`) fails when any paragraph
in the user documentation, README, or human changelogs exceeds four
sentences.  It also rejects em dashes and Latin abbreviations (`i.e.`,
`e.g.`, `etc.`) to keep the prose under Simplified Technical English.
`tools/para-split.py` rewraps over-long paragraphs to comply.  The generated
`docs/api-docs` pages are excluded; their source docstrings carry the same
rule.

### C4: Timezone support with OS-aware default

`--tz` / `--timezone` override the display zone for `status` reports.
Accepted forms are an IANA name (`Asia/Singapore`) or a fixed
`UTC`/`GMT` offset (`UTC+8`, `GMT+8`, `UTC+08`, `GMT+08`, `UTC+08:30`).  With
no override, adacovex now honours the operating system's wall-clock zone
through `Ada.Calendar.Time_Zones.UTC_Time_Offset` (which reads the `TZ`
variable and the system timezone) and shows it as `UTC+/-HH:MM`.  A named
zone resolves from a built-in table of common IANA names; a zone that may
observe daylight saving time, or one the table lacks, is probed against the
platform tzdata (`zdump` + `date +%z`) for the DST-correct current offset,
with the table as the fallback when the probe is unavailable.  `status`,
`status --export` and `status --metrics` report the resolved zone, the
current date and time, and the count of dated release changelogs under the
target.

### C5: Complexity check extended to non-Ada source

`complexity` now walks the whole target and scores many languages (C/C++,
C#, Go, Java, JavaScript, TypeScript, Python, Ruby, PHP, Rust, Shell,
Kotlin, and the YAML/JSON/TOML/XML/Markdown/Markdown families) alongside
Ada.  `--excludes=EXT,EXT` skips listed file extensions and is rejected
unless the `complexity` subcommand is given, so it can never run on its own.
Per-subprogram analysis stays Ada-specific; other languages contribute
file-level lines of code and decision counts.

### C6: ANSI colour on the terminal report

`Adacovex.Ansi` colours the terminal output (red for failures, green for
passes, bold for headings).  Colour is disabled automatically inside CI
(the `CI` variable), under `NO_COLOR`, or with `TERM=dumb`, so CI logs stay
plain and machine-readable.  The complexity report and the main header use
it.

### C7: AGENTS.md keeps documentation current

A new note in `AGENTS.md` states that every change must update the relevant
user documentation, the Ada docstrings that feed `docs/api-docs`, and the
changelog, and must re-run the sync gates (`docs-check`,
`action-parity-check`, `agents-tree`, `doc-links`, `link-check`).  This makes
the expectation explicit that LLM-assisted edits keep docs in step with code.

## Fixes

### H1: Status default zone now follows the operating system

The previous timezone default ignored the system zone and fell back to UTC
unless a `TZ` variable or a Debian `/etc/timezone` file named a zone.
`Timezones.Default` now resolves the offset from
`Ada.Calendar.Time_Zones.UTC_Time_Offset`, so the reported time matches the
operator's configured wall clock.  The date/time rendering also compensates
for GNAT's local-time calendar accessors, so the displayed wall clock is
correct in every zone (including negative offsets, which the original
implementation rejected outright).

### H2: Timezone and ANSI packages stay SPARK-clean

`Adacovex.Timezones` dropped its `Ada.Text_IO` read of `/etc/timezone` and
`Adacovex.Ansi` scoped its environment-variable reads, so both remain
`SPARK_Mode On` with only the env-var Global-contract warning suppressed
(matching `CPUs.Get_Temp_Directory`).  `make prove` therefore keeps its
Platinum, zero-unproved status.

## Test Suite

The native suite grows from 1066 to 1157 tests (16 categories).  The CLI
config suite gains 16 flag-gating assertions (`--excludes` requires
`complexity`, `--serve-workers` requires `--serve` and a positive value,
`--tz`/`--timezone` validates its value and stores it).

A new Timezone + ANSI suite (63 assertions) covers timezone parsing and
formatting (named IANA zones, `UTC`/`GMT` offsets, malformed values,
`Now_Text`, the OS default, and the platform probe) and ANSI colour
coverage (`Colour_Allowed` under CI / NO_COLOR / TERM=dumb, plus the SGR
wrappers).

A new Complexity check suite (12 assertions) covers the multi-language
scan and `--excludes` filtering.  The totals are resynced via
`make test-count`.

## Proof Results

Platinum, 0 unproved, 0 justified.  The timezone and ANSI refactors keep
every analysed unit `SPARK_Mode On` (the only non-SPARK constructs are the
env-var reads, whose Global-contract absence is suppressed), so the VC total
is resynced via `make proof-status` and stays at the Platinum bar.
Invocation: `adacovex prove` (`--steps=10000`, gnatprove 16.1.0).

## Traceability

- `HLR-CLI` -- C1 `--serve-workers`, C5 `complexity --excludes`, C6 ANSI
  colour, C7 AGENTS.md note.
- `HLR-TZ` -- C4 timezone support and status detail, H1 OS-default fix.
- `HLR-ANSI` -- C6 terminal colour.
- `HLR-COMPLEXITY` -- C5 multi-language complexity and excludes.
- `HLR-DASH` / `HLR-ARCH` -- C2 CSS 4px gate and build-time minification.

See `docs/cli-reference.md`, `docs/dashboard.md`, and `docs/platforms.md`.
