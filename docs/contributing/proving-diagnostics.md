# Reading a prove failure

`adacovex prove` runs gnatprove and reports what it found. This page shows
what the output looks like in each mode, and what each unproved check asks you
to change. The contract rules are on
[Proving and writing proofs](proving.md).

## The two output modes

A local run is **concise**. adacovex captures the prover output and replays
one framed block when the run finishes. The replay keeps the check results,
the errors, the warnings, and the summary.

The replay drops the `Phase N of M:` progress lines and the suppressed notice
blocks. It drops the blank lines those drops leave behind, and it reports how
many notices it hid in a `filtered:` footer.

gnatprove prints one warning per inlined call site, so one diagnostic can
arrive many times in a run. The replay keeps the first copy, drops the repeat
with its location and excerpt, and states the count in a `duplicates:` footer.
`--verbose` shows every raw line.

`--verbose` turns the capture off and streams the raw prover output live. CI
passes `--verbose`, so a CI log keeps the unedited prover stream.

## Colour, the cache, and CI

The concise replay is coloured by severity. Errors are red, warnings are
yellow, and notices and their locations are dim. `Success:` is green, and the
summary footers are bold. The same rules apply to a cached replay.

Colour is off when a CI variable is set, when `NO_COLOR` is set, or when
`TERM=dumb`. A redirected log therefore stays plain text.

A warm cache hit is not a silent run. adacovex stores the plain replay text
under the proof input hash and prints it again, so a cached run and a fresh
run report the same warnings, diagnostics block, and footers. The `cache:`
line says that the proof itself came from disk.

Inside GitHub Actions, each distinct unproved finding is also an inline
annotation. The shape is
`::error file=<path>,line=<line>,col=<column>,title=SPARK proof failed::<kind>`.
A local run prints the text block only.

## A clean run

```
Success: all checks proved (N checks).
Summary logged in obj/gnatprove/gnatprove.out
  coverage:  statements 96% (1448/1508)  subprograms 98% (392/400)  VCs 100% (1054/1054)
```

A line states the number of checks gnatprove proved. Nothing was filtered, so
the replay has no footer, and the run prints no diagnostics block.

## The coverage summary

The last line reports **proof coverage**: the proved statements, the proved
subprograms, and the proved VCs, each with its count and its total. A total of
zero prints `n/a`, never a division by zero and never 100 percent.

The summary is on by default. `--no-coverage` hides it for one run, and
`[prove] coverage = false` in the global configuration file hides it for every
local run. `--coverage` forces it back on, so a CI job can override the config
file. The summary is not a gate: `--require-proof` and `--fail-on` decide pass
or fail.

The summary is one line, and it is deliberately short. Run
`adacovex spark-coverage` for the full report: every file, folder, or package
with its statement, subprogram, and VC coverage, plus `--require-coverage` for
a gate on that report.

## A failing run

The fixture below reads one element of a table. Its precondition states
`I <= T'Length`, which does not prove the index is inside the table, because
an unconstrained array need not start at its length.

```
 medium: array index check might fail
--> prove_diag_broken.adb:7:17
    7 |          return T (I);
      |                    ^
      + reason for check: value must be a valid index into the array
      + possible fix: add precondition (I in Positive) to subprogram at prove_diag_broken.ads:11
      + provers gave up before completing the proof
Summary logged in obj/gnatprove/gnatprove.out

  proof:      1 unproved check(s) (prover alr:16.1.0)
    prove_diag_broken.adb:7:17  array index check (provers gave up)
  fix:       the provers gave up before completing the proof; raise the proof budget with --steps=<N> (10000 by default)
```

The replay holds the prover's own detail: the check kind, the `-->` location,
the source excerpt, and the sub-messages. The diagnostics block adds the
unproved count, the prover identity, the location and kind of each finding,
and one fix hint.

The block names at most eight findings. A longer list still counts every
finding, and it states how many it left out.

The block names each finding once. A check that gnatprove reported once per
inlined call site counts once, because the location and the check kind are
the same.

## What each finding asks you to change

| Finding | What it means | What to do |
|---------|---------------|------------|
| `array index check`, `range check`, `overflow check` | A value can leave its subtype bounds | State the bound as a subtype constraint, a precondition, or an invariant that the code establishes |
| `divide by zero` | The divisor can be zero | State `Y /= 0` in the precondition of the subprogram that divides |
| `precondition` | A caller cannot establish the callee's precondition | Establish it at the call site, or relax the precondition to what the body needs |
| `postcondition` | The body may not satisfy its own contract | Add the missing fact to a loop invariant, or state the postcondition the body derives |
| `assertion` | A `pragma Assert` may not hold | Add the fact as a loop invariant, or state it where the body makes it true |
| `loop invariant` | The invariant may fail on entry or after an iteration | Move the fact into the invariant, where the loop preserves it |
| `termination` | The proof cannot show the loop or the recursion ends | Add a `Loop_Variant` that decreases on every iteration |
| `initialization` | An object is read before its first write | Write the object before its first read, and declare its `Global` aspect |

The fix hint follows the first finding's kind. Fix that finding first, then
rerun `prove`. The next block names the next finding.

## Contract typos are compile errors

A misspelled attribute (`Doubled'Resul`) or an unknown name in a contract is
a compile error, not a finding. gnatprove stops before the proof, and the
replay keeps the error with its location:

```
 error: <the compiler message>
--> prove_diag_typo_attribute_broken.ads:10:19
   10 |              Post => Doubled'Resul = 2 * X;
      |                              ^
```

The run then exits non-zero and the final line states the prover exit code,
for example `ERROR: gnatprove exited with code 1 (error lines: 1 above)`. No
diagnostics block appears, because no check was proved or disproved.

Fix the contract and rerun. A typo never needs a larger `--steps`.

## When the provers give up

The sub-message `provers gave up before completing the proof` means the solver
ran out of budget. The solver found no counterexample, so the code may be
correct and the check may need a larger budget.

Rerun with a larger `--steps` before you change the contracts. `--steps`
defaults to 10000, and a larger value costs proof time. Raise it for one run
rather than for the whole project.

The block marks such a finding as `(provers gave up)`, and its fix hint raises
`--steps` instead of naming a contract.

## Seeing the before and after yourself

`tests/e2e/prove_diagnostics.py` generates one project per case on this page,
each with a broken variant and a fixed counterpart. The cases are `index`,
`overflow`, `division`, `precondition`, `invariant`, `invariant_entry`, `flow`,
`typo_attribute`, and `typo_identifier`.

```bash
python3 tests/e2e/prove_diagnostics.py --keep
adacovex prove --target=obj/prove-diagnostics/prove_diag_index_broken
adacovex prove --target=obj/prove-diagnostics/prove_diag_index_fixed
```

The first run prints the replay and the diagnostics block. The second prints
`Success: all checks proved`. Run one case with `--case=overflow`, and add
`--debug` to print every full prover output. `just prove-e2e` runs the same
script as a gate, and it skips itself when no gnatprove is resolvable.

## See also

- [Proving and writing proofs](proving.md) -- contracts, VC categories, and
  proof patches for vendored code
- [Proof patches over vendored code](proving-patches.md) -- adding contracts
  without touching the originals
- [CLI reference -- the `prove` subcommand](../usage/cli-reference-flags.md#the-prove-subcommand)
  -- every `prove` flag
- [SPARK assurance levels](../api-docs/adacovex-spark-levels.md) -- Stone to
  Platinum
