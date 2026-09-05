# Architecture: outputs, pipeline, and delivery

This page covers the output formats, the build and documentation gates, the supported platforms and delivery channels, and the exact pipeline execution order.  The dependency and proof-level design is on [Architecture Decisions](architecture.md); the IR, DAL, scanning, and patch system are on [Architecture: verification and proof patches](architecture-verification.md).

## Output Formats

adacovex supports multiple output formats:

- **ANSI terminal report**: Colour-coded summary for interactive use.
  Colour is suppressed under CI, `NO_COLOR`, or `TERM=dumb`, so CI logs
  stay plain (see `Adacovex.Ansi` and its pure decision function
  `Colour_Allowed`)
- **SVG badges**: `spark.svg`, `tests.svg`, `docs.svg`, plus `do178c.svg` /
  `iso26262.svg` / `iec62304.svg` compliance badges (`--standard=all` emits all
  three) for CI badges
- **Markdown reports**: `VERIFICATION.md` and `TRACE.md` for compliance documentation
 - **HTML dashboard**: Interactive web dashboard with JSON API (`--serve`).
   It is standard-aware (defaults to all standards like `sbom`) with light/dark
   theme support (toggle button, respects `prefers-color-scheme`). The static
   page shell (CSS, header, theme script) is a real HTML file,
   `resources/dashboard.html`, bundled into the binary at build time.
   `tools/gen-dashboard.py` assembles the authored CSS (`resources/css/dashboard.css`),
   the authored JS (`resources/js/*.js`), and the vendored JavaScript
   libraries at the `resources/` root (`graphre.js`, `nomnoml.js`,
   `flexsearch.js`, `yace.js`) into a single minified page shell. The layout
   separates dependency JavaScript (`resources/` root) from authored dashboard
   JavaScript (`resources/js/`), which is also how the SBOM asset scanner
   tells vendored components from the project's own modules.

   The tool regenerates `src/adacovex-dashboard_template.ads` (a String
   constant, committed and byte-identical when unchanged).
   
   The Ada compiler includes that constant in the final binary. Every released
   binary - whether a GitHub release artifact or an Alire crate binary - carries
   the complete dashboard with no external file dependencies.
   
   At runtime, `Adacovex.Renderers.HTML.Render_Dashboard_Internal` only builds
   the dynamic card markup and injects it at the `__CARDS__` placeholder, filling
   the `__THEME__` initial-theme marker. The result is a single self-contained
   HTML document: no CDN, no network requests, works offline.
- **SBOM**: CycloneDX 1.5, SPDX 2.3, or Markdown format with proof, standard,
  and DAL/level properties

## Testing

adacovex uses a native zero-dependency test framework (`Adacovex.Test_Support`) with 1235 tests across 17 categories. No external test framework (AUnit, and more) is required. Test results are written to `docs/test_result.md` in a parseable Markdown table format.

## Complexity check

The `complexity` subcommand walks the whole target and scores many languages
(C, C++, C#, Go, Java, JavaScript, TypeScript, Python, Ruby, PHP, Rust,
Shell, Kotlin, and the YAML/JSON/TOML/XML/Markdown/reStructuredText
families) alongside Ada.  Per-subprogram analysis stays Ada-specific; the
other languages contribute file-level lines of code and decision counts.
`--excludes=EXT,EXT` skips listed file extensions and is rejected unless the
`complexity` subcommand is given, so it can never run on its own.  `make
complexity-check` gates the tree through the same thresholds.

## Timezone resolution

adacovex honours the operating system's timezone by default.  The resolved
offset comes from `Ada.Calendar.Time_Zones.UTC_Time_Offset`, the standard
Ada runtime, which reads the `TZ` variable and the system timezone through
the C library, so the default is always the operator's wall clock
(DST-aware).  `status` reports the effective timezone, the current date and
time in it, and how many dated release changelogs the target carries under
`docs/changelogs`.

`--tz` / `--timezone` override the display zone for one invocation.  The
value is either a well-known IANA name (for example `Asia/Singapore`) or a
fixed `UTC`/`GMT` offset (`UTC+8`, `GMT+8`, `UTC+08`, `GMT+08`,
`UTC+08:30`).  adacovex ships no timezone database, so a named zone
resolves from a built-in table of common IANA names and their standard-time
offsets.  A zone that may observe daylight saving time (marked in the
table), or one the table lacks, is probed against the platform tzdata
(`zdump` validates the name, `date +%z` reads the current offset, both
through one shell command) for the DST-correct offset; the table offset is
the fallback when the probe is unavailable.  The date/time rendering
compensates for GNAT's local-time calendar accessors, so the displayed wall
clock is correct in every zone.  `HLR-TZ` covers this behaviour.

## Build and documentation gates

Two cheap Python gates keep the dashboard and the hand-written docs in
step with the code, and both run inside `make check`:

- `tools/csslint.py` (`make csslint-check`) enforces the dashboard spacing
  convention: every `margin`, `padding`, and `gap` pixel length is a
  multiple of 4px.  It also runs inside `make build`.
- `tools/check-docs.py` (`make docs-check`) fails when any paragraph in the
  user docs, README, or human changelogs exceeds four sentences, and it
  rejects em dashes and Latin abbreviations (`i.e.`, `e.g.`, `etc.`).
  `tools/para-split.py` rewraps over-long paragraphs to comply.

The generated `docs/api-docs` pages are excluded from the paragraph rule;
its source docstrings carry the same rule.

## Supported Platforms

adacovex supports the same platforms Alire itself supports. Because Alire is
the packaging and delivery mechanism, adacovex inherits Alire's
supported-platform matrix. The crate builds via `alr build`. It is distributed
through the Alire community index (`alr install covex`). The release workflow
builds it with the Alire toolchain:

- **Binary distribution**: Linux x86-64, Windows x86-64, and macOS x86-64
  (the platforms for which Alire publishes binary releases and GNAT FSF
  toolchains, including cross compilers for ARM, RISC-V, and AVR).
- **From source**: any platform with a GNAT FSF 9.2+ compiler on which Alire
  can be built (Alire lists FreeBSD and OpenBSD among buildable hosts).
- **GitHub release bundles**: built on GitHub's Linux runners and distributed
  as `adacovex-vX.Y.Z.tar.gz` for every tag.

The GitHub Actions composite action pins `gnat-version` (default `16.1.0`) via
`alire-project/setup-alire`, and CI runs on `ubuntu-latest`, so the CI-verified
platform is Linux x86-64. The tool itself is written in portable Ada 2012 using
only the GNAT runtime, so no adacovex code is platform-specific beyond what the
GNAT runtime and Alire toolchain provide.

## Delivery and Versioning

adacovex follows one version across every delivery channel, and each channel is
version-locked to the same release:

- **Single source of truth**: the `version` field in `alire.toml` /
`alire-dev.toml` is the single source, resolved by installation method. `tools/gen-version.py` regenerates `src/adacovex_version_info.ads` at build time (and `make bump-version`). It reads the first available of `ADACOVEX_VERSION` (release builds), `alire-dev.toml` (source checkouts), or `alire.toml` (dependency-managed installs). For dependency-managed installs, the published crate builds from its release manifest, so the toml associated with the covex binary for dependency management carries the version. `Adacovex. Version` in `src/adacovex.ads` re-exports the version.

As a result, `--version`, the man page, the SBOM tool version, and the result-cache namespace all derive from the manifest and can never drift. Release builds bundle the release tag instead via the `ADACOVEX_VERSION` environment variable (release workflow / `make release`).

- **CI is tied to the release version**: the GitHub Actions composite action
(`action.yml`) is version-matched to the adacovex binary. The release workflow bundles `adacovex-vX. Y. Z.tar.gz` and `adacovex-action-vX.

Y. Z.tar.gz` for every `vX. Y. Z` tag, and the action downloads the binary for the tag it is referenced by (`@vX.

Y. Z` runs that exact version). Floating tags (`vMAJOR`, `vMAJOR. MINOR`, `latest`) are force-pushed at release time so `@latest` / `@v1` / `@v1.3` always resolve to the newest matching release.

- **CI platform/compiler**: CI validates the self-assessment (build, prove,
  tests) with the pinned `gnat-version` on `ubuntu-latest`, so the CI-proven
  combination is the released binary built against that exact toolchain.
- **Attestation**: every release bundle is attested with
  `actions/attest` (OIDC), and the release notes link the
  signed attestation.

## Build-time linker output (SFrame)

The Alire GNAT toolchain's bundled `ld` (2.44) emits a benign message
(`error in ...(.sframe); no .sframe will be created`) when it reads the
`.sframe` section that newer system binutils wrote into the glibc startup
objects. The link still succeeds. `make build` filters only this one message;
all compiler and gnatprove warnings remain fully visible, so nothing real is
ever suppressed.

## Read Only

adacovex itself is read-only. It merely scans your codebase for target docstrings and proofs.

It does not make edits in place or on your behalf.

## Flexible

adacovex lets you write proofs and decide where proofs are pointless (for
example code that has to involve manual memory management). You just have to
justify your rationale. The tool is not rigid. It does not expect 100% proving
for all use cases.

You write the proofs yourself, so there is no magic or hidden abstractions here.

## Pipeline (execution order)

When adacovex runs, it executes these steps in sequence:

 ```
0. Parse CLI args           -> CLI_Config record (prove / sbom / diff / man / complexity / normal)
0a. Early-exit modes        -> --help / --version / man / status / complexity exit before the pipeline
1. Determine ANSI color     -> NO_COLOR check
2. (prove mode) Run GNATprove -> fresh obj/gnatprove/gnatprove.out
3. Scan source files        -> Package_Vectors.Vector (subprograms, HLR tags, docstrings)
4. Apply docstring patches  -> Merge .adacovex/patches/ (strict mode only)
5. Compute doc metrics      -> Docstring_Metrics (coverage %)
6. Parse GNATprove output   -> Proof_Summary (VC counts, SPARK level)
7. Parse test results       -> Test_Summary (pass/fail counts)
8. Assess DAL compliance    -> DAL_Assessment (Achieved / Unmet + reasons)
9. Render ANSI summary      -> stdout (terminal report)
10. Emit SVG badges          -> <svg-dir>/*.svg (if enabled)
11. Emit Markdown reports    -> <md-dir>/VERIFICATION.md + TRACE.md (if enabled)
12. Emit automatic SBOM      -> <target>/sbom.json | sbom.spdx.json | docs/compliance/SBOM.md (unless --no-sbom)
13. Start HTTP server        -> :<port> (if --serve; serves the dashboard,
                               the JSON API, the SVG badges, and the bundled
                               offline manual at /docs)
14. Set exit code            -> 0 if Achieved, 1 if Unmet
```

Differential modes (`--compare-base` / `--coverage-delta`) run before the
pipeline and snapshot a base revision via `Adacovex.VCS` (git `worktree add`,
hg `archive`, svn `export`, fossil `open` on a copied DB, or a git worktree
against the jj store), assess base and current tree, report the delta, and
exit. `man` installs the generated man page (`Adacovex.Renderers.Man`) into
the local man database (`~/.local/share/man`, Linux/WSL) and refreshes it with
`mandb`.

## Swapping the GNAT compiler (LLVM backend)

adacovex and Alire both default to the GCC-based **GNAT** (`gnat_native`)
compiler. No action is needed. Only swap if you specifically want an
LLVM-backend GNAT (for example GNAT LLVM) for your target project -- for
example to exercise dissimilar redundancy via diverse code generation.

GNAT LLVM is **not** yet packaged as a standard Alire toolchain crate, so two
paths exist:

1. **Alire-managed compiler (preferred when available).** If a GNAT LLVM binary
   release becomes available in the Alire index, declare it in your
   `alire.toml` / `alire-dev.toml`:

   ```toml
   [[depends-on]]
   gnat_llvm = "*"
   ```

   `alr` then selects it automatically for that project's builds. You can also
   pick a default compiler for all projects with
   `alr toolchain --select --disable-assistant` and choosing the LLVM GNAT.

2. **System-installed GNAT LLVM.** Install GNAT LLVM on `$PATH`, then force the
   Ada toolchain in the root `.gpr` so `gprbuild` does not fall back to the
   GCC GNAT:

   ```gpr
   for Toolchain_Name ("Ada") use "GNAT_LLVM";
   ```

   You can confirm which compiler built a given `.ali` file by its first line
   (`GNAT` vs `GNAT-LLVM`).

Notes:

- GNAT LLVM and GCC GNAT are not guaranteed ABI-compatible. Compile all Ada in
   a project with the same compiler.
- GNAT LLVM's `-fstack-check` support is partial and some features
  (`Scalar_Storage_Order`, `Convention C++`) differ from GCC GNAT.
- SPARK proof results are compiler-independent, so `covex prove` and the
  DAL assessment are unaffected by the choice.
