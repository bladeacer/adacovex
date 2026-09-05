--  Top-of-file opt-out annotation detection for per-file gate exclusions.
--  A source, documentation, or data file can carry a marker directive in
--  its leading comment block to opt out of one adacovex analysis gate.
--  The directive is a marker token on a comment line near the top of the
--  file (the first non-comment, non-blank line ends the header block, so
--  prose or code further down never counts).  The comment syntax follows
--  the file's own language:
--
--    --  no-covex-complexity-scan    (Ada: --, YAML/Python/Shell: #,
--    --  no-covex-docstrings          C-family: //, RST: .. , and so on)
--    --  no-covex-spark-proof         (opt the file out of the proof run)
--    <!-- no-covex-analysis -->       (Markdown/HTML comment also counts)
--
--  The recognised markers are:
--
--    no-covex-complexity-scan  opt the file out of the complexity/LOC gate
--    no-covex-docstrings       opt the file out of docstring coverage
--    no-covex-spark-proof      opt the file out of the SPARK proof run
--    no-covex-analysis         opt the file out of all three gates
--
--  Matching is case-insensitive and independent of the comment prefix, so
--  the same marker text works in Ada, Markdown, Python, Rust, and every
--  other scanned language.
--  HLR-SCAN: Per-file opt-out annotations

package Adacovex.Opt_Outs is

   --  The analysis gate a top-of-file marker can disable for one file.
   --  Complexity_Scan covers the cyclomatic-complexity/LOC gate
   --  (`adacovex complexity`).  Docstrings covers the docstring-coverage
   --  metrics and the --require-docstrings gate.  SPARK_Proof covers the
   --  gnatprove run and the proof metrics of the `prove` subcommand.
   type Gate is (Complexity_Scan, Docstrings, SPARK_Proof);

   --  True when the file at Path carries an opt-out marker for the given
   --  gate in its leading comment block.  Missing or unreadable files
   --  report False (never raise).  The header block is the run of blank
   --  and comment lines at the top of the file; the first non-comment,
   --  non-blank line ends it, and at most 24 physical lines are examined.
   --  @param Path  File path to inspect.
   --  @param G  Analysis gate to test for an opt-out marker.
   --  @return True when a matching marker appears in the file header.
   function File_Opts_Out (Path : String; G : Gate) return Boolean;

end Adacovex.Opt_Outs;
