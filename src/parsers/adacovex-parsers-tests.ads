with Adacovex.Types;

--  Parser for AUnit test-run results.
--  Reads a Markdown-format test summary file or parses raw stdout
--  to produce a structured Test_Summary.
--  HLR-TEST: Test result parsing

package Adacovex.Parsers.Tests is
   pragma SPARK_Mode (On);

    --  Parse a Markdown-format test result file for pass/fail counts.
    --  Reads category counts from a pre-formatted test summary Markdown file.
    --  @param File_Path  Path to test result Markdown file.
    --  @param Summary  Output test summary record.
    --  @param Success  True if file was parsed successfully.
    procedure Parse_Test_Result
      (File_Path : String;
       Summary   : out Types.Test_Summary;
       Success   : out Boolean)
    with Pre => File_Path'Length > 0;

    --  Parse raw test-runner stdout for pass/fail counts.
    --  Reads from the standard input (piped test-runner output) and extracts
    --  per-category test counts and overall pass/fail status.
    --  @param Summary  Output test summary from piped stdout.
    procedure Parse_Test_Stdout (Summary : out Types.Test_Summary);

end Adacovex.Parsers.Tests;
