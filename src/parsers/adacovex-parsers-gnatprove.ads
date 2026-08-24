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
   --  Target_Dir, or "" if none is present.  Used by the result cache to key
   --  a cached proof summary to the exact artifact analyzed.
   --  @param Target_Dir  Root directory to inspect.
   --  @return Path to a discovered gnatprove.out, or "".
   function Find_Prove_Output (Target_Dir : String) return String
   with Pre => Target_Dir'Length > 0;

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
   --  Maps proved-VC percentage and flow/runtime check results to a
   --  SPARK_Level (Stone through Platinum).
   --  @param Summary  Proof summary with VC counts per category.
   --  @return Derived SPARK_Level (Stone through Platinum).
   function Determine_SPARK_Level
     (Summary : Types.Proof_Summary) return Types.SPARK_Level
   with
     SPARK_Mode => On,
     Post       =>
       (if Summary.Unproved > 0
        then not (Determine_SPARK_Level'Result = Types.Platinum)),
     Global     => null;

end Adacovex.Parsers.GNATprove;
