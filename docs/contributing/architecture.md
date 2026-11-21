# adacovex Architecture Decisions

adacovex's architecture spans four pages. This page records the design
decisions: the zero-dependency rule, the formal-verification policy, and
result caching. The companion pages cover
[dependency management and the toolkit](architecture-dependencies.md),
[verification and proof patches](architecture-verification.md), and
[outputs, pipeline, and delivery](architecture-outputs.md).

## Unix Philosophy

adacovex follows the Unix philosophy of doing one thing well:

- **Single-purpose pipeline**: Each step (scanning, proof parsing, test parsing, DAL assessment, rendering) is a focused, composable unit.
- **Text-based interfaces**: Input and output are plain text (Ada source, `.out` files, Markdown reports, ANSI terminal output).
- **No library dependencies**: Only the GNAT runtime is used -- no external
  libraries or frameworks. Alire is the packaging and delivery mechanism and
  adds no runtime dependency (gnatprove is resolved at run time by the
  `prove` subcommand).
- **Composable tools**: `prove` runs GNATprove, then falls through to the
  standard assessment pipeline; `sbom` generates a proof-aware SBOM
  independently.
- **Exit codes**: `0` for success (DAL achieved), `1` for compliance failure, for straightforward CI integration.
- **Minimal user code**: users write as little code as possible while getting
maximum value. The tool accepts third-party and generated code as it is. It recognises common docstring conventions (Ada `--  @param`, Google `Args:`/`Returns:`, Sphinx `:param:`/`:returns:`) and common test-result formats (TAP, Automake, Surefire, Unity).

It lowers foreign type names (`int32_t`, `size_t`, and more) onto bounded Ada types. Nothing needs to be rewritten to be assessed.

## Zero-Library-Dependency Design

adacovex declares no library dependencies beyond the GNAT runtime. All data structures use either:

- GNAT runtime containers (`Ada.Containers.Vectors` for unbounded collections)
- Fixed-size string buffers (`Max_Line = 262144`, `Max_Path = 16384`, etc.) for bounded I/O

`Max_Path` and `Max_Line` scale with the auto-detected host word size
(`System.Word_Size`), keeping the classic 4096 / 262144 values on 64-bit
hosts while using proportionally smaller limits on narrower machines. The
semantic limits (`Max_Id_Str`, `Max_Desc_Str`, `Max_Filename`) are not
storage-size dependent and remain fixed.

`Max_Line` is deliberately generous (256 KiB on 64-bit) so single-line declarations from heavily code-generated projects parse cleanly. A physical line that *does* exceed the buffer is **never truncated and then processed** -- truncation can silently produce a partial (and wrong) result -- so the parser drains the remainder, reports file and line to standard error, and fails that parse explicitly.

The source scanner counts the skipped file in `Skipped_Ct`, which forces the DAL assessment to `Unmet` and the exit code to `1` (no compliance claim can be made for unread code). The same explicit-failure contract applies to every parser: HLR/LLR markdown, GNATprove output (text and JSON), test results, and Alire manifest / lockfile / GPR dependency graphs. An exact buffer-length line is not an overflow (it parses normally), and the reader consumes its line terminator, so the next line is never a spurious empty one. Paths exceeding `Max_Path` are reported and skipped rather than crashing.

**Overflow contract (two tiers).** Every fixed width in the tree is one of
the five `Max_*` constants, and each constant has exactly one tier:

| Constant | Value on a 64-bit host | Tier |
|----------|------------------------|------|
| `Max_Path` | 16384 (`256 * Word_Size`) | fail loudly |
| `Max_Line` | 262144 (`4096 * Word_Size`) | fail loudly |
| `Max_Id_Str` | 64 | clamp |
| `Max_Desc_Str` | 128 | clamp |
| `Max_Filename` | 128 | clamp |

Path and line buffers *fail loudly*. An
overlong physical line is drained and reported (`line exceeds Max_Line
buffer`), the file is not parsed, `Skipped_Ct` increments, and DAL becomes
`Unmet`. An overlong path is likewise reported and skipped with its file or
subtree.

No partial results ever flow downstream. Semantic text fields (subprogram
names, HLR/LLR IDs, descriptions, docstring tag names/values, CLI strings)
are *clamped* to their fixed buffer with the length field (`Name_Len`,
`Id_Len`, `D_Len`, ...) recording the prefix, so adversarial or generated
input can never raise `Constraint_Error`. Clamping keeps the scan correct
and still consumes the full token, so following tokens are not misparsed.

A bounded copy never keeps its own private width. The proof artefact copy,
for example, passes each artefact name as an unconstrained string and checks
it against `Max_Path`, so no second name bound can disagree with the path
bound.

**Why no chunking / LEB128.** adacovex audits in memory: counts (packages,
subprograms, HLR tags, tests, SBOM components) are unbounded vectors, and
each scanned unit is processed line-at-a-time into fixed per-item buffers. A
single Ada declaration does not admit streaming/chunked parsing, and
truncating a declaration is worse than a loud failure.

Chunking can gain nothing: LEB128 (variable-length integer encoding) is a serialization concern and does not apply to an in-memory CLI audit. The design therefore scales to arbitrarily large codebases by dynamic allocation, bounded per-item buffers, and explicit overflow handling, without streaming encodings.

The bounded-buffer constants are tabulated in
`docs/api-docs/adacovex-types.md` (`Max_Line`, `Max_Path`, `Max_Desc_Str`,
`Max_Filename`, `Max_Id_Str`).

So adacovex can be built and run on any system with a GNAT toolchain,
with Alire only for toolchain management.

## SPARK Formal Verification

adacovex itself is SPARK-proven: all of its VCs are proved and the code is
AoRTE-free. Its assessed level is **Gold**, not Platinum, because Platinum also
requires full proof coverage -- every subprogram the SPARK coverage report
assesses proved -- and the project keeps deliberately `SPARK_Mode (Off)` units
outside the proof. The tool analyses GNATprove output (`gnatprove.out`) to
assess SPARK assurance levels (Stone through Platinum) for target projects.

The tool does not perform verification itself: it parses and reports on proof
results produced by GNATprove, which keeps its scope narrow and aligns with
the Unix philosophy of composing specialised tools.

### Proof scope and justification policy

- **Proof scope is the target's own units.** adacovex proves the Ada/SPARK
   code it is run against, never third-party dependencies. GNATprove units that
   are skipped (for example standard-library or vendor code that GNATprove
   itself does not analyse) are tracked via `Units_Skipped` and reported in the
   ANSI and Markdown reports -- out of proof scope by design, not a proof
   failure.
- **Justifications are an accepted discharge mechanism.** A `Total` row's
  `Justified` count (GNATprove `pragma Annotate` justifications for decidedly
  unprovable checks, such as non-functional foreign-language calls) is counted
  neither as proved nor as unproved: `Proved = Total - Justified - Unproved`.
  Justified VCs do **not** downgrade the SPARK level; only unproved VCs
  do, and unit tests pin this.
- **Gold is the minimum compliance baseline. Platinum is the ideal.**
  `Min_SPARK_For` thresholds (A=Gold, B=Silver, C=Bronze, D/E=Stone) are the
  gate for DAL compliance. Platinum is achieved and reported only when the
  project has functional contracts, proves every one of them, and has full
  proof coverage: `Determine_SPARK_Level` also requires the SPARK coverage
  report (`Spark_Coverage.Analyze`, folded in by `Apply_To_Proof`) to show
  every assessed subprogram proved. A project that proves all of its flow,
  run-time, and assertion checks but carries no functional contracts, or that
  leaves subprograms outside the proof, is **not** Platinum. Platinum is a
  best-effort target, not a compliance requirement at any DAL level.

## Result caching

adacovex persists parsed analysis results on disk so unchanged inputs are not re-scanned, re-parsed, or re-proved. Source scans, GNATprove summaries, test summaries, `compliance/HLR.md`/`compliance/LLR.md` requirement parses, the resolved SBOM dependency graph, and the differential-mode scans are each keyed by a namespace prefix plus the SHA-256 of the artifact(s) they were derived from. For example: `"scan:" | "prove:" | "tests:" | "hlr:" | "llr:" | "graph:" + digest`. Re-parsing a byte-identical artifact yields a hit regardless of the target directory or command line.

An unchanged manifest/lockfile/.gpr set serves the cached dependency graph,
unchanged `compliance/HLR.md`/`compliance/LLR.md` serve the cached
requirement parses, and `--compare-base` / `--coverage-delta` reuse cached
source scans for the current tree.

- **Schema namespace**: the default cache root is
  `the result cache <version>/<Cache_Schema>`. `Cache_Schema` (in
  `src/core/adacovex-cache.ads`) is bumped whenever the serialized layout of a
  cached record or the scanner/parser semantics change, so blobs written by an
  incompatible build are never served as if valid. System-tool version probes
  are *not* under the result cache: they live in `<cache>/probes/` (a
  stable machine-level store; wiping the result cache must not re-probe every
  tool).
- **Graph key**: the dependency-graph key hashes the Alire manifests, the
  `alire.lock`, every `.gpr`, the vendored trees, and the root language mix.
  It also hashes the supported-language project manifests that can own a
  vendored directory (`package.json`, `Cargo.toml`, `Cargo.lock`, `go.mod`,
  `composer.json`, `Gemfile`, `pom.xml`, `pyproject.toml`, `Package.swift`,
  and the npm lockfiles) and every manifest that shapes the root declaration
  set (`pubspec.yaml`, `DESCRIPTION`, `META.json`, `setup.cfg`, `mix.exs`,
  `rebar.config`, `conanfile.py`, `conanfile.txt`, `build.gradle[.kts]`, and
  the package-named `*.csproj` / `*.gemspec` / `*.podspec` / `*.rockspec` /
  `*.opam` / `*.cabal`), so an edit to a test-labelled section, a lockfile,
  or a declared dependency invalidates the cached graph and the graph is
  rebuilt from the new content.
- **Per-unit proof entries**: `Adacovex.Prove_Units` gives every proof unit
  its own entry under the `proveunit:` namespace. A unit key covers its
  resolved path, its content, the content of the units its `with` closure
  names, the gnatprove options, and the prover identity. A one-unit edit
  invalidates that unit and the units that depend on it; every other unit
  entry stays a hit. The whole-run `prove:` entry remains the correctness
  gate, because gnatprove proves a project in one invocation: a run whose
  unit keys all hit restores the cached artefacts through the whole-run
  entry, and a partial edit reports the unit split and runs the prover once.
- **Entry header**: every entry starts with a 24-byte header, a format tag plus
  the write time in OS seconds. `Load` strips it before returning the payload,
  so callers see the bytes they stored. The header time, never the file mtime,
  is the entry's age: a CI cache restore or a file copy rewrites mtime, so an
  mtime rule would make an old entry look new. An entry without a header is
  never read, so `Cache_Schema` `s12` abandons the s11 era.
- **TTL**: a load older than `--cache-expiry` days (default `7`) is a miss and
  removes that entry; `0` means never expire. `[cache] expiry-days` sets the
  same value. Expiry runs before the count cap, so a stale entry is never
  counted as live.
- **Eviction**: `Put_Cached` evicts oldest-first by header time when more
  than `--cache-max` entries (default `4096`) accumulate. A file without a
  readable header falls back to its mtime. `Eviction_Count` tracks removals and
  is reported in the ANSI cache line.
- **Clear**: `adacovex --cache-clear` removes the resolved cache root and
  exits, printing the path and the entry count. It refuses a file-system root,
  the home directory, or an empty path, so a bad `--cache-dir` can never empty
  an unrelated tree.
- **Overflow safety**: `Serialize` returns an empty blob when a package is
   larger than `Max_Cache_Blob`, and `Deserialize` rejects empty/oversized
   input, so truncated data can never be served as a hit.
- **`--target` resolution**: `--target` resolves through
  `Adacovex.Paths.Resolve` (a relative path against the working directory,
  `~` expanded, `.`/`..` folded, separators unified) before any cache is
  read. Source scans, test summaries, requirement parses, the dependency
  graph, tool probes, registry metadata, and the proof cache all use that one
  resolved identity, so `prove`, `sbom`, and a plain assessment share their
  entries whether the run starts in the project, its parent, or anywhere
  else, provided the resolved project path is the same. The proof-cache key
  also resolves the root `.gpr`, and the per-unit keys resolve each unit
  path.
- **CI**: the GitHub action persists `<cache>` between workflow runs
  (`result-cache` input, default true).

### Shared directory snapshot

One assessment walks the target tree several times: the source scanner, the
tools-key hash, the graph-key language probe, the vendored discovery and
hash walks, the `.gpr` walk, and the complexity checker all enumerate the
same directories. `Adacovex.Dir_Cache` keeps one per-process snapshot per
directory, so the first walker enumerates a directory and every later walker
pays one mtime stat instead. The memo never touches disk, holds at most 256
directories, and serves a snapshot only while the directory's mtime is
unchanged.

A slot keeps its metadata (a key of up to 128 bytes, the mtime, the count) in
its first cache lines and its entry array after it. An entry is a packed
66-byte record: a 64-byte name, a one-byte length, and a one-byte kind. Up to
128 entries are recalled per directory, which covers the self tree's two
densest scanned directories (78 and 84 entries); the memo previously held 64,
and every walker re-enumerated those two.

A directory the memo cannot hold is reported as truncated, and the caller then
falls back to direct enumeration instead of trusting the snapshot. That
covers a directory with more entries than the memo holds and a directory
holding an entry name longer than 64 characters. A truncated directory must
never look empty, because every walker that trusts an empty snapshot skips the
whole subtree (version 1.49.0 fixed a `Adacovex.Dir_Cache.Snapshot` that
reported `Count => 0` with `Truncated => False` for an over-long entry name;
the fix is pinned by the Dir cache test category, which also pins the fitted
long name and the 100-entry directory since 1.63.0).

`--no-cache` bypasses the result cache entirely (useful when artifacts change
without their content hash changing, or to measure rescan cost) and
`--cache-dir` relocates it. The ANSI report shows a
`result cache: X hit(s), Y miss(es), Z evicted` line per run.
