with Adacovex.Types;

--  Parser for AUnit test-run results.
--  Reads a Markdown-format test summary file or parses raw stdout
--  to produce a structured Test_Summary.
--  HLR-TEST: Test result parsing

package Adacovex.Parsers.Tests is

   --  Parse a Markdown-format test result file for pass/fail counts.
   --  Reads category counts from a pre-formatted test summary Markdown file.
   --  @param File_Path  Path to test result Markdown file.
   --  @param Summary  Output test summary record.
   --  @param Success  True if file was parsed successfully.
   procedure Parse_Test_Result
     (File_Path : String;
      Summary   : out Types.Implementation.Test_Summary;
      Success   : out Boolean)
   with Pre => File_Path'Length > 0;

end Adacovex.Parsers.Tests;
