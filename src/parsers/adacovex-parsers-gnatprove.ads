with Adacovex.Types;

--  Parser for GNATprove verification-output files.
--  Reads the summary table from gnatprove.out and produces a
--  structured Proof_Summary record.
--  HLR-PROOF: GNATprove output parsing

package Adacovex.Parsers.GNATprove is
   pragma SPARK_Mode (On);

   use type Types.SPARK_Level;

   --  Parse a gnatprove.out file, extracting VC counts per check type.
   --  Reads the GNATprove summary table and populates the Proof_Summary
   --  record with proved/unproved VC counts per category.
   --  @param File_Path  Path to gnatprove.out.
   --  @param Summary  Output proof summary record.
   --  @param Success  True if file was parsed successfully.
   procedure Parse_Prove_Out
     (File_Path : String;
      Summary   : out Types.Proof_Summary;
      Success   : out Boolean)
   with Pre => File_Path'Length > 0;

   --  Probe for and parse GNATprove output from a project directory.
   --  Tries, in order:
   --    1. <Target>/obj/gnatprove/gnatprove.out
   --    2. <Target>/gnatprove.out
   --  If none found, Summary is zeroed and Success = False.
   --  @param Target_Dir  Project root directory.
   --  @param Summary  Output proof summary record.
   --  @param Success  True if gnatprove.out was found and parsed.
   procedure Parse_Prove_From_Project
     (Target_Dir : String;
      Summary    : out Types.Proof_Summary;
      Success    : out Boolean)
   with Pre => Target_Dir'Length > 0;

   --  Return the path of the first existing GNATprove output file under
   --  Target_Dir, or "" if none is present. Used by the result cache to key
   --  a cached proof summary to the exact artifact analysed.
   --  @param Target_Dir  Root directory to inspect.
   --  @return Path to a discovered gnatprove.out, or "".
   function Find_Prove_Output (Target_Dir : String) return String
   with Pre => Target_Dir'Length > 0;

   --  Extract the Unproved column value from one Total summary row.
   --  The row is the space-aligned "Total | Flow | Provers | Justified |
   --  Unproved" line of the gnatprove.out summary table; columns are runs
   --  separated by two or more spaces and the Unproved cell is either
   --  "." (all proved) or "N (P%)". The result-cache layer uses this to
   --  refuse to serve a stored summary that reports unproved VCs, because
   --  gnatprove exits 0 even when solver timeouts leave checks unproved.
   --  @param Row  One Total row line (no trailing newline).
   --  @return The unproved-VC count (0 when the cell is "." or missing).
   function Total_Row_Unproved (Row : String) return Natural
   with SPARK_Mode => On, Pre => Row'First >= 1 and Row'Last < Natural'Last;

   --  Parse VC summary from a JSON file containing GNATprove results.
   --  Expects top-level keys: "total_vcs", "proved_vcs", "unproved_vcs",
   --  "flow_deps", "flow_proved", and more.
   --  Falls back to Parse_Prove_Out on failure (not yet implemented).
   --  @param File_Path  Path to GNATprove JSON results file.
   --  @param Summary  Output proof summary record.
   --  @param Success  True if JSON was parsed successfully.
   procedure Parse_Prove_JSON
     (File_Path : String;
      Summary   : out Types.Proof_Summary;
      Success   : out Boolean)
   with Pre => File_Path'Length > 0;

   --  Derive an overall SPARK certification level from proof results.
   --  Platinum requires a complete formal specification and full proof
   --  coverage: at least one functional contract to prove with every one
   --  of them proved, and every subprogram the SPARK coverage report
   --  assesses proved. A project that proves its flow, run-time, and
   --  assertion checks but has no functional contracts, or that leaves
   --  subprograms outside the proof, is Gold at most.
   --  @param Summary  Proof summary with VC counts per category, plus
   --    the coverage evidence Apply_Coverage attaches.
   --  @return Derived SPARK_Level (Stone through Platinum).
   function Determine_SPARK_Level
     (Summary : Types.Proof_Summary) return Types.SPARK_Level
   with
     SPARK_Mode => On,
     Post       =>
       (if Summary.Unproved > 0
        then not (Determine_SPARK_Level'Result = Types.Platinum));

   --  Fold the SPARK coverage report's whole-tree rollup into a proof
   --  summary and re-derive its level. A summary parsed from
   --  gnatprove.out alone counts total VCs but cannot show whether every
   --  subprogram was proved, so Platinum is only granted once the
   --  assessment pipeline has measured the coverage report
   --  (Adacovex.Spark_Coverage.Analyze) and attached it here.
   --  @param Summary  Proof summary to update.
   --  @param Measured  True when both proof artefacts were read.
   --  @param Subs_Proved  Subprograms the prover proved.
   --  @param Subs_Total  Subprograms the prover considered.
   --  @param Checks_Proved  Checks the prover discharged.
   --  @param Checks_Total  Checks the prover reported.
   procedure Apply_Coverage
     (Summary       : in out Types.Proof_Summary;
      Measured      : Boolean;
      Subs_Proved   : Natural;
      Subs_Total    : Natural;
      Checks_Proved : Natural;
      Checks_Total  : Natural)
   with
     SPARK_Mode => On,
     Post       =>
       (if Summary.Unproved > 0 then not (Summary.Level = Types.Platinum));

end Adacovex.Parsers.GNATprove;
