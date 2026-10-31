# Tooling Ergonomics Plan

## Goal
Improve day-to-day developer ergonomics around documentation accuracy, prove output readability, CI feedback, configuration, exclusion semantics, and live-reload behavior. The work spans diagnostics, configuration, and runtime behavior and must land across three minor semver bumps so each release stays testable and shippable.

## Scope boundaries
- Only the features listed in the user request are in scope.
- Each feature is mapped to one of three releases.
- Documentation parity, flag wiring, and test parity are treated as required parts of each feature, not optional polish.
- No implementation code is written in this plan pass.

## Out of scope for this plan
- New assessment features unrelated to ergonomics.
- Breaking CLI changes that would invalidate existing ci.yml / action.yml usage without migration.
- Any runtime dependency additions that would violate the project's zero-library-dependency stance.

## Cross-cutting constraints
- Keep CLI flag surface consistent with docs, shell completion, the man page, and the GitHub Action. The project already has parity checks for this, so new flags must be wired through the same channels.
- New behavior that affects assessment output, exit codes, or serve behavior must be discoverable:
  - documented in the CLI reference and related usage pages
  - reflected in the generated man page and tldr page where relevant
  - covered by tests
- Diagnostics work should respect the project's existing quiet-by-default prove behavior and the difference between local and CI output. Do not silently flip defaults in a way that makes CI noisier or local output unreadable.
- Configuration work must respect the project's current global config file convention and path resolution, if one exists, rather than inventing an entirely new layout without checking the current one first.
- Whenever config-file defaults, precedence, sample values, or supported-value comments change, update the docs and the sample `adacovex.toml` together so users, docs, and the runtime all tell the same story.
- All new code in this branch must land as fully `SPARK_Mode On` Ada/SPARK with contracts covering each statement. New units must reach **0 unproved, 0 justified** under `just prove`, and no new `pragma SPARK_Mode (Off)` may be introduced except in the two already-exempt packages (`Types.Implementation` and `Complexity`). The work must not regress proof coverage or create avoidable future proof debt.

## Audit findings to address before implementation

### Documentation parity for `tldr` and `man`
- `man` and `tldr` are real subcommands and are referenced across the CLI reference, the dash completion list, the usage pages, and the generated man page.
- The current tldr cheat sheet lists `spark-coverage` as an example command alongside the main assessment, `prove`, `--serve`, `man`, and `sbom`, but it does not necessarily enumerate every subcommand or recent flag in equal depth.
- The CLI reference and usage pages are the better source of truth for the full command surface, and any tldr page update should stay concise while still matching the supported invocation shapes.
- Before adding a docs-integrity check, the concrete discrepancies should be enumerated:
  - which subcommands/flags the tldr page currently shows
  - which ones the CLI reference documents
  - which ones `adacovex --help` and `adacovex completion` expose
  - whether the man page and tldr page agree with each other and with `--help`

### Proof output verbosity and diagnostics
- Prove output already has a quiet-by-default path and a `--verbose` path, with suppressions for benign info noise.
- The requested work is partly a formatting/diagnostics improvement and partly a discoverability question:
  - do we want a single `prove` output mode with better in-line diagnostics, or
  - do we want a concise mode and a verbose/developer mode, or
  - do we want rich diagnostics only in CI while keeping local output compact
- This decision affects flag design, so it should be resolved during implementation planning rather than assumed.

### `--fail-on` threshold model
- The project already has `--require-*` style gates for several assessment dimensions.
- A `--fail-on` model should be designed as a clear threshold/exit-code mechanism, not as a duplicate of existing gates unless there is a deliberate reason to generalize them.
- The design needs to answer:
  - what dimensions are configurable
  - whether thresholds are percentages, counts, or both
  - whether the new flag composes with existing gates or replaces some of their roles

### Configuration file
- There is already a global configuration file concept in the codebase, so a new per-project / config-file feature should be checked against the current config file shape before inventing a new layout.
- The configuration file must be named `adacovex.toml`.
- The config file is a way to override default CLI flag values, not just to add extra settings. Users set the defaults they prefer there so they do not have to retype brittle one-liners on every invocation.
- A sample `adacovex.toml` must ship in the cwd of the adacovex source code itself.
  - The sample should show the current default values for the supported entries.
  - It should include comment blocks that mention other supported values where relevant.
  - It should link to the documentation for further detail.
- Precedence must be explicit and fixed:
  1. explicit CLI flags win
  2. per-project / cwd `adacovex.toml` wins over the global config
  3. global config file wins over built-in fallback values
  4. built-in fallback values apply last
- Key questions to answer during implementation:
  - which flags are allowed in the config file
  - how `init` should scaffold a per-project `adacovex.toml` and how that interacts with CI
  - how config paths are discovered on each platform
  - which settings need docs links, value comments, and default-value comments in the sample file

### Exclusions and ignore annotations
- The project already has per-file opt-out markers and scan-scope skip flags.
- The request appears to want a clearer or broader exclusion/ignore mechanism, possibly at a finer granularity than the current file-level opt-outs.
- Implementation should clarify:
  - whether this is a new annotation form, a generalization of existing opt-outs, or both
  - what scope it covers (complexity, docstrings, proof, or all analyses)
  - how it should be documented so it is not confused with the existing markers

### Watch / hot reload
- There is no current watcher-based serve behavior in the scanned surface, so this is a new runtime feature.
- It must be designed as opt-in or on-by-default with an explicit disable flag, and only for commands where watching is sensible.
- Watch support needs a cross-platform file watcher story; this is the heaviest runtime dependency-style decision in the plan and should be scoped carefully.

## Version bumps

The tooling-ergonomics work is spread across three minor bumps:

- `v1.65.0` -- documentation parity + diagnostics foundation
- `v1.66.0` -- diagnostics depth + failure thresholds + exclusions
- `v1.67.0` -- configuration + watch behavior

Each bump ends with the same release checklist, and a bump is only complete once its changelog is written, the version is bumped, and `just check` passes:

- [x] v1.65.0 changelog written
- [x] v1.65.0 version bumped
- [x] `just check` passes for v1.65.0
- [ ] v1.66.0 changelog written
- [ ] v1.66.0 version bumped
- [ ] `just check` passes for v1.66.0
- [ ] v1.67.0 changelog written
- [ ] v1.67.0 version bumped
- [ ] `just check` passes for v1.67.0

---

## Release 1: v1.65.0 -- Documentation parity + diagnostics foundation
Recommended first bump because it improves correctness and feedback quality before adding new knobs.

### 1.1 Audit and reconcile `tldr` and `man` documentation

- [x] Enumerate current tldr page commands and compare them against the CLI reference, `--help`, completion, and the man page.
- [x] Fix any clear discrepancies in the tldr page, man page, or CLI reference so the three surfaces agree.
- [x] Keep the tldr page concise; do not try to turn it into a full CLI reference.
- [x] Update the relevant docs in the same change if any command descriptions or examples change.
- [x] Regenerate or refresh generated help surfaces if the tldr/man surfaces change.

### 1.2 Add a documentation-integrity check to `just check`

- [x] Add a check that verifies the tldr page, man page, and CLI reference surfaces are mutually consistent for the supported subcommands and flag shapes they advertise.
- [x] Make the check able to report:
  - a subcommand or flag shown in one surface but missing from another
  - stale command examples
- [x] Keep this check alongside the existing docs-coverage and action-parity gates, not as a replacement for them.
- [x] Wire the new check into the release path so it runs before the version bump is considered done.

### 1.3 Proof-output readability baseline

- [x] Start with the diagnostics that are cheapest to make useful and least likely to disturb existing behavior:
  - cleaner replay of the base prover stdout/stderr
  - clearer separation between tool noise and actionable failure detail
- [x] Defer richer inline annotations and structured failure shapes to v1.66.0 once the output model is agreed.
- [x] Keep the baseline update compatible with the existing quiet-by-default prove behavior.

### 1.4 Documentation updates for Release 1

- [x] Update CLI reference and related usage pages if the audit changes any command descriptions or examples.
- [x] Regenerate or refresh generated help surfaces if the tldr/man surfaces change.
- [x] Confirm the changelog entry for v1.65.0 is written before the version bump.

### 1.5 Release checklist for v1.65.0

- [x] v1.65.0 changelog written
- [x] version bumped to v1.65.0
- [x] `just check` passes

---

## Feature work view

This section is the per-feature checklist mirror of the release view above, intended for slow progress where each feature is ticked off once it lands and its changelog pieces are in.

### Documentation parity

- [x] Audit tldr and man surfaces against the CLI reference and `--help`.
- [x] Fix discrepancies across tldr, man, CLI reference, and completion.
- [x] Add a docs-integrity check to `just check`.
- [x] Document any changed command descriptions or examples.

### Proof output readability baseline

- [x] Improve the replay/formatting of base prover output.
- [x] Separate tool noise from actionable failure detail.
- [x] Keep the baseline compatible with quiet-by-default prove behavior.

---

## Release 2: v1.66.0 -- Diagnostics depth + failure thresholds + exclusions

---

## Release 2: v1.66.0 -- Diagnostics depth + failure thresholds + exclusions

### 2.1 Richer prove diagnostics

- [ ] Improve actionable output for proof failures:
  - show the prover identity and the kind of proof that failed where possible
  - point at the source file and target location rather than only the summary
  - give a short "what failed" and "how to fix" style guidance when the tool can derive it
- [ ] If the output-mode decisions from v1.65.0 are still open, finalize them here:
  - concise vs verbose output
  - which mode is default locally
  - which mode is used in CI
- [ ] Document the final diagnostics-mode choices.

### 2.2 `--fail-on` threshold flag

- [ ] Add a configurable exit-code/threshold mechanism.
- [ ] Define the supported threshold dimensions and the failure semantics clearly.
- [ ] Decide whether `--fail-on` generalizes existing gates or is a separate mechanism.
- [ ] Make sure the new flag is:
  - documented
  - wired into completion
  - covered by tests
  - reflected in the Action/CI surface if CI is expected to use it

### 2.3 Exclusion and ignore annotations

- [ ] Standardize or extend exclusion/ignore behavior.
- [ ] Decide whether this is:
  - a new inline annotation form
  - a broader opt-out mechanism
  - or both
- [ ] Document the supported granularity and the analyses it affects.
- [ ] Keep the new exclusion semantics distinct from the existing opt-out markers in both behavior and docs.

### 2.4 Documentation updates for Release 2

- [ ] Document the `--fail-on` threshold flag.
- [ ] Document the new or extended exclusion annotations.
- [ ] Document the final diagnostics-mode choices.
- [ ] Update the changelog entry for v1.66.0 before the version bump.

### 2.5 Release checklist for v1.66.0

- [ ] v1.66.0 changelog written
- [ ] version bumped to v1.66.0
- [ ] `just check` passes

---

## Feature work view (continued)

### Richer prove diagnostics

- [ ] Show prover identity and proof type where possible.
- [ ] Point at source file and target location instead of only summarizing.
- [ ] Give short "what failed" and "how to fix" guidance when derivable.
- [ ] Finalize concise vs verbose output choices and document them.

### `--fail-on` threshold flag

- [ ] Add configurable exit-code/threshold mechanism.
- [ ] Define supported threshold dimensions and failure semantics.
- [ ] Decide whether `--fail-on` generalizes existing gates or is separate.
- [ ] Document, wire into completion, test, and reflect in the Action/CI surface if used.

### Exclusion and ignore annotations

- [ ] Standardize or extend exclusion/ignore behavior.
- [ ] Decide whether this is a new annotation form, a broader opt-out mechanism, or both.
- [ ] Document supported granularity and affected analyses.
- [ ] Keep new exclusion semantics distinct from existing opt-out markers in behavior and docs.

---

## Release 3: v1.67.0 -- Configuration + watch behavior

### 3.1 Configuration file support

- [ ] Implement config-file reading for the flags that should be settable there.
- [ ] The configuration file must be named `adacovex.toml`.
- [ ] The config file is for overriding default CLI flag values, so users can set their preferred defaults once and stop repeating long CLI invocations.
- [ ] Provide a sample `adacovex.toml` in the cwd of the adacovex source code itself.
  - [ ] Show the default values for the supported entries.
  - [ ] Add comment blocks mentioning other supported values where relevant.
  - [ ] Link to the documentation from the sample file.
- [ ] Enforce the precedence order:
  1. [ ] explicit CLI flags win
  2. [ ] per-project / cwd `adacovex.toml`
  3. [ ] global config file
  4. [ ] built-in fallback defaults
- [ ] If `init` is wanted, make it create a per-project `adacovex.toml` with a sensible scaffold drawn from the sample file.
- [ ] Support a global config option that can disable the per-project scaffolding behavior when that is desired.
- [ ] Keep the sample file, the global config docs, and the runtime precedence behavior in sync with each other and with the CLI defaults.

### 3.2 Watch / hot reload for serve and other suitable commands

- [ ] Add a file-watcher mode for commands where live reload is useful, starting with `serve`.
- [ ] Default behavior:
  - [ ] watch where it makes sense
  - [ ] allow `--no-watch` to disable it
- [ ] Keep `prove` off by default for watching, but allow it to be enabled if useful.
- [ ] Use a cross-platform watcher implementation that fits the project's runtime constraints.

### 3.3 Documentation and test updates for Release 3

- [ ] Document the config file location, format, precedence, and `init` behavior.
- [ ] Document that the file is named `adacovex.toml` and that it is used to override default CLI flag values.
- [ ] Keep the user-facing documentation aligned with the sample `adacovex.toml`, including the listed defaults and the supported-value comments.
- [ ] Document watch behavior, defaults, and the `--no-watch` escape hatch.
- [ ] Add tests for config reading, precedence, and watch behavior where practical.
- [ ] For every config-related change, update the docs in the same change so the runtime behavior, the sample file, and the documentation never drift.
- [ ] Update the changelog entry for v1.67.0 before the version bump.

### 3.4 Release checklist for v1.67.0

- [ ] v1.67.0 changelog written
- [ ] version bumped to v1.67.0
- [ ] `just check` passes

---

## Feature work view (continued)

### Configuration file support

- [ ] Implement config-file reading for the flags that should be settable there.
- [ ] Name the configuration file `adacovex.toml`.
- [ ] Treat the config file as a place to override default CLI flag values, so users set preferred defaults once and stop repeating long CLI invocations.
- [ ] Ship a sample `adacovex.toml` in the cwd of the adacovex source code itself.
  - [ ] Show the default values for the supported entries.
  - [ ] Add comment blocks mentioning other supported values where relevant.
  - [ ] Link to the documentation from the sample file.
- [ ] Enforce the precedence order:
  - [ ] explicit CLI flags win
  - [ ] per-project / cwd `adacovex.toml`
  - [ ] global config file
  - [ ] built-in fallback defaults
- [ ] If `init` is wanted, make it create a per-project `adacovex.toml` with a sensible scaffold drawn from the sample file.
- [ ] Support a global config option that can disable the per-project scaffolding behavior when that is desired.
- [ ] Keep the sample file, the global config docs, and the runtime precedence behavior in sync with each other and with the CLI defaults.

### Watch / hot reload for serve and other suitable commands

- [ ] Add a file-watcher mode for commands where live reload is useful, starting with `serve`.
- [ ] Default behavior:
  - [ ] watch where it makes sense
  - [ ] allow `--no-watch` to disable it
- [ ] Keep `prove` off by default for watching, but allow it to be enabled if useful.
- [ ] Use a cross-platform watcher implementation that fits the project's runtime constraints.

---

## Recommended implementation order within each release

For every release, implement each feature as its own markdown checklist so a feature can be ticked off once it is in and its parts of the changelog are included:

1. [ ] Decide the final flag/behavior design and write it down.
2. [ ] Implement the core behavior.
3. [ ] Wire the feature through docs, completion, man page, and tldr page where relevant.
4. [ ] Add tests.
5. [ ] Run the existing parity and docs checks so new flags/surfaces do not drift.
6. [ ] Write the version changelog.
7. [ ] Bump the version.
8. [ ] Run `just check`.
9. [ ] Mark the release checklist complete only after the changelog, version bump, and `just check` are all done.

## Risks and open decisions

- Proof output style: concise vs verbose vs contextual CI mode is still open and affects flag design.
- `--fail-on` semantics: determine whether it generalizes existing gates or is a separate mechanism.
- Configuration file: confirm the current global config shape before designing the per-project file and `init` behavior.
- Watch support: confirm the cross-platform watcher approach before promising watch behavior across commands.

## Documentation discipline

For each implementation item, update the docs in the same change:

- the relevant CLI reference and usage pages
- the generated man page and tldr page where the change is user-facing
- the sample `adacovex.toml` and its comments when config defaults, supported values, or precedence are affected
- the changelog for the version the change ships in

When config defaults, sample values, supported-value comments, or precedence change, keep the runtime, the sample `adacovex.toml`, and the documentation telling the same story.

## Verification approach
- After each release's implementation:
  - run the relevant docs and parity checks
  - run the test suite
  - manually exercise the new flags/behaviors on a small target project
- Before releasing, confirm that:
  - the tldr page, man page, CLI reference, and `--help` agree
  - new flags are discoverable
  - defaults are intentional and documented
  - CI-relevant behavior is documented and testable
