with Adacovex.Types;
--  SPDX-License-Identifier: Apache-2.0

--  Parser for GNATprove verification-output files.
--  Reads the summary table from gnatprove.out and produces a
--  structured Proof_Summary record.
--  HLR-PROOF: GNATprove output parsing

package Adacovex.Parsers.GNATprove is
   pragma SPARK_Mode (On);

   --  Parse a gnatprove.out file, extracting VC counts per check type.
   procedure Parse_Prove_Out
     (File_Path : String;
      Summary   : out Types.Proof_Summary;
      Success   : out Boolean);

   --  Derive an overall SPARK certification level from proof results.
   function Determine_SPARK_Level
     (Summary : Types.Proof_Summary) return Types.SPARK_Level;

end Adacovex.Parsers.GNATprove;
