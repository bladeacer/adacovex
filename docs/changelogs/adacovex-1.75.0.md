# adacovex 1.75.0

Date: _2026-11-23_

Version bumped 1.74.0 -> 1.75.0.

## Changes

### C1: `prove` controls the counterexample search

`--counterexamples=on|off` sets whether gnatprove searches for a
counterexample. The search is on by default, because a counterexample names
the input that breaks a check and is the shortest route to a fix. The switch
joins the option string and therefore the proof result-cache identity, so one
caller cannot serve another a proof searched under a different setting. The
`off` value skips the search when a run only needs a pass or fail.

A finding that carries a counterexample is no longer reported as a budget
failure. One gnatprove message block can hold a counterexample and a
`+ provers gave up` line, and the budget reading used to win and hide the
actionable hint. The counterexample now wins, and the block keeps its fix
hint.

### C2: `prove` always sends a proof level

`prove` now sends `--level=N` when the user gives one, and level 4 otherwise.
Without `--level`, gnatprove runs cvc5 alone with no per-check timeout, so an
unflagged run proved less than its own output claimed. A Makefile target that
omitted the flag also never shared a cache entry with `just run-ada-crdt`.

The level sits in the option string, so it is part of the proof
result-cache identity. Every existing proof entry is invalidated once, by
design, because a cached proof at another level is a different proof. Help,
the man page, and the flag-detail page state the default and the reason.

### C3: A proof entry belongs to the resolved project

The proof result cache keys on the resolved absolute target, so a relative and
an absolute `-t` for one project share one entry. `just run-ada-crdt` and the
Ada_CRDT `make prove` target keep separate entries, because the two commands
request different proofs (`-l=4` against gnatprove's legacy default), not
because the cache is per caller. This closes debt entry D11.

### C4: Every help topic reads like one Unix tool

Twelve help frames now share one shape: a `Usage:` block, a one-line summary,
aligned option columns, one `Examples:` command, a `See also:` line naming the
related topics, and an `Exit codes:` block where a code other than 0 or 1
exists (`man --check`, `tldr --check`, `init`, `prove`, `spark-coverage`, and
the `--require-*` gates). An unknown topic names itself, suggests the nearest
topic or flag, and lists the valid topics before the full usage.

`help <topic>` and `<subcommand> --help` stay byte-identical, and a flag before
`--help` still selects the main usage. The CLI e2e suite asserts the frame, the
two new sections, and the absence of a developer-only command in all twelve
frames.

### C5: `--suppress-warnings=all` hides every tagged notice

The reserved `all` set matched no tag, so it suppressed nothing and said
nothing. It now hides every tagged notice. The Ada_CRDT dogfood run found the
gap: the run reported 4 hidden notices, 11 collapsed duplicates, and 6 warning
lines over 2 distinct messages, while `all` had done nothing.

### C6: `docs/stats/` records the measured figures

`just perf-report` measures the release shapes through `tools/bench.py` and
rewrites the generated tables on `docs/stats/`: pipeline and prove timings,
binary size, syscall profile, bundle size and cost, cache behaviour, and test
counts. Each page names its version, host profile, command, and raw result.
`just release` runs the report with `--release`, so a release commit carries
fresh figures.

The tool measured the wrong profile until this release: `alr build --release`
never sets `ADACOVEX_PROFILE`, so the report timed a development build while
the host profile printed Alire's release settings. It now builds through
`tools/build.py --release` and labels the profile from the flag it passed.

### C7: One phase column, re-measured every version

`docs/contributing/perf/prove-timing.md` folds 1.63.0-1.75.0 into one phase,
represented by 1.75.0. From this version the open column is re-measured at
each version, so its representative is the latest measured version, and a row
the session did not take reads "not measured" instead of borrowing an older
number. The page keeps the three most recent closed phases plus the open one.

The 1.75.0 reading is 5.93 s pipeline warm, 6.02 s pipeline cold, and 6.01 s
prove warm on a release build at load 18.5; the prove-cold row is not
measured, because three cold runs did not finish inside the session budget.
The syscall reading is 282 020 `newfstatat` calls against 7 924 at 1.63.0, so
the warm stat count regressed by 35 times. Debt entry D16 owns the fix, and
AGENTS.md now requires a warm-run perf check on every change.

### C8: Platform detection says what it probes

`Adacovex.Paths.Detect_Platform` describes its two facts plainly. Windows needs
no probe, because the separator convention is a compile-time fact. macOS has
no such fact, so the code asks whether `/System/Library/CoreServices` exists;
that directory exists only on macOS, so on every other host the question
answers "no" by design and the host is treated as XDG. The API reference and
the perf page carry the same wording, so a macOS path in a Linux syscall trace
reads as the probe it is.

## Test Suite

Native suite: 2494/2494 passing across 30 categories, 0 skips. The CLI
configuration category carries the twelve help-frame snapshots and the unknown
topic suggestions, and the proof runner category carries the default-level and
counterexample switch cases.

`just cli-e2e` passes 213 checks, including the frame assertions for every
help topic and the rejection paths for `--counterexamples`.
`just prove-e2e` passes 274 checks over 20 committed fixture projects.

## Proof Results

The product changes touch the prove runner, the diagnostics hint table, the
CLI parser, and the help renderer. No `SPARK_Mode (Off)` pragma was added
outside the two exempted packages.

The tree proves at the default budget (gnatprove 16.1.0: 1060 VCs, 0 unproved,
0 justified). Self-assessment: Gold, 100% docstrings, DAL-C Achieved, ASIL B
and Class A Achieved under `--standard=all`.

## Traceability

HLR-PROVE: `prove` always sends a proof level, the counterexample search is a
cache-identity option, a counterexample outranks a budget message, and a proof
entry belongs to the resolved project location.

HLR-CLI: every help topic renders one frame with an example, a see-also line,
and an exit-code block where a code other than 0 or 1 exists; an unknown topic
suggests the nearest match.

HLR-PERF: `docs/stats/` carries the measured figures for the current version,
the prove-timing page keeps one column per phase, and AGENTS.md makes a
warm-run perf check part of every change.

No product HLR changed for the help wording, the documentation phrasing, or
the stats work; those changes keep the documented surface and the gates in
step.
