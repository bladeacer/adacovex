with Adacovex.Types;

--  Parser for GNATprove verification-output files.
--  Reads the summary table from gnatprove.out and produces a
--  structured Proof_Summary record.
--  HLR-PROOF: GNATprove output parsing

package Adacovex.Parsers.GNATprove is
   pragma SPARK_Mode (On);

   --  Parse a gnatprove.out file, extracting VC counts per check type.
   --  Reads the GNATprove summary table and populates the Proof_Summary
   --  record with proved/unproved VC counts per category.
   procedure Parse_Prove_Out
     (File_Path : String;
      Summary   : out Types.Proof_Summary;
      Success   : out Boolean)
     with Pre => File_Path'Length > 0;

   --  Derive an overall SPARK certification level from proof results.
   --  Maps proved-VC percentage and flow/runtime check results to a
   --  SPARK_Level (Stone through Platinum).
   function Determine_SPARK_Level
     (Summary : Types.Proof_Summary) return Types.SPARK_Level
     with Global => null;

end Adacovex.Parsers.GNATprove;
