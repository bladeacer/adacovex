with Ada.Strings.Unbounded;

--  Diagnostics and output for the `adacovex prove` subcommand.
--
--  This package owns the proof finding model, the pass that reads a captured
--  gnatprove stream, the rendered diagnostics block, the GitHub Actions
--  annotation shape, and the quiet replay printer. The prove runner keeps
--  only the orchestration: resolve gnatprove, run it, and call these
--  subprograms. Keeping the I/O-heavy report layer here also keeps
--  `adacovex-prove.adb` inside its cyclomatic-complexity budget.
--
--  A local prove run is concise: the captured prover output is replayed as
--  one framed block, with severity colours and a diagnostics block for
--  unproved checks. A warm cache hit replays the text that run produced, so
--  cached and fresh output agree.
--  HLR-PROVE: Proof diagnostics

package Adacovex.Prove_Output is

   --  How many findings a diagnostics block names. The total unproved count
   --  is always reported; only the first Max_Failure_Items entries are named,
   --  so a project with many unproved checks does not swamp the report.
   Max_Failure_Items : constant := 8;

   --  One unproved finding of a proof run, gathered from the captured
   --  gnatprove stream.
   type Prove_Failure is record
      --  `file:line:column`, as gnatprove reported the check.
      Location       : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      --  The check kind (for example `range check` or `postcondition`).
      Kind           : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      --  True for a flow-analysis finding (an uninitialized object), False
      --  for a prover check.
      Flow           : Boolean := False;
      --  True when the prover gave up instead of finding a counterexample:
      --  the proof ran out of budget, so a larger --steps is the next step
      --  and the code may well be correct.
      Budget         : Boolean := False;
      --  The prover set the gnatprove summary attributes to this check's
      --  category (for example `CVC5, Z3`). gnatprove 16.1 records the
      --  solvers per summary row, not per SARIF result, so this is the
      --  category's prover set rather than a single solver name. It is
      --  empty when the summary is missing or the row names no prover.
      Solver         : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      --  The counterexample gnatprove printed for this check, as one phrase
      --  (for example `when I = 1 and T = (2 => 2)`). It is empty when the
      --  prover found none or ran with counterexamples off.
      Counterexample : Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.Null_Unbounded_String;
      --  How many copies of this finding the stream carried. The prover
      --  prints one copy per inlined call site, so a value above one means
      --  the same check failed at several call sites.
      Call_Sites     : Natural := 1;
   end record;

   type Failure_Array is array (1 .. Max_Failure_Items) of Prove_Failure;

   --  Counts gathered by one diagnostics pass over a captured gnatprove
   --  output file. Unproved is every unproved finding the stream carried and
   --  Count is how many of them Items names, so a reader sees both the scale
   --  of the failure and the first locations to fix.
   type Failure_Stats is record
      --  Distinct unproved findings seen in the stream; a repeated finding
      --  counts once.
      Unproved : Natural := 0;
      --  Entries filled in Items (<= Max_Failure_Items).
      Count    : Natural := 0;
      --  The first findings, in stream order.
      Items    : Failure_Array;
   end record;

   --  Collect the actionable failure detail of a captured gnatprove stream:
   --  the location and check kind of every unproved check, and of every flow
   --  finding that names an uninitialized object. A prover failure line has
   --  the shape
   --
   --     unit.adb:54:08: medium: postcondition might fail
   --
   --  and a flow finding the shape
   --
   --     unit.adb:31:05: "X" is not initialized
   --
   --  so the pass keeps the location, strips the optional severity word, and
   --  derives the kind from the message. Every other line is ignored: a line
   --  without a `file:line:column` prefix is not a finding, and a finding
   --  that reports a proof outcome rather than a failure is not one to act
   --  on. A check counts once per source location and check kind once the
   --  `, in call inlined at ...` suffix is removed: the prover can report one
   --  check once per inlined call site, so a repeated finding is not
   --  double-counted. The repeat count is kept in Call_Sites. The seen table
   --  is bounded, and a stream with more distinct findings than it holds
   --  keeps its later repeats.
   --  @param Path  Captured gnatprove output file to read.
   --  @param Stats  Findings gathered during the pass.
   --  @param Summary_Path  Gnatprove summary (gnatprove.out) whose prover
   --  column attributes a prover set to each category. Empty when the
   --  summary is not available.
   procedure Collect_Failures
     (Path : String; Stats : out Failure_Stats; Summary_Path : String := "");

   --  Render the diagnostics block for a proof run that left unproved checks:
   --  how many, which prover produced them, the first check locations with
   --  their kinds, and a one-line fix hint derived from the first check's
   --  kind. It is empty when the run left no finding, so a clean run prints
   --  nothing. Lines end with a line feed and the last line is the hint, so
   --  the caller can print the result as one block.
   --  @param Prover  The resolved prover identity (version or path), or ""
   --  when it is not known.
   --  @param Stats  Findings gathered by Collect_Failures.
   --  @param Source_Root  Directory the finding locations are relative to,
   --  or "" to omit the source excerpt line.
   --  @return The diagnostics block, or "" when there is nothing to report.
   function Diagnostics_Text
     (Prover : String; Stats : Failure_Stats; Source_Root : String := "")
      return String;

   --  Render the same findings as one JSON object, so a CI job or a script
   --  can read the facts without parsing prose. It carries the prover
   --  identity, the unproved count, and one entry per named finding with
   --  its location, line, column, kind, solver, counterexample, flow and
   --  budget flags, call-site count, source excerpt, and fix hint. It is
   --  empty when the run left no finding.
   --  @param Prover  The resolved prover identity, or "".
   --  @param Stats  Findings gathered by Collect_Failures.
   --  @param Source_Root  Directory the finding locations are relative to.
   --  @return One JSON object, or "" when there is nothing to report.
   function Diagnostics_Json
     (Prover : String; Stats : Failure_Stats; Source_Root : String := "")
      return String;

   --  Build the GitHub Actions workflow command for one unproved finding.
   --  The location gnatprove prints is `file:line:column`, so the trailing
   --  fields are split off and the result is
   --  `::error file=...,line=...,col=...,title=SPARK proof failed::<kind>`.
   --  A location without a column still yields an annotation (the `col`
   --  field is omitted). A location that cannot be split returns the empty
   --  string, so a malformed finding is never emitted as an empty file
   --  annotation. The function is pure: emitting is the caller's job.
   --  @param Location  Source location as Collect_Failures recorded it.
   --  @param Kind  Check kind (for example "range check").
   --  @return The workflow command, or "" when the location is malformed.
   function Annotation_Line (Location : String; Kind : String) return String;

   --  Emit one annotation per distinct finding when running in GitHub
   --  Actions. A local run prints nothing here, so the diagnostics block
   --  stays the only failure detail.
   --  @param Stats  Findings gathered by Collect_Failures.
   procedure Emit_Annotations (Stats : Failure_Stats);

   --  Print replay text line by line with a severity colour: errors red,
   --  warnings yellow, notices and their locations dim, a success line green,
   --  and the summary footers bold. Colour is already a no-op under CI,
   --  NO_COLOR, or a dumb terminal (Adacovex.Ansi.Wrap), so a log stays plain
   --  text. The text is the plain, cached form (no escape codes are stored),
   --  so a CI log or a later warm hit never inherits a colour decision made
   --  on another terminal.
   --  @param S  Replay text, with line feeds between lines.
   procedure Print_Replay_Blob (S : String);

   --  Print a replay file line by line. This is the shape a fresh run uses,
   --  and the fallback when a replay does not fit the cache blob.
   --  @param Path  Replay text file.
   procedure Print_Replay_File (Path : String);

   --  Append one text block to a replay file. An empty block appends
   --  nothing. Used to put the diagnostics block after the replay in the
   --  text that is printed and cached.
   --  @param Path  Replay text file.
   --  @param Text  Text to append (line feeds included).
   procedure Append_Text (Path : String; Text : String);

   --  Cache a replay file as plain text under Key. A replay larger than the
   --  cache blob is not cached: the file was already printed, so only the
   --  warm-cache convenience is lost.
   --  @param Key  Cache key (already namespaced by the caller).
   --  @param Path  Replay text file.
   procedure Cache_Replay (Key : String; Path : String);

   --  Print the cached replay stored under Key, when one exists. This is the
   --  warm-cache path that keeps a cached run and a fresh run in agreement.
   --  @param Key  Cache key (already namespaced by the caller).
   procedure Print_Cached_Replay (Key : String);

end Adacovex.Prove_Output;
