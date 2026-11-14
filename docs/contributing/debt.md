# Technical debt register

This page records the technical debt that the v1.69.0-v1.75.0 releases
surfaced. Each entry states the defect, the condition that closes it, and
its state. An entry leaves this page only when the plan that owns it closes
and the changelog records the outcome.

The register is the source of truth for **open** debt. A release that adds
debt adds a row in the same change, so a later reader sees the cost before
the next release is planned. Item 8c closes or explicitly accepts every row
in v1.72.0.

## State

- **Open** -- the defect is present in the tree.
- **Closed** -- the defect is removed and a gate or test holds it closed.
- **Accepted** -- the defect stays by decision, with the reason stated.

## Standing constraints

Two rules are not debt and never expire. They are repeated here because a
new entry must not propose work that breaks them.

- `pragma SPARK_Mode (Off)` stays at exactly two packages:
  `Types.Implementation` and `Complexity`. Both instantiate the non-formal
  `Ada.Containers` vectors that gnatprove rejects in `SPARK_Mode On` code.
  `just spark-off-check` fails on a third package.
- Every new executable statement carries contracts, so `just prove` reaches
  0 unproved and 0 justified VCs. A change that cannot be proved narrows
  instead of widening the Off set.

## Register

| ID | Area | Defect | Done when | State |
|----|------|--------|-----------|-------|
| D1 | Diagnostics | The same unproved finding could print more than once, and the text, JSON, and annotation paths each grouped findings their own way. | One deduplicated finding list feeds every renderer, and `just prove-e2e` asserts the shape. | Closed (v1.69.0) |
| D2 | Manifest parsing | The system-tool scan descended into generated build trees, so a Meson or CMake log that recorded `PATH` registered tools the project never used. A C project listed `cargo` and `go`. | A generated tree contributes no tool reference, by conventional name and by build-system state; a C-project fixture proves it. | Closed (v1.70.0) |
| D3 | Manifest parsing | A whole-word match in a build file still registers a tool that a comment or a variable name mentions, never a command that the file runs. | A reference counts only in command position, or the page states the wider rule as accepted. | Open (v1.71.0, item 6b/8b) |
| D4 | Manifest parsing | The scan and the cache key kept two copies of the directory-exclusion list, so the two could disagree about which files the tool set covers. | One predicate (`Skip_Scan_Dir`) owns the decision for the scan and for `Source_Tree_Hash`. | Closed (v1.70.0) |
| D5 | Bounded strings | Fixed-width copies of artefact names in `Adacovex.Prove`, and `Max_*` constants without one shared bound, can overflow or silently truncate. | Every bounded copy has a checked bound, the overflow contract names each `Max_*`, and a test covers the limit. | Open (v1.71.0, item 8b) |
| D6 | Time | Timestamp formatting had more than one path, so a surface could disagree with another about the zone. | `Adacovex.Timezones` is the only formatter, and every surface honours `--tz`. | Closed (v1.68.0) |
| D7 | Help | The main usage and the contextual topics rendered different frames, so one tool read as several. | Every topic renders the `prove` frame, and `help <topic>` is byte-identical to `<subcommand> --help`. | Open (v1.75.0, item 19) |
| D8 | Cache | A warm cache hit printed less than the cold run it served, so the two told different stories. | The replay is cached as plain text and reprinted, and warm and cold output agree. | Closed (v1.69.0) |
| D9 | Colour | Escape codes could reach the cache, and one report path built its own codes. | Every coloured surface goes through `Adacovex.Ansi`, and the cache stores plain text only. | Closed (v1.69.0) |
| D10 | CI output | Annotations were emitted outside GitHub Actions, where no reader consumes them. | An annotation prints only when `GITHUB_ACTIONS` is set, and a local run keeps the text block. | Closed (v1.69.0) |
| D11 | Cache identity | A proof-cache key folds the caller's target string into the digest, so two working directories produce two keys for one project. | The key uses the resolved absolute path, and per-unit entries miss only a changed unit and its dependents. | Open (v1.74.0, item 18) |
| D12 | Pipeline | The warm `just check` took 453 s on 2026-11-14, against a 60 s budget, and the per-gate table names the costly gates. | A warm run finishes under a minute with no gate weakened and no check dropped, and the table records it. | Open (v1.71.0-v1.72.0, items 15b-15c) |
| D13 | Docstrings | A few packages changed by recent items still carry a thin or missing docstring. | `just doc` emits no empty description, parameter, or return, and docstring coverage stays 100%. | Open (v1.72.0, item 9) |
| D14 | SBOM accuracy | The scanner recognises only a curated tool list, so a project's real build tool that is absent from that list (for example `meson`) never appears. | The list covers the build tools of the fixture projects, or the page states the closed list as accepted. | Open (v1.71.0, item 6b) |
