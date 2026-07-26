with Adacovex.Types;

--  Parser for GNATprove verification-output files.
--  Reads the summary table from gnatprove.out and produces a
--  structured Proof_Summary record.

package Adacovex.Parsers.GNATprove is

   --  Parse a gnatprove.out file, extracting VC counts per check type.
   procedure Parse_Prove_Out
     (File_Path : String;
      Summary   : out Types.Proof_Summary;
      Success   : out Boolean);

   --  Derive an overall SPARK certification level from proof results.
   function Determine_SPARK_Level
     (Summary : Types.Proof_Summary) return Types.SPARK_Level;

end Adacovex.Parsers.GNATprove;
