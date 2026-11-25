package body Adacovex.Cli_Help is

   --  The alias, proof-tool, and spark-coverage descriptions, kept apart so
   --  Desc_Core stays under the cyclomatic cap as flags are added (the LOC
   --  gate rejects one god function).
   --  @param Flag  Flag name without its leading dashes.
   --  @return The description, or "" when this table does not own it.
   function Desc_Extra (Flag : String) return String is
   begin
      if Flag = "workers" then
         return "Alias for --serve-workers.";
      elsif Flag = "args" then
         return
           "Pass one extra argument to gnatprove, repeatable "
           & "(for example --args=--warnings=error).";
      elsif Flag = "skip-path" then
         return
           "With complexity: skip every file whose path contains "
           & "this fragment (repeatable, for example "
           & "--skip-path=docs/api-docs).";
      elsif Flag = "svg-path" then
         return "Alias for --emit-svg=PATH.";
      elsif Flag = "emit-md" then
         return "Alias for --emit-markdown=PATH.";
      elsif Flag = "md-path" then
         return "Alias for --emit-markdown=PATH.";
      elsif Flag = "no-md" then
         return
           "Suppress the Markdown report; it wins over " & "--emit-markdown.";
      elsif Flag = "strict" then
         return
           "Strict docstring mode, the default; the inverse of "
           & "--relaxed.";
      elsif Flag = "diff" then
         return "Alias for --compare-base.";
      elsif Flag = "base" then
         return "Alias for --compare-base.";
      elsif Flag = "delta" then
         return "Alias for --coverage-delta.";
      elsif Flag = "spark" then
         return "Alias for --require-spark.";
      elsif Flag = "docstrs" then
         return "Alias for --require-docstrings.";
      elsif Flag = "tests" then
         return "Alias for --require-tests.";
      elsif Flag = "spark-coverage" then
         return
           "Subcommand: report SPARK statement, subprogram, and VC "
           & "coverage from the gnatprove artefacts, and gate on it.";
      elsif Flag = "group" then
         return
           "With spark-coverage: row grouping, file | folder | "
           & "package (default: file).";
      elsif Flag = "metric" then
         return
           "With spark-coverage: summary metric, statements | "
           & "subprograms | vcs (default: statements).";
      elsif Flag = "spark-format" then
         return
           "With spark-coverage: report shape, text | json "
           & "(default: text).";
      elsif Flag = "min-coverage" then
         return
           "With spark-coverage: hide rows whose verified percentage "
           & "is below this value (default: 0, which shows all).";
      elsif Flag = "require-coverage" then
         return
           "CI gate: fail when the --gate-metric percentage is below "
           & "this value.";
      elsif Flag = "gate-metric" then
         return
           "Metric the --require-coverage gate applies to, statements "
           & "| subprograms | vcs (default: statements).";
      elsif Flag = "diagnostics" then
         return "Prove diagnostics shape, text | json (default: text).";
      else
         return "";
      end if;
   end Desc_Extra;

   function Desc_Core (Flag : String) return String is
   begin
      if Flag = "target" then
         return "Target project root directory (default: current directory).";
      elsif Flag = "manifest" then
         return "Override the target project manifest file.";
      elsif Flag = "dal" then
         return
           "DO-178C DAL level A|B|C|D|E (default: C; also the shared rigor tier).";
      elsif Flag = "asil" then
         return "ISO 26262 level A|B|C|D|QM (sets the standard and tier).";
      elsif Flag = "class" then
         return "IEC 62304 safety class A|B|C (sets the standard and tier).";
      elsif Flag = "standard" then
         return "do178c | iso26262 | iec62304 | all (default: do178c).";
      elsif Flag = "serve" then
         return
           "Switch: run the pipeline, then spawn the HTTP dashboard "
           & "server on the port (default 8080) and block.  Omit it to "
           & "render and exit without a server.  Standard-aware: "
           & "defaults to all standards.  Also see "
           & "--port/--theme/--serve-workers/--watch.";
      elsif Flag = "watch" or else Flag = "no-watch" then
         return
           "Refresh the served document metrics when the target's "
           & "sources change.  On by default for --serve; --no-watch "
           & "turns it off.  Only document and package metrics "
           & "refresh; proof, test, and compliance results keep the "
           & "values of the starting run.";
      elsif Flag = "serve-workers" then
         return
           "HTTP server task-pool worker count for --serve "
           & "(default 4, valid Positive, capped at 256).  Related "
           & "flag of --serve.";
      elsif Flag = "theme" then
         return
           "Dashboard theme: light | dark | system (default: system; only with --serve).";
      elsif Flag = "port" then
         return "HTTP server port for --serve (default: 8080).";
      elsif Flag = "emit-svg" then
         return
           "Write SVG badges to a directory (default <target>/docs/badges).";
      elsif Flag = "no-svg" then
         return "Suppress SVG badge output (overrides --emit-svg).";
      elsif Flag = "emit-markdown" then
         return "Write VERIFICATION.md and TRACE.md into a directory.";
      elsif Flag = "emit-metrics" then
         return "Write a JSON metrics + dependency graph export to a file.";
      elsif Flag = "skip-dir" then
         return "Add a directory to the relaxed-mode skip list (repeatable).";
      elsif Flag = "relaxed" then
         return "Disable strict mode (skip dirs, no patches).";
      elsif Flag = "cache" then
         return "Enable the on-disk result cache (default: on).";
      elsif Flag = "no-cache" then
         return "Disable the on-disk result cache (always re-scan).";
      elsif Flag = "cache-dir" then
         return "Relocate the result cache directory.";
      elsif Flag = "cache-max" then
         return "Cap the result cache entry count (default: 4096).";
      elsif Flag = "cache-expiry" then
         return
           "Cache entry lifetime in days (default: 7; 0 = never " & "expire).";
      elsif Flag = "cache-clear" then
         return
           "Remove every cache entry, print the path and count, and "
           & "exit.";
      elsif Flag = "compare-base" then
         return
           "Differential mode: compare against a base "
           & "revision (git/hg/svn/fossil/jj) and report the "
           & "VC/DAL delta.";
      elsif Flag = "coverage-delta" then
         return
           "Docstring-coverage gate: exit non-zero if current coverage is below the base revision.";
      elsif Flag = "verbose" then
         return "Verbose diagnostics on stderr.";
      elsif Flag = "no-sbom" then
         return
           "Skip the automatic SBOM generated at the end of every assessment.";
      elsif Flag = "sbom-format" or Flag = "format" then
         return
           "SBOM format for the automatic SBOM: cyclonedx-json | spdx-json | md (default: cyclonedx-json).";
      elsif Flag = "out" then
         return
           "SBOM output path for the sbom subcommand (default: <target>/sbom.json).";
      elsif Flag = "jobs" then
         return "GNATprove parallelism -j N (default: auto).";
      elsif Flag = "level" then
         return
           "GNATprove proof effort 0-4 (default: 4, the deepest" & " effort).";
      elsif Flag = "timeout" then
         return "Per-check prover timeout in seconds.";
      elsif Flag = "steps" then
         return "Max proof steps (default: 10000).";
      elsif Flag = "memlimit" then
         return "Prover memory limit in MB.";
      elsif Flag = "force" then
         return "Force full gnatprove reanalysis and man page reinstall.";
      elsif Flag = "no-loop-unrolling" then
         return
           "Disable automatic loop unrolling (always on for prove; kept for compat).";
      elsif Flag = "no-inlining" then
         return "Disable contextual analysis inlining.";
      elsif Flag = "counterexamples" then
         return
           "Ask the prover for a breaking input on every failed"
           & " check (on by default; off skips the search).";
      elsif Flag = "suppress-warnings" then
         return
           "Suppress GNATprove benign info messages (--suppress-warnings[=SETS]).";
      elsif Flag = "quiet" then
         return "Alias for --suppress-warnings (the default set).";
      elsif Flag = "require-spark" then
         return "CI gate: fail loudly if SPARK level < LVL (Stone..Platinum).";
      elsif Flag = "require-docstrings" then
         return "CI gate: fail loudly if docstring coverage < PCT% (0-100).";
      elsif Flag = "require-tests" then
         return "CI gate: fail loudly if passing test count < N.";
      elsif Flag = "require-proof" then
         return "CI gate: fail loudly if proved-VC coverage < PCT% (0-100).";
      elsif Flag = "fail-on" then
         return
           "CI policy gate over spark, docstrings, proof, tests, or"
           & " coverage (DIM[=VAL], comma-separated or repeatable).";
      elsif Flag = "coverage" then
         return
           "Show the proof-coverage summary after a successful prove (on by default).";
      elsif Flag = "no-coverage" then
         return
           "Hide the proof-coverage summary after prove (also [prove] coverage = false).";
      elsif Flag = "help" then
         return "Show help and exit (also 'adacovex help <topic>').";
      elsif Flag = "version" then
         return "Print the bundled version and exit.";
      elsif Flag = "sbom" then
         return
           "Subcommand: generate a proof-aware SBOM (see also --sbom-format/--format/--out).";
      elsif Flag = "prove" then
         return
           "Subcommand: run GNATprove then assess (see --jobs/--level/...).";
      elsif Flag = "status" then
         return "Subcommand: report toolkit + platform status.";
      elsif Flag = "export" then
         return
           "With status: write the report as JSON to PATH "
           & "(or stdout when no path is given).";
      elsif Flag = "metrics" then
         return
           "With status: print compact key=value metrics "
           & "lines for shell scripts.";
      elsif Flag = "completion" then
         return
           "Subcommand: print shell completion script (bash/fish/zsh/pwsh).";
      elsif Flag = "man" then
         return
           "Subcommand: install the man page into the local man database.";
      elsif Flag = "tldr" then
         return
           "Subcommand: install the bundled tldr page into the local "
           & "tldr client.";
      elsif Flag = "check" then
         return
           "Man subcommand flag: --check exits 0 when installed page matches binary.";
      elsif Flag = "dir" then
         return "Man subcommand flag: --dir=PATH installs under PATH/man1.";
      elsif Flag = "complexity" then
         return
           "Subcommand: cyclomatic-complexity and LOC gate across the "
           & "target's source files.  Use --excludes to skip extensions.";
      elsif Flag = "excludes" then
         return
           "Comma-separated file extensions to skip in --complexity "
           & "scans (for example md,rst).";
      elsif Flag = "tz" or Flag = "timezone" then
         return
           "Display timezone for reports: an IANA name (Europe/London) "
           & "or a UTC/GMT offset (UTC+2, GMT-5).";
      else
         return "";
      end if;
   end Desc_Core;

   --  The full description of one option: the core table first, then the
   --  alias and proof-tool table.
   --  @param Flag  Option name without its leading dashes.
   --  @return Description text, or "" for an unknown option.
   function Describe (Flag : String) return String is
      Core : constant String := Desc_Core (Flag);
   begin
      if Core'Length > 0 then
         return Core;
      end if;
      return Desc_Extra (Flag);
   end Describe;

   --  The heading of one group, with its trailing colon.
   --  @param G  Option group.
   --  @return Heading text, for example "Assess:".
   function Heading (G : Option_Group) return String is
   begin
      case G is
         when Group_Assess =>
            return "Assess:";

         when Group_Report =>
            return "Report:";

         when Group_Prove  =>
            return "Prove:";

         when Group_Scope  =>
            return "Cache and scope:";

         when Group_CI     =>
            return "CI gates:";

         when Group_Diff   =>
            return "Differential and SBOM:";

         when Group_More   =>
            return "More detail:";
      end case;
   end Heading;

   --  The group an option belongs to. The order of the branches follows how
   --  often a user reaches for each area, and an option the table does not
   --  place lands in Group_More.
   --  @param Flag  Option name without its leading dashes.
   --  @return The group the man page files the option under.
   function Group_Of (Flag : String) return Option_Group is
   begin
      if Flag = "target"
        or else Flag = "manifest"
        or else Flag = "dal"
        or else Flag = "asil"
        or else Flag = "class"
        or else Flag = "standard"
        or else Flag = "status"
        or else Flag = "export"
        or else Flag = "metrics"
      then
         return Group_Assess;
      elsif Flag = "serve"
        or else Flag = "theme"
        or else Flag = "port"
        or else Flag = "serve-workers"
        or else Flag = "workers"
        or else Flag = "watch"
        or else Flag = "no-watch"
        or else Flag = "emit-svg"
        or else Flag = "no-svg"
        or else Flag = "svg-path"
        or else Flag = "emit-markdown"
        or else Flag = "emit-md"
        or else Flag = "md-path"
        or else Flag = "no-md"
        or else Flag = "emit-metrics"
        or else Flag = "tz"
        or else Flag = "timezone"
        or else Flag = "verbose"
      then
         return Group_Report;
      elsif Flag = "prove"
        or else Flag = "jobs"
        or else Flag = "level"
        or else Flag = "timeout"
        or else Flag = "steps"
        or else Flag = "memlimit"
        or else Flag = "force"
        or else Flag = "no-loop-unrolling"
        or else Flag = "no-inlining"
        or else Flag = "counterexamples"
        or else Flag = "args"
        or else Flag = "suppress-warnings"
        or else Flag = "quiet"
        or else Flag = "coverage"
        or else Flag = "no-coverage"
        or else Flag = "diagnostics"
      then
         return Group_Prove;
      elsif Flag = "cache"
        or else Flag = "no-cache"
        or else Flag = "cache-dir"
        or else Flag = "cache-max"
        or else Flag = "cache-expiry"
        or else Flag = "cache-clear"
        or else Flag = "relaxed"
        or else Flag = "strict"
        or else Flag = "skip-dir"
        or else Flag = "excludes"
        or else Flag = "skip-path"
        or else Flag = "complexity"
        or else Flag = "spark-coverage"
        or else Flag = "group"
        or else Flag = "metric"
        or else Flag = "spark-format"
        or else Flag = "min-coverage"
        or else Flag = "require-coverage"
        or else Flag = "gate-metric"
      then
         return Group_Scope;
      elsif Flag = "require-spark"
        or else Flag = "spark"
        or else Flag = "require-docstrings"
        or else Flag = "docstrs"
        or else Flag = "require-tests"
        or else Flag = "tests"
        or else Flag = "require-proof"
        or else Flag = "fail-on"
      then
         return Group_CI;
      elsif Flag = "sbom"
        or else Flag = "no-sbom"
        or else Flag = "sbom-format"
        or else Flag = "format"
        or else Flag = "out"
        or else Flag = "compare-base"
        or else Flag = "diff"
        or else Flag = "base"
        or else Flag = "coverage-delta"
        or else Flag = "delta"
      then
         return Group_Diff;
      else
         return Group_More;
      end if;
   end Group_Of;

end Adacovex.Cli_Help;
