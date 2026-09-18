# Pipeline and prove timings

`make bench` times five scenarios: pipeline cold, pipeline warm, prove cold,
prove warm, and prove cold clone. The category definitions and the expected
numbers are on [Performance](index.md); the machine and the harness are on
[Benchmarking adacovex](benchmarks.md).

## Sample output (hyperfine, x86-64, 12-core machine)

1.47.0 is the first release compiled with `-O2 -gnatn` (1.46.0 and earlier
used GNAT's default `-O0`). The 1.46.0 figures are kept for comparison;
they were measured in the same session so the load conditions match. The
1.50.0 column was measured on a later session, so read it for shape, not
for a millisecond-level A/B against 1.47.0. The 1.52.0 column is the first
measured at gnatprove `--level=4` (its prove gate) and on the same tree the
cold-clone scenario landed in, so its prove rows sit beside the new
scenario:

| Scenario | 1.46.0 (`-O0`) | 1.47.0 (`-O2`) | 1.50.0 | 1.52.0 |
|----------|-----------------|----------------|--------|--------|
| Pipeline cold, self tree | -- | 73.9 +/- 5.8 ms | 73.2 +/- 5.3 ms | 67.5 +/- 2.5 ms |
| Pipeline warm, self tree | -- | 43.4 +/- 2.8 ms | 46.3 +/- 4.0 ms | 41.9 +/- 2.9 ms |
| Pipeline cold, Ada_CRDT | 39.3 +/- 4.3 ms | 33.4 +/- 3.5 ms (-15%) | 42.7 +/- 13.1 ms | 36.4 +/- 2.3 ms |
| Pipeline warm, Ada_CRDT | 38.4 +/- 4.7 ms | 40.8 +/- 4.7 ms (noise) | 31.6 +/- 2.9 ms | 30.8 +/- 2.3 ms |
| Prove cold, session wiped | -- | 80.9 +/- 5.3 s | 87.6 +/- 0.6 s | 67.3 +/- 4.2 s |
| Prove cold clone (fresh tree) | -- | -- | -- | 67.2 +/- 1.7 s |
| Prove warm | -- | 52.8 +/- 4.5 ms | 55.4 +/- 4.3 ms | 45.6 +/- 3.0 ms |
| Stripped binary | 6.49 MiB | 5.39 MiB (-17%) | 5.3 MiB | 5.4 MiB |

The 1.52.0 column was measured in one session (hyperfine, gnatprove 16.1.0,
12 logical cores, `--level=4` prove gate at 878 VCs). Its pipeline rows are
the fastest of the four columns, which is measurement noise on an I/O-bound
path, not a claimed optimisation: the 1.52.0 work touched no scanning or
rendering code. The prove-cold figure moves down from 1.50.0's 87.6 s
sample mostly through load conditions -- see the range note below.

The 1.50.0 column is also the first with the smaller manual encoding, so
its 5.3 MiB stripped binary is the only row that moves by design (see
[Bundled offline manual](benchmarks-binary-size.md#bundled-offline-manual)).

The 1.50.0 shapes are deliberately flat: the phase's work removes failed
work (a rewrite of the generated manual, a recompile and relink, and a
re-proved tree), not steady work. The headline 1.50.0 number is therefore
not in this table: `make prove` on an unchanged tree measures ~1.0 s (five
runs), because `alr build` is now a true no-op instead of recompiling the
28k-line generated manual on every run.

The prove-cold figure is solver-bound and machine-load sensitive: repeat
single-shot runs of the identical 1.47.0 tree measured between 67 s and
109 s as background load varied (a matched-load A/B settled at 69.9 s vs
67.3 s). The 1.50.0 tree behaves the same way (single shots of 61 s and
67 s against a three-run sample of 87.6 s), and the 1.52.0 tree measured
67.3 s with the same shape. Treat ~40-110 s as the
observed range; the compiler switches and the proof level do not move it
(level 4 costs the same order as the default level on this tree -- one
full-tree level-4 session measured ~19 s of wall at `-j8` against ~14 s at
the default level, both far under the multi-run bench samples because the
session store amortises across repetitions that keep it).

The numbers shift with the machine and the codebase. What matters is the
shape: the warm paths sit in the tens of milliseconds, and the cold paths
are bounded by work that genuinely must happen (hashing the changed
sources, parsing the proof, building the SBOM) -- a from-scratch solver
run happens once per gnatprove session, not once per run.

## The prove cold-clone shape

1.52.0 adds a fifth scenario to `make bench`: prove against a **fresh copy**
of the tree -- no result cache, no gnatprove session, and no
`gnatprove.out`. It is the first-run-on-a-new-checkout shape: prove cold
wipes the session but leaves the summary in place, while a cold clone has
nothing, so nothing can short-circuit. Measured on the 1.52.0 tree:
67.2 +/- 1.7 s over two runs (min 66.0 s, max 68.5 s), statistically
identical to the 67.3 s prove-cold sample in the same session, as expected:
the tree copy adds well under a second and the solver work dominates. Read
the two rows as one number with two names -- the scenario exists to prove
that the fresh-checkout path pays nothing beyond prove cold, not to
introduce a new cost.

## The Ada_CRDT second datapoint

A second datapoint rides along with every `make bench`: when the Ada_CRDT
dogfood tree (`../Ada_CRDT`) is present, the two pipeline scenarios repeat
against it. It is a smaller target (~80 specs, its own vendored layout and
manifest set), so a regression tied to one project's structure cannot hide
behind the self-assessment numbers. 1.46.0 measured ~39 ms cold / ~31 ms
warm there (the `-O0` baseline); 1.47.0 measures ~33 ms / ~41 ms, 1.50.0
~43 ms / ~32 ms (the 1.50.0 cold sample is noisy, one 80 ms first run), and
1.52.0 ~36 ms / ~31 ms. The prove scenarios are not repeated (the solver
floor is covered by the self run).

## See also

- [Performance](index.md) -- the benchmark category definitions.
- [Benchmarking adacovex](benchmarks.md) -- the machine and the harness.
- [Prove timing and the optimisation review](prove-timing.md) -- the
  per-phase `make prove` timing table.
