# adacovex 1.57.0

Date: _2026-10-03_

Version bumped 1.56.0 -> 1.57.0.

## Changes

### C1: The manifest package is split into one helper per file

`src/parsers/adacovex-parsers-manifest.adb` was one 2 254-line unit, and it
was the slowest compile in the tree at 21.9 s. It is now a parent body plus 19
separate bodies, one per helper, named for the subprogram each holds, which is
the convention the rest of the package already followed. Nineteen entries were
added to `tools/agents-tree.map` so the architecture tree stays generated from
the source rather than maintained by hand.

This is pure code motion. No behaviour changed, no flag changed, and no proof
surface moved: the proof is still 884 of 884 VCs across 66 analysed units with
0 unproved and 0 justified.

The split does not do what it was expected to do, and the reason is worth
recording so the next reader does not assume it will. **An Ada separate body
does not get its own compiler process.** It is compiled in the same `gnat1`
invocation as its parent unit, which is why `obj/adacovex-parsers-manifest.o`
is a single 6.5 MB object listing every subunit symbol. A separate body splits
a file; it does not split a compile. Measured through `git stash -u` on one
machine with the load recorded, the original tree built in 60.7 s and 62.7 s and
the split tree in 57.3 s and 59.8 s. The wall clock barely moved, and an earlier
37.5 s figure for the unsplit tree turned out to have been taken on a quieter
machine, so build timings on this host are load-relative and have to be read as
such.

Two consequences shaped the change itself. The scan directory stack, the
referenced-tool set, the probe list, the cache flag, and the key buffers were
locals of one subprogram, and a separate body can neither see them nor reset
another body's state, so they became package-level objects reset at the top of
`Discover_System_Dev_Deps`. `Trim` and `Starts_With` stayed in the parent body
because a SPARK aspect cannot be placed on a separate body declaration; gnatprove
rejects it with `incorrect placement of aspect "SPARK_Mode"`.

The only proof figure C1 moved is the considered-subprogram count, from 461 to
474, because each separate body is now an entity in its own right. C1 added no
verification condition, assertion, contract, or run-time check. The tree as
shipped stands at 477 considered and 98 proved subprograms, and 884 VCs, because
the coverage analyser of H1 contributes the remainder.

### C2: The build has a development profile and a release profile

`adacovex.gpr` put `-O2 -gnatn` in `Compiler.Default_Switches`, so a developer
rebuild paid the release optimisation cost on every compile. The project now has
two profiles. Development builds at `-O1 -gnatn` with `-g`; release builds at
`-O2 -gnatn` with no debug information. `tools/build.py` selects the release
profile for `--release` or when `ADACOVEX_VERSION` is set in the environment,
and prints `=== Build profile: <name> ===` so the profile in force is never a
guess. Both switch sets were verified in the compile command lines, and
`gprbuild -s` does rebuild when the profile changes.

The mechanism is not the one this release planned, because the toolchain does
not have it. gprbuild 26.0.1 has no `profile` block: the parser rejects the name
with `":=" expected`, reading `profile` as an identifier. It has no conditional
expressions either, rejecting `cannot be part of an expression`. What works is a
`case` statement over a typed external variable, which gprbuild does support:

```ada
type Build_Profile_Type is ("development", "release");
Profile : Build_Profile_Type := external ("ADACOVEX_PROFILE", "development");
```

One more trap, recorded because it is silent: Alire's own `--release` does not
set `BUILD=release`. Alire 2.1.1 has no `[build-profiles]` section, so the
release signal has to be the `--release` flag or the `ADACOVEX_VERSION`
environment variable that a release build sets anyway.

Every performance figure in the documentation must now name the profile it was
taken on, because a `-O1` number is not comparable with an `-O2` one. That
documentation pass is B5 of the plan and is **not** in this release: the
existing figures were all taken before profiles existed, so they remain
comparable with each other, but this release does not yet state the profile
beside them, and the stripped-binary-size figure still describes a binary built
with `-g`.

### C3: The build parallelism was measured, and no fix was needed

`alr build` reports 39 s of wall clock for 99.8 s of serial work on 12 cores, a
speedup of 2.6x, and an early sample of the process table showed at most three
concurrent `gnat1` processes. That reads like a capped job pool, so the first
plan was to pass `--jobs=<cores>` through `tools/build.py`.

It is not a job pool. Sampling the process table over a full rebuild gave a
**mean of 6.4 and a maximum of 12** concurrent `gnat1` processes on 12 cores:
the machine is already saturated at its peaks, and the low mean is the serial
section rather than a cap. `alr build -- -j0` measured no faster than the
default on the same tree. The serial section is the chain
`adacovex-types.ads` at 9.3 s into `adacovex-parsers-manifest.adb` at 21.9 s,
31 s that cannot overlap itself.

So `tools/build.py` is unchanged. The honest conclusion is that the only real
lever is the 21.9 s body, and C1 shows it cannot be shortened by splitting it
into separate bodies, because those share one compiler invocation. Shortening it
means moving code into a genuinely different unit. That is a separate piece of
work, and it is not in this release.

### C4: The manifest split and the parallelism ceiling are not independent levers

This release records a planning correction, because two items that were scoped
as independent turned out to depend on the same language property.

B1 was justified as the largest single build win, on the reasoning that
splitting a 2 254-line unit lowers the critical path on a parallel build. B4
was justified as a cheap one-line fix to a capped job pool. Measuring both
showed that separate bodies share a `gnat1` invocation, so B1 cannot shorten the
critical path, and that the job count was never the constraint, so B4 has no fix
to apply. The two items were not independent: B1's benefit depended on exactly
the property B4's diagnosis removed.

Both changes still stand on their own merits. B1 puts the package in the
one-helper-per-file shape the rest of the tree uses and takes it under the
per-file complexity and LOC caps, and the diagnostic in C3 stops a future
release from spending time on a `--jobs` flag that cannot help. Neither is a
performance win, and this changelog does not claim one.

## Test Suite

1756 tests across 25 categories, unchanged from 1.56.0. C1 is pure code motion
through 19 new files, and the full suite passes on the split tree; C2 changes
compiler switches only; C3 and C4 change no assessed behaviour.

The absence of a new test category is deliberate for this release and is not an
oversight: the coverage analyser of H1 ships without tests of its own, because
its fixtures belong with the subcommand that invokes it. See H1.

## Proof Results

Platinum, 0 unproved, 0 justified, **884 of 884 VCs across 66 analysed units**
under gnatprove 16.1.0 at `--level=4`, on the release-equivalent `-O2` profile.
The analysed-unit count is identical to 1.56.0 and the VC total is not: the
coverage analyser of H1 adds six checks, and all six are proved.

The assessed Ada source did change, twice over. C1 moved code between bodies of
one package, and H1 added a whole package. The considered-subprogram count moved
from 461 to 477 and the proved count from 95 to 98. No `pragma SPARK_Mode (Off)`
was added to any package, and the only two packages that carry one remain
`Types.Implementation` and `Complexity`.

## Fixes

### H1: The coverage analyser failed two gates, and both are fixed

`src/core/adacovex-spark_coverage.ads` is the analyser for a planned
`spark-coverage` subcommand. It reached the tree with two gate failures behind
it, and both are fixed here rather than by parking the package out of the
release.

The first was the DO-178C traceability criterion. The package spec carries the
`HLR-SPARK` tag, and no `HLR-SPARK` record existed in
`docs/compliance/HLR.md`, so `make prove` reported `Orphan HLR tags found in
source` and DAL-C, ASIL B, and Class A all read Unmet. The record now exists and
states the three metrics, the file, folder, and package grouping, and the three
off classes.

The second was the `spark-off-check` gate, and the gate was at fault. The package
docstring quotes the phrase `(SPARK_Mode => Off)` when it names the reason
gnatprove gives for a skipped entity, and the gate matched that prose as if it
were a pragma. The gate now reads only the code part of each Ada line, the same
rule `check-docs.py` and the analyser itself already apply, so a docstring that
documents the pragma is no longer a violation while a real
`pragma SPARK_Mode (Off)` still is. `tools/tests.py` covers the new line
handling.

The package still has no CLI surface, no tests of its own, and no user
documentation. It ships in this release as proved, traceable code that nothing
invokes yet, and the subcommand, its flags, and its documentation land with the
release that gives the analyser a command.

## Traceability

- `HLR-SPARK` is new. It covers `Adacovex.Spark_Coverage`: the three metrics,
  the file, folder, and package grouping, and the three off classes. C1 through
  C4 change build switches and file layout only, and no requirement arises from
  them.
- `HLR-MANIFEST` -- unchanged in behaviour. C1 moves the implementation of 19
  helpers out of the parent body into separate bodies in the same package. The
  dependency graph, the SBOM, and the CLI surface are byte-identical; the
  `make check` gates that cover this package (`complexity-check`,
  `description`, `sbom`) pass unchanged.
- `HLR-BUILD` -- no such tag exists, and none is added. The build profile is a
  developer-facing switch, not an assessed requirement, in the same way
  `tools/gen-docs.py` and `tools/tests.py` are developer tooling that no HLR tag
  covers.
- C2 and C3 change `adacovex.gpr` and `tools/build.py`. Both are build
  configuration, not assessed Ada source, so the proof-input hash is unaffected
  and the cached proof stays valid.
- H1 adds the `HLR-SPARK` record to `docs/compliance/HLR.md`, which is the change
  that clears the DAL-C traceability criterion, and it repairs the
  `spark-off-check` gate so the gate reads Ada code rather than comment text.
  Neither changes an existing requirement.