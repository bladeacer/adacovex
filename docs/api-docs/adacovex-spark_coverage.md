# Adacovex.Spark_Coverage

SPARK proof-coverage report.
Reports three coverage metrics for an Ada project, grouped by
source file, by folder, or by Ada package, and classifies every
subprogram gnatprove did not prove into one of three off
classes.

The data is read from the two artefacts ``just prove`` already
writes. The report never runs the prover:

  obj/gnatprove/gnatprove.out   the per-unit analysed/total
split and one ``skipped;``
line per unproved entity,
with the reason
(SPARK_Mode => Off).
obj/gnatprove/gnatprove.sarif one result per reported check,
with the file and line it
belongs to and a ``kind`` of
"pass" or "open".

The three metrics (Adacovex.Types.Spark_Metric_Kind):

  statement coverage   proved executable statements / all
executable statements in the unit's body
subprogram coverage  proved subprograms / subprograms gnatprove
considered in the unit
VC coverage          discharged checks / checks the prover
reported

Each metric is reported twice per row: ``proved / (proved +
off)``, which is how much of the SPARK-relevant surface is
verified and the number the opt-in sweep moves, and ``proved /
total``, which is how much of the whole program is verified.
Every table header names its numerator and its denominator, and
the JSON output carries them as named fields, so a reader never
has to guess which ratio a percentage is.

Off classes (Adacovex.Types.Spark_Off_Class) are decided from
the source, never from a hand-maintained list:

  Off_Irreducible  the unit carries an explicit ``SPARK_Mode
                   (Off)`` pragma or aspect. That is the
documented set of packages that instantiate a
non-formal container and can never be in
SPARK.
Off_IO_Bound     the skipped subprogram's own source references
input or output (Ada.Text_IO, Ada.Directories,
Ada.Environment_Variables, Ada.Command_Line,
GNAT.OS_Lib) or spawns a process. The prover
cannot analyse it at all, so off is correct
and permanent.
Off_Work_Queue   any other skipped subprogram: default-off pure
logic, provable in principle, and therefore
the backlog.

Subprograms in units gnatprove never reported on are counted as
not covered. That is a real number, derived from the unit's
source, and is never folded into an off class.
HLR-SPARK: SPARK coverage report

> **Note:** All items in this package are public.

## Functions

### function Count_Line_Statements (Line : Standard.String) return Standard.Natural `[Global]`

> Statement count of one Ada source line under the statement definition this report uses. The count is exact for one line in isolation, and the caller supplies the enclosing context (declarative or statement part) so declarations are never counted: * one per Ada simple statement (assignment, procedure call, return, raise, exit, goto, null statement, delay) whose terminating ';' appears; * one per compound-statement head: if, elsif, else, case, when, while, for, loop, declare, begin, pragma; * zero for closing and connective keywords (end, then, is, in, renames, with, use, package, procedure, function, type, record, separate, others), for blank and comment lines, and for a continuation line of a statement that started earlier. The count is an approximation of "executable statements": it needs no parse tree and it does not move when the compiler changes. The denominator it feeds is documented as this approximation, never as a COCOMO-style statement count.

| Parameter | Description |
|-----------|-------------|
| `Line` | One physical source line, comments included. |

**Returns:** The number of statements the line contributes.

### function Line_Is_IO_Bound (Line : Standard.String) return Standard.Boolean `[Global]`

> Whether the code part of one Ada source line performs input or output. It references Ada.Text_IO, Ada.Directories, Ada.Environment_Variables, Ada.Command_Line, or GNAT.OS_Lib, or it spawns a process. Comment text is stripped first, so a docstring that names a package never counts.

| Parameter | Description |
|-----------|-------------|
| `Line` | One physical source line. |

**Returns:** True when the line's code performs input or output.

### function Line_Opts_Out (Line : Standard.String) return Standard.Boolean `[Global]`

> Whether one Ada source line carries an explicit `SPARK_Mode (Off)` pragma or aspect. Only a package that opts out deliberately does; a subprogram skipped because it reaches a non-formal container is not opted out here. Comment text is stripped first, so prose that discusses the pragma never counts.

| Parameter | Description |
|-----------|-------------|
| `Line` | One physical source line. |

**Returns:** True when the line declares an explicit SPARK_Mode (Off).

## Procedures

### procedure Analyze (Target_Dir : Standard.String; Proof_Dir : Standard.String; Group : Adacovex.Types.Spark_Group_Kind; Units : Adacovex.Types.Implementation.Spark_Coverage_Vectors.Vector; Groups : Adacovex.Types.Implementation.Spark_Group_Vectors.Vector; Totals : Adacovex.Types.Implementation.Spark_Coverage_Totals; Skipped_Ct : Standard.Natural; Proof_Ok : Standard.Boolean)

> Build the whole report for the project rooted at Target_Dir. Proof_Dir holds the gnatprove artefacts; an empty string selects <target>/obj/gnatprove. The Ada source tree under Target_Dir supplies the statement counts.

| Parameter | Description |
|-----------|-------------|
| `Group` | Row grouping selector. |
| `Groups` | Group rollups for Group (appended to). |
| `Proof_Dir` | Directory holding gnatprove.out and gnatprove.sarif, or "" for <target>/obj/gnatprove. |
| `Proof_Ok` | False when a proof artefact was missing or unreadable. The report is then not trustworthy and every gate must fail loudly. |
| `Skipped_Ct` | Number of source files the statement scan could not read (line or path overflow, or unreadable). |
| `Target_Dir` | Project root directory. |
| `Totals` | Whole-tree rollup. |
| `Units` | Per-unit coverage records (appended to). |

### procedure Apply_To_Proof (Totals : Adacovex.Types.Implementation.Spark_Coverage_Totals; Proof_Ok : Standard.Boolean; Proof : Adacovex.Types.Proof_Summary) `[Pre]`

> Fold a coverage rollup into an assessment's proof summary and re-derive its SPARK level. Platinum requires full proof coverage -- every subprogram the report assesses proved -- so the level cannot be decided from gnatprove.out alone. An assessment that never measures the coverage report therefore never claims Platinum.

| Parameter | Description |
|-----------|-------------|
| `Proof` | Proof summary to update (level re-derived). |
| `Proof_Ok` | Whether Analyze read both proof artefacts. |
| `Totals` | Whole-tree rollup from Analyze. |

### procedure Gate_Failure_Message (Metric : Adacovex.Types.Spark_Metric_Kind; Proved : Standard.Natural; Total : Standard.Natural; Min_Pct : Standard.Natural; Msg : Adacovex.Types.Path_Field; Msg_Len : Standard.Natural) `[Global]`

> The CI threshold-gate message for a metric that fell below its threshold. The message names the metric, its numerator, its denominator, and the achieved value, so the failure and the report above it can never be read as different quantities.

| Parameter | Description |
|-----------|-------------|
| `Metric` | Metric the gate applies to. |
| `Min_Pct` | Required verified percentage. |
| `Msg` | Output buffer receiving the message. |
| `Msg_Len` | Length of the message in Msg. |
| `Proved` | Numerator (the verified count). |
| `Total` | Denominator (the assessed count). |

### procedure Group_Values (G : Adacovex.Types.Implementation.Spark_Coverage_Group; M : Adacovex.Types.Spark_Metric_Kind; Proved : Standard.Natural; Total : Standard.Natural) `[Global]`

> Numerator and denominator of one metric in a group rollup. Every count in a group is a sum over its member units, so a group percentage is always a ratio of sums and never a mean of its children. A denominator of zero is reported as zero.

| Parameter | Description |
|-----------|-------------|
| `G` | Group rollup. |
| `M` | Metric to select. |
| `Proved` | Numerator (the verified count). |
| `Total` | Denominator (the assessed count). |

### procedure Metric_Values (Totals : Adacovex.Types.Implementation.Spark_Coverage_Totals; M : Adacovex.Types.Spark_Metric_Kind; Proved : Standard.Natural; Total : Standard.Natural) `[Global]`

> Numerator and denominator of one metric in the whole-tree rollup. A denominator of zero is reported as zero, never as a division by zero and never as 100 percent.

| Parameter | Description |
|-----------|-------------|
| `M` | Metric to select. |
| `Proved` | Numerator (the verified count). |
| `Total` | Denominator (the assessed count). |
| `Totals` | Whole-tree rollup. |

### procedure Print_JSON (Totals : Adacovex.Types.Implementation.Spark_Coverage_Totals; Units : Adacovex.Types.Implementation.Spark_Coverage_Vectors.Vector; Groups : Adacovex.Types.Implementation.Spark_Group_Vectors.Vector; Group : Adacovex.Types.Spark_Group_Kind)

> Render the machine-readable report. The JSON names every numerator and denominator as its own field instead of emitting bare percentages.

| Parameter | Description |
|-----------|-------------|
| `Group` | Row grouping selector. |
| `Groups` | Group rollups for the selected grouping. |
| `Totals` | Whole-tree rollup. |
| `Units` | Per-unit coverage records. |

### procedure Print_Report (Totals : Adacovex.Types.Implementation.Spark_Coverage_Totals; Groups : Adacovex.Types.Implementation.Spark_Group_Vectors.Vector; Group : Adacovex.Types.Spark_Group_Kind; Min_Pct : Standard.Natural)

> Render the human-readable report. One overall block per metric, then one table per group. Every header names its numerator and its denominator.

| Parameter | Description |
|-----------|-------------|
| `Group` | Row grouping selector (named in the header). |
| `Groups` | Group rollups for the selected grouping. |
| `Min_Pct` | Rows whose verified percentage is below this are hidden. Zero shows every row. |
| `Totals` | Whole-tree rollup. |
