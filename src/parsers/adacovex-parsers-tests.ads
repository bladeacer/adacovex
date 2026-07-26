with Adacovex.Types;

--  Parser for AUnit test-run results.
--  Reads a Markdown-format test summary file or parses raw stdout
--  to produce a structured Test_Summary.
--  HLR-TEST: Test result parsing

package Adacovex.Parsers.Tests is
   pragma SPARK_Mode (On);

   --  Parse a Markdown-format test result file for pass/fail counts.
   procedure Parse_Test_Result
     (File_Path : String;
      Summary   : out Types.Test_Summary;
      Success   : out Boolean);

   --  Parse raw test-runner stdout for pass/fail counts.
   procedure Parse_Test_Stdout
     (Summary : out Types.Test_Summary);

end Adacovex.Parsers.Tests;
