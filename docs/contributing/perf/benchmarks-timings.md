# Pipeline and prove timings

`just bench` times the build phases and five pipeline and `prove`
scenarios: pipeline cold, pipeline warm, prove cold, prove warm, and prove
cold clone. The category definitions and the expected numbers are on
[Performance](index.md); the machine and the harness are on
[Benchmarking adacovex](benchmarks.md).

**Build profile.** Since 1.57.0 the tree carries two build profiles: the
development profile (`-O1 -gnatn -g`, the default for `alr build`) and the
release profile (`-O2 -gnatn`, selected by `tools/build.py --release` or
`ADACOVEX_VERSION`). Every timing on this page is taken on the release
profile, because that is the binary the released figures describe; a
development build is roughly half the serial compile time and is for
iteration, not for measurement.

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
not in this table: `just prove` on an unchanged tree measures ~1.0 s (five
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

**Every scenario banner carries the load it was measured under**, because the
scenarios run in sequence and each one loads the box. A scenario measured late
inherits the load the earlier ones left behind, so two rows can differ by more
than the work between them accounts for. `just bench` prints the 1-minute load
average in front of each scenario for that reason. To compare two shapes
honestly, run them paired -- back to back, each with its own pre-run load --
rather than comparing rows from one sequential pass. The paired method, and a
case where sequence order alone manufactured an apparent 14-second gap, are on
[Prove timing and the optimisation review](prove-timing.md).

## Generator and docs-bundling cost

`just build` runs five generators before it compiles anything, and the
docs bundling is the step users suspect when a build feels slow. The
measured steady-state cost says it is not the bottleneck. These figures
come from the 12-core bench machine with nothing changed and every cache
warm (load 0.8-1.4, 1.63.0 tree):

| Step | ms |
|------|----|
| `tools/gen-version.py` | 41 |
| `tools/csslint.py --check` | 38 |
| `tools/gen-dashboard.py` | 142 |
| `tools/gen-docs.py` (bundle fingerprint current, bodies cached) | 76 |
| `tools/gen-tldr.py` | 40 |
| `sphinx-build` from scratch (`gen-docs.py --fresh`) | 9 950 |

A no-op `alr build` measures 301 ms +/- 9 ms over five runs (load 0.94),
so a no-op `just build` is about 0.3 s of workspace sync plus about 0.3 s
of generators. The encoding adds about 2 s to the cold Sphinx row because
it runs in parallel across the cores. Every later run reuses the encoded
bodies from `obj/adacovex-docs-encode/`.

## The cold-tree docs skip (1.63.0)

1.63.0 changed the one large docs row. A tree with no Sphinx build
directory -- a fresh clone, or a tree after `docs/_build/` was removed --
used to rebuild the whole site (8.8 s, 9.5 s, 9.7 s and 10.2 s over four
samples at load 1.3-1.4) and re-encode every asset to reproduce bytes the
committed spec already carried. The generator now stamps the bundle
fingerprint of its inputs into the spec header (`Source_Fingerprint`),
and a run that is not asked to rebuild reads that constant instead: the
same cold tree measures 76 ms +/- 4 ms over three runs, and Sphinx does
not run. `gen-docs.py --check` never takes this path, so the gate still
fails on a stale or hand-edited spec, and a clean build reproduces the
committed spec byte for byte.

The two shapes differ by two orders of magnitude in syscalls as well as in
wall time (strace -c on the same tree):

| Shape | total syscalls | `newfstatat` |
|-------|----------------|--------------|
| cold tree, fingerprint hit | 3 618 | 763 |
| `gen-docs.py --fresh` | 115 581 | 46 366 |

The same change closed the parity gap that made the spec gate fail on a
cold machine. Sphinx merges an incremental search index with the one
already on disk, and its prune empties a removed word's document set
without dropping the key, so a committed spec carried phantom word
entries (`"appveyor":[]`) that a clean build never emits. The bundler now
drops the empty entries and sorts the keys, so the incremental developer
tree and the clean build a fresh clone runs produce the same bundle.

## Cold build phases (1.63.0)

`python3 tools/bench.py build` measures the build phases on the release
profile. A cold `just build` on a fresh checkout measures 38.4 s +/- 2.5 s
over three runs (35.7-40.7 s, load 0.95). The phases split as:

| Phase | Cost | Verdict |
|-------|------|---------|
| generators (version, CSS gate, dashboard, docs, tldr) | 0.34 s | docs phase cut from 9-10 s to a fingerprint hit |
| `alr` workspace sync | inside the 301 ms no-op build | nothing to fetch: `alire/alire.lock` carries an empty solution |
| compile + link (79 units, both mains, `-j0` over 12 threads) | about 38 s | measured-necessary: gprbuild already fans out over every thread, and the release profile keeps `-O2` by design |
| cold prove (solver, 1054 VCs) | 64.5 s | measured-necessary: the solver dominates, so only VC count moves it (see [Prove timing](prove-timing.md)) |

The strace profile of the warm no-op build reports 136 370 syscalls,
19 710 of them `newfstatat`: the stat traffic of gprbuild's out-of-date
check across the source tree. Nothing in that profile repeats on a cold
tree -- the cold tree pays the compile, not the check.

## Host-side toolchain caches

A cold machine pays for its toolchain once, per host, outside the tree.
Alire fetches `gnat_native` (990 MB unpacked) and `gprbuild` (278 MB) into
`~/.local/share/alire/toolchains/` on the first `alr build`. The
dev-manifest commands fetch their binary crates into
`~/.local/share/alire/releases/`: `gnatdoc_bin` (139 MB) for `just doc`,
`gnatformat_bin` (53 MB) for `just fmt`, and `gnatprove` (1.3 GB) for the
proof tools. The `prove` subcommand's own download keeps a second copy
under `~/.local/share/adacovex/toolchain/`.

Nothing in that list is a build dependency of the crate. Once the caches
exist, the sync costs nothing measurable -- the whole no-op `alr build`
is 301 ms. The published `alire.toml` declares no dependencies, so a
consumer build of the `covex` crate fetches nothing beyond the Alire
toolchain.

The compile side tells the same story. A full rebuild of all 101 bodies
takes 39.1 s, and the serial compile totals 99.8 s across those files.
`adacovex-parsers-manifest.adb` alone is 21.9 s of that serial total (22
percent). The two generated bundle specs together are 0.3 percent of it:
`adacovex-docs_template.adb` compiles in 288 ms. Both compile figures
were taken before the build split into profiles, on the single
`-O2 -gnatn` switch set that the release profile preserves, so they
describe the shipped binary's profile.

## The prove cold-clone shape

1.52.0 adds a fifth scenario to `just bench`: prove against a **fresh copy**
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

A second datapoint rides along with every `just bench`: when the Ada_CRDT
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
  per-phase `just prove` timing table.
