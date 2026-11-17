# Adacovex.Prove_Output

Diagnostics and output for the ``adacovex prove`` subcommand.

This package owns the proof finding model, the pass that reads a captured
gnatprove stream, the rendered diagnostics block, the GitHub Actions
annotation shape, and the quiet replay printer. The prove runner keeps
only the orchestration: resolve gnatprove, run it, and call these
subprograms. Keeping the I/O-heavy report layer here also keeps
``adacovex-prove.adb`` inside its cyclomatic-complexity budget.

A local prove run is concise: the captured prover output is replayed as
one framed block, with severity colours and a diagnostics block for
unproved checks. A warm cache hit replays the text that run produced, so
cached and fresh output agree.
HLR-PROVE: Proof diagnostics

> **Note:** All items in this package are public.

## Types

### type Failure_Array

```ada
type Failure_Array is array (1 .. Max_Failure_Items) of Prove_Failure;
```

> The fixed finding array one diagnostics pass fills, in stream order.

### type Failure_Stats

```ada
type Failure_Stats is record
Unproved : Natural := 0;
Count    : Natural := 0;
Items    : Failure_Array;
end record;
```

> Counts gathered by one diagnostics pass over a captured gnatprove output file. Unproved is every unproved finding the stream carried and Count is how many of them Items names, so a reader sees both the scale of the failure and the first locations to fix.

### type Prove_Failure

```ada
type Prove_Failure is record
Location       : Ada.Strings.Unbounded.Unbounded_String :=
Ada.Strings.Unbounded.Null_Unbounded_String;
Kind           : Ada.Strings.Unbounded.Unbounded_String :=
Ada.Strings.Unbounded.Null_Unbounded_String;
Flow           : Boolean := False;
Budget         : Boolean := False;
Solver         : Ada.Strings.Unbounded.Unbounded_String :=
Ada.Strings.Unbounded.Null_Unbounded_String;
Counterexample : Ada.Strings.Unbounded.Unbounded_String :=
Ada.Strings.Unbounded.Null_Unbounded_String;
Call_Sites     : Natural := 1;
end record;
```

> One unproved finding of a proof run, gathered from the captured gnatprove stream.

## Functions

### function Annotation_Line (Location : Standard.String; Kind : Standard.String) return Standard.String

> Build the GitHub Actions workflow command for one unproved finding. The location gnatprove prints is `file:line:column`, so the trailing fields are split off and the result is `::error file=...,line=...,col=...,title=SPARK proof failed::<kind>`. A location without a column still yields an annotation (the `col` field is omitted). A location that cannot be split returns the empty string, so a malformed finding is never emitted as an empty file annotation. The function is pure: emitting is the caller's job.

| Parameter | Description |
|-----------|-------------|
| `Kind` | Check kind (for example "range check"). |
| `Location` | Source location as Collect_Failures recorded it. |

**Returns:** The workflow command, or "" when the location is malformed.

### function Diagnostics_Json (Prover : Standard.String; Stats : Adacovex.Prove_Output.Failure_Stats; Source_Root : Standard.String) return Standard.String

> Render the same findings as one JSON object, so a CI job or a script can read the facts without parsing prose. It carries the prover identity, the unproved count, and one entry per named finding with its location, line, column, kind, solver, counterexample, flow and budget flags, call-site count, source excerpt, and fix hint. It is empty when the run left no finding.

| Parameter | Description |
|-----------|-------------|
| `Prover` | The resolved prover identity, or "". |
| `Source_Root` | Directory the finding locations are relative to. |
| `Stats` | Findings gathered by Collect_Failures. |

**Returns:** One JSON object, or "" when there is nothing to report.

### function Diagnostics_Text (Prover : Standard.String; Stats : Adacovex.Prove_Output.Failure_Stats; Source_Root : Standard.String) return Standard.String

> Render the diagnostics block for a proof run that left unproved checks: how many, which prover produced them, the first check locations with their kinds, and a one-line fix hint derived from the first check's kind. It is empty when the run left no finding, so a clean run prints nothing. Lines end with a line feed and the last line is the hint, so the caller can print the result as one block.

| Parameter | Description |
|-----------|-------------|
| `Prover` | The resolved prover identity (version or path), or "" when it is not known. |
| `Source_Root` | Directory the finding locations are relative to, or "" to omit the source excerpt line. |
| `Stats` | Findings gathered by Collect_Failures. |

**Returns:** The diagnostics block, or "" when there is nothing to report.

## Procedures

### procedure Append_Text (Path : Standard.String; Text : Standard.String)

> Append one text block to a replay file. An empty block appends nothing. Used to put the diagnostics block after the replay in the text that is printed and cached.

| Parameter | Description |
|-----------|-------------|
| `Path` | Replay text file. |
| `Text` | Text to append (line feeds included). |

### procedure Cache_Replay (Key : Standard.String; Path : Standard.String)

> Cache a replay file as plain text under Key. A replay larger than the cache blob is not cached: the file was already printed, so only the warm-cache convenience is lost.

| Parameter | Description |
|-----------|-------------|
| `Key` | Cache key (already namespaced by the caller). |
| `Path` | Replay text file. |

### procedure Collect_Failures (Path : Standard.String; Stats : Adacovex.Prove_Output.Failure_Stats; Summary_Path : Standard.String)

> Collect the actionable failure detail of a captured gnatprove stream: the location and check kind of every unproved check, and of every flow finding that names an uninitialized object. A prover failure line has the shape unit.adb:54:08: medium: postcondition might fail and a flow finding the shape unit.adb:31:05: "X" is not initialized so the pass keeps the location, strips the optional severity word, and derives the kind from the message. Every other line is ignored: a line without a `file:line:column` prefix is not a finding, and a finding that reports a proof outcome rather than a failure is not one to act on. A check counts once per source location and check kind once the `, in call inlined at ...` suffix is removed: the prover can report one check once per inlined call site, so a repeated finding is not double-counted. The repeat count is kept in Call_Sites. The seen table is bounded, and a stream with more distinct findings than it holds keeps its later repeats.

| Parameter | Description |
|-----------|-------------|
| `Path` | Captured gnatprove output file to read. |
| `Stats` | Findings gathered during the pass. |
| `Summary_Path` | Gnatprove summary (gnatprove.out) whose prover column attributes a prover set to each category. Empty when the summary is not available. |

### procedure Emit_Annotations (Stats : Adacovex.Prove_Output.Failure_Stats)

> Emit one annotation per distinct finding when running in GitHub Actions. A local run prints nothing here, so the diagnostics block stays the only failure detail.

| Parameter | Description |
|-----------|-------------|
| `Stats` | Findings gathered by Collect_Failures. |

### procedure Print_Cached_Replay (Key : Standard.String)

> Print the cached replay stored under Key, when one exists. This is the warm-cache path that keeps a cached run and a fresh run in agreement.

| Parameter | Description |
|-----------|-------------|
| `Key` | Cache key (already namespaced by the caller). |

### procedure Print_Replay_Blob (S : Standard.String)

> Print replay text line by line with a severity colour: errors red, warnings yellow, notices and their locations dim, a success line green, and the summary footers bold. Colour is already a no-op under CI, NO_COLOR, or a dumb terminal (Adacovex.Ansi.Wrap), so a log stays plain text. The text is the plain, cached form (no escape codes are stored), so a CI log or a later warm hit never inherits a colour decision made on another terminal.

| Parameter | Description |
|-----------|-------------|
| `S` | Replay text, with line feeds between lines. |

### procedure Print_Replay_File (Path : Standard.String)

> Print a replay file line by line. This is the shape a fresh run uses, and the fallback when a replay does not fit the cache blob.

| Parameter | Description |
|-----------|-------------|
| `Path` | Replay text file. |
