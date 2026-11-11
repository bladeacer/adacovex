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

### type Failure_Stats

```ada
type Failure_Stats is record
Unproved : Natural := 0;
Count    : Natural := 0;
Items    : Failure_Array;
end record;
```

### type Prove_Failure

```ada
type Prove_Failure is record
Location : Ada.Strings.Unbounded.Unbounded_String :=
Ada.Strings.Unbounded.Null_Unbounded_String;
Kind     : Ada.Strings.Unbounded.Unbounded_String :=
Ada.Strings.Unbounded.Null_Unbounded_String;
Flow     : Boolean := False;
Budget   : Boolean := False;
end record;
```

## Functions

### function Annotation_Line (Location : Standard.String; Kind : Standard.String) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `Kind` | Check kind (for example "range check"). |
| `Location` | Source location as Collect_Failures recorded it. |

**Returns:** The workflow command, or "" when the location is malformed.

### function Diagnostics_Text (Prover : Standard.String; Stats : Adacovex.Prove_Output.Failure_Stats) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `Prover` | The resolved prover identity (version or path), or "" |
| `Stats` | Findings gathered by Collect_Failures. |

**Returns:** The diagnostics block, or "" when there is nothing to report.

## Procedures

### procedure Append_Text (Path : Standard.String; Text : Standard.String)

| Parameter | Description |
|-----------|-------------|
| `Path` | Replay text file. |
| `Text` | Text to append (line feeds included). |

### procedure Cache_Replay (Key : Standard.String; Path : Standard.String)

| Parameter | Description |
|-----------|-------------|
| `Key` | Cache key (already namespaced by the caller). |
| `Path` | Replay text file. |

### procedure Collect_Failures (Path : Standard.String; Stats : Adacovex.Prove_Output.Failure_Stats)

| Parameter | Description |
|-----------|-------------|
| `Path` | Captured gnatprove output file to read. |
| `Stats` | Findings gathered during the pass. |

### procedure Emit_Annotations (Stats : Adacovex.Prove_Output.Failure_Stats)

| Parameter | Description |
|-----------|-------------|
| `Stats` | Findings gathered by Collect_Failures. |

### procedure Print_Cached_Replay (Key : Standard.String)

| Parameter | Description |
|-----------|-------------|
| `Key` | Cache key (already namespaced by the caller). |

### procedure Print_Replay_Blob (S : Standard.String)

| Parameter | Description |
|-----------|-------------|
| `S` | Replay text, with line feeds between lines. |

### procedure Print_Replay_File (Path : Standard.String)

| Parameter | Description |
|-----------|-------------|
| `Path` | Replay text file. |
