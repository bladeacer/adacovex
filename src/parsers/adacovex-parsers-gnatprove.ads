with Adacovex.Types;

package Adacovex.Parsers.GNATprove is

   procedure Parse_Prove_Out
     (File_Path : String;
      Summary   : out Types.Proof_Summary;
      Success   : out Boolean);

   function Determine_SPARK_Level
     (Summary : Types.Proof_Summary) return Types.SPARK_Level;

end Adacovex.Parsers.GNATprove;
