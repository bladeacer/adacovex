# Adacovex.Spark_Coverage

SPARK proof-coverage report.
Reports three coverage metrics for an Ada project, grouped by
source file, by folder, or by Ada package, and classifies every
subprogram gnatprove did not prove into one of three off
classes.

The data is read from the two artefacts ``make prove`` already
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

| Parameter | Description |
|-----------|-------------|
| `Line` | One physical source line, comments included. |

**Returns:** The number of statements the line contributes.

### function Line_Is_IO_Bound (Line : Standard.String) return Standard.Boolean `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Line` | One physical source line. |

**Returns:** True when the line's code performs input or output.

### function Line_Opts_Out (Line : Standard.String) return Standard.Boolean `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Line` | One physical source line. |

**Returns:** True when the line declares an explicit SPARK_Mode

## Procedures

### procedure Analyze (Target_Dir : Standard.String; Proof_Dir : Standard.String; Group : Adacovex.Types.Spark_Group_Kind; Units : Adacovex.Types.Implementation.Spark_Coverage_Vectors.Vector; Groups : Adacovex.Types.Implementation.Spark_Group_Vectors.Vector; Totals : Adacovex.Types.Implementation.Spark_Coverage_Totals; Skipped_Ct : Standard.Natural; Proof_Ok : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Group` | Row grouping selector. |
| `Groups` | Group rollups for Group (appended to). |
| `Proof_Dir` | Directory holding gnatprove.out and |
| `Proof_Ok` | False when a proof artefact was missing or |
| `Skipped_Ct` | Number of source files the statement scan |
| `Target_Dir` | Project root directory. |
| `Totals` | Whole-tree rollup. |
| `Units` | Per-unit coverage records (appended to). |

### procedure Gate_Failure_Message (Metric : Adacovex.Types.Spark_Metric_Kind; Proved : Standard.Natural; Total : Standard.Natural; Min_Pct : Standard.Natural; Msg : Adacovex.Types.Path_Field; Msg_Len : Standard.Natural) `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Metric` | Metric the gate applies to. |
| `Min_Pct` | Required verified percentage. |
| `Msg` | Output buffer receiving the message. |
| `Msg_Len` | Length of the message in Msg. |
| `Proved` | Numerator (the verified count). |
| `Total` | Denominator (the assessed count). |

### procedure Group_Values (G : Adacovex.Types.Implementation.Spark_Coverage_Group; M : Adacovex.Types.Spark_Metric_Kind; Proved : Standard.Natural; Total : Standard.Natural) `[Global]`

| Parameter | Description |
|-----------|-------------|
| `G` | Group rollup. |
| `M` | Metric to select. |
| `Proved` | Numerator (the verified count). |
| `Total` | Denominator (the assessed count). |

### procedure Metric_Values (Totals : Adacovex.Types.Implementation.Spark_Coverage_Totals; M : Adacovex.Types.Spark_Metric_Kind; Proved : Standard.Natural; Total : Standard.Natural) `[Global]`

| Parameter | Description |
|-----------|-------------|
| `M` | Metric to select. |
| `Proved` | Numerator (the verified count). |
| `Total` | Denominator (the assessed count). |
| `Totals` | Whole-tree rollup. |

### procedure Print_JSON (Totals : Adacovex.Types.Implementation.Spark_Coverage_Totals; Units : Adacovex.Types.Implementation.Spark_Coverage_Vectors.Vector; Groups : Adacovex.Types.Implementation.Spark_Group_Vectors.Vector; Group : Adacovex.Types.Spark_Group_Kind)

| Parameter | Description |
|-----------|-------------|
| `Group` | Row grouping selector. |
| `Groups` | Group rollups for the selected grouping. |
| `Totals` | Whole-tree rollup. |
| `Units` | Per-unit coverage records. |

### procedure Print_Report (Totals : Adacovex.Types.Implementation.Spark_Coverage_Totals; Groups : Adacovex.Types.Implementation.Spark_Group_Vectors.Vector; Group : Adacovex.Types.Spark_Group_Kind; Min_Pct : Standard.Natural)

| Parameter | Description |
|-----------|-------------|
| `Group` | Row grouping selector (named in the header). |
| `Groups` | Group rollups for the selected grouping. |
| `Min_Pct` | Rows whose verified percentage is below this |
| `Totals` | Whole-tree rollup. |
