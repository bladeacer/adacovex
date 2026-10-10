with Adacovex.Types;

--  SPARK proof-coverage report.
--  Reports three coverage metrics for an Ada project, grouped by
--  source file, by folder, or by Ada package, and classifies every
--  subprogram gnatprove did not prove into one of three off
--  classes.
--
--  The data is read from the two artefacts `make prove` already
--  writes. The report never runs the prover:
--
--    obj/gnatprove/gnatprove.out   the per-unit analysed/total
--                                      split and one `skipped;`
--                                      line per unproved entity,
--                                      with the reason
--                                      (SPARK_Mode => Off).
--    obj/gnatprove/gnatprove.sarif one result per reported check,
--                                      with the file and line it
--                                      belongs to and a `kind` of
--                                      "pass" or "open".
--
--  The three metrics (Adacovex.Types.Spark_Metric_Kind):
--
--    statement coverage   proved executable statements / all
--                         executable statements in the unit's body
--    subprogram coverage  proved subprograms / subprograms gnatprove
--                         considered in the unit
--    VC coverage          discharged checks / checks the prover
--                         reported
--
--  Each metric is reported twice per row: `proved / (proved +
--  off)`, which is how much of the SPARK-relevant surface is
--  verified and the number the opt-in sweep moves, and `proved /
--  total`, which is how much of the whole program is verified.
--  Every table header names its numerator and its denominator, and
--  the JSON output carries them as named fields, so a reader never
--  has to guess which ratio a percentage is.
--
--  Off classes (Adacovex.Types.Spark_Off_Class) are decided from
--  the source, never from a hand-maintained list:
--
--    Off_Irreducible  the unit carries an explicit `SPARK_Mode
--                     (Off)` pragma or aspect. That is the
--                     documented set of packages that instantiate a
--                     non-formal container and can never be in
--                     SPARK.
--    Off_IO_Bound     the skipped subprogram's own source references
--                     input or output (Ada.Text_IO, Ada.Directories,
--                     Ada.Environment_Variables, Ada.Command_Line,
--                     GNAT.OS_Lib) or spawns a process. The prover
--                     cannot analyse it at all, so off is correct
--                     and permanent.
--    Off_Work_Queue   any other skipped subprogram: default-off pure
--                     logic, provable in principle, and therefore
--                     the backlog.
--
--  Subprograms in units gnatprove never reported on are counted as
--  not covered. That is a real number, derived from the unit's
--  source, and is never folded into an off class.
--  HLR-SPARK: SPARK coverage report

package Adacovex.Spark_Coverage is

   --  Statement count of one Ada source line under the statement
   --  definition this report uses. The count is exact for one line
   --  in isolation, and the caller supplies the enclosing context
   --  (declarative or statement part) so declarations are never
   --  counted:
   --
   --    * one per Ada simple statement (assignment, procedure call,
   --      return, raise, exit, goto, null statement, delay) whose
   --      terminating ';' appears;
   --    * one per compound-statement head: if, elsif, else, case,
   --      when, while, for, loop, declare, begin, pragma;
   --    * zero for closing and connective keywords (end, then, is,
   --      in, renames, with, use, package, procedure, function,
   --      type, record, separate, others), for blank and comment
   --      lines, and for a continuation line of a statement that
   --      started earlier.
   --
   --  The count is an approximation of "executable statements": it
   --  needs no parse tree and it does not move when the compiler
   --  changes. The denominator it feeds is documented as this
   --  approximation, never as a COCOMO-style statement count.
   --  @param Line  One physical source line, comments included.
   --  @return The number of statements the line contributes.
   function Count_Line_Statements (Line : String) return Natural
   with Global => null;

   --  Whether one Ada source line carries an explicit
   --  `SPARK_Mode (Off)` pragma or aspect. Only a package that
   --  opts out deliberately does; a subprogram skipped because it
   --  reaches a non-formal container is not opted out here. Comment
   --  text is stripped first, so prose that discusses the pragma
   --  never counts.
   --  @param Line  One physical source line.
   --  @return True when the line declares an explicit SPARK_Mode
   --    (Off).
   function Line_Opts_Out (Line : String) return Boolean
   with Global => null;

   --  Whether the code part of one Ada source line performs input
   --  or output. It references Ada.Text_IO, Ada.Directories,
   --  Ada.Environment_Variables, Ada.Command_Line, or GNAT.OS_Lib,
   --  or it spawns a process. Comment text is stripped first, so a
   --  docstring that names a package never counts.
   --  @param Line  One physical source line.
   --  @return True when the line's code performs input or output.
   function Line_Is_IO_Bound (Line : String) return Boolean
   with Global => null;

   --  Numerator and denominator of one metric in the whole-tree
   --  rollup. A denominator of zero is reported as zero, never as
   --  a division by zero and never as 100 percent.
   --  @param Totals  Whole-tree rollup.
   --  @param M  Metric to select.
   --  @param Proved  Numerator (the verified count).
   --  @param Total  Denominator (the assessed count).
   procedure Metric_Values
     (Totals : Types.Implementation.Spark_Coverage_Totals;
      M      : Types.Spark_Metric_Kind;
      Proved : out Natural;
      Total  : out Natural)
   with Global => null;

   --  Numerator and denominator of one metric in a group rollup.
   --  Every count in a group is a sum over its member units, so a
   --  group percentage is always a ratio of sums and never a mean
   --  of its children. A denominator of zero is reported as zero.
   --  @param G  Group rollup.
   --  @param M  Metric to select.
   --  @param Proved  Numerator (the verified count).
   --  @param Total  Denominator (the assessed count).
   procedure Group_Values
     (G      : Types.Implementation.Spark_Coverage_Group;
      M      : Types.Spark_Metric_Kind;
      Proved : out Natural;
      Total  : out Natural)
   with Global => null;

   --  Build the whole report for the project rooted at Target_Dir.
   --  Proof_Dir holds the gnatprove artefacts; an empty string
   --  selects <target>/obj/gnatprove. The Ada source tree under
   --  Target_Dir supplies the statement counts.
   --  @param Target_Dir  Project root directory.
   --  @param Proof_Dir  Directory holding gnatprove.out and
   --    gnatprove.sarif, or "" for <target>/obj/gnatprove.
   --  @param Group  Row grouping selector.
   --  @param Units  Per-unit coverage records (appended to).
   --  @param Groups  Group rollups for Group (appended to).
   --  @param Totals  Whole-tree rollup.
   --  @param Skipped_Ct  Number of source files the statement scan
   --    could not read (line or path overflow, or unreadable).
   --  @param Proof_Ok  False when a proof artefact was missing or
   --    unreadable. The report is then not trustworthy and every
   --    gate must fail loudly.
   procedure Analyze
     (Target_Dir : String;
      Proof_Dir  : String;
      Group      : Types.Spark_Group_Kind;
      Units      : in out Types.Implementation.Spark_Coverage_Vectors.Vector;
      Groups     : in out Types.Implementation.Spark_Group_Vectors.Vector;
      Totals     : out Types.Implementation.Spark_Coverage_Totals;
      Skipped_Ct : out Natural;
      Proof_Ok   : out Boolean);

   --  Render the human-readable report. One overall block per
   --  metric, then one table per group. Every header names its
   --  numerator and its denominator.
   --  @param Totals  Whole-tree rollup.
   --  @param Groups  Group rollups for the selected grouping.
   --  @param Group  Row grouping selector (named in the header).
   --  @param Min_Pct  Rows whose verified percentage is below this
   --    are hidden. Zero shows every row.
   procedure Print_Report
     (Totals  : Types.Implementation.Spark_Coverage_Totals;
      Groups  : Types.Implementation.Spark_Group_Vectors.Vector;
      Group   : Types.Spark_Group_Kind;
      Min_Pct : Natural := 0);

   --  Render the machine-readable report. The JSON names every
   --  numerator and denominator as its own field instead of
   --  emitting bare percentages.
   --  @param Totals  Whole-tree rollup.
   --  @param Units  Per-unit coverage records.
   --  @param Groups  Group rollups for the selected grouping.
   --  @param Group  Row grouping selector.
   procedure Print_JSON
     (Totals : Types.Implementation.Spark_Coverage_Totals;
      Units  : Types.Implementation.Spark_Coverage_Vectors.Vector;
      Groups : Types.Implementation.Spark_Group_Vectors.Vector;
      Group  : Types.Spark_Group_Kind);

   --  The CI threshold-gate message for a metric that fell below
   --  its threshold. The message names the metric, its numerator,
   --  its denominator, and the achieved value, so the failure and
   --  the report above it can never be read as different
   --  quantities.
   --  @param Metric  Metric the gate applies to.
   --  @param Proved  Numerator (the verified count).
   --  @param Total  Denominator (the assessed count).
   --  @param Min_Pct  Required verified percentage.
   --  @param Msg  Output buffer receiving the message.
   --  @param Msg_Len  Length of the message in Msg.
   procedure Gate_Failure_Message
     (Metric  : Types.Spark_Metric_Kind;
      Proved  : Natural;
      Total   : Natural;
      Min_Pct : Natural;
      Msg     : out Types.Path_Field;
      Msg_Len : out Natural)
   with Global => null;

end Adacovex.Spark_Coverage;
