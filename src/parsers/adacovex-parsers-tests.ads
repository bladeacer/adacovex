with Adacovex.Types;

--  Parser for test-run results.
--  Reads a Markdown-format test summary file or parses raw stdout
--  to produce a structured Test_Summary.
--  HLR-TEST: Test result parsing
--
--  Recognized formats (all additive, best-effort):
--    Markdown table      | Category | Tests | PASS/FAIL | rows
--    Summary line        "Passed: N  Failed: M"
--    TAP                 "ok N - name" / "not ok N - name"
--    Automake suite      "PASS: name" / "FAIL: name"
--    Maven Surefire      "Tests run: N, Failures: M, Errors: E"
--    Unity               "N Tests M Failures [K Ignored]"

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

   --  Locate and parse the test result file for a target project.
   --  Searches a conventional list of test-summary file names in the
   --  project root (and docs/) and parses the first file that exists,
   --  so adacovex accepts common report conventions beyond test_result.md.
   --  @param Target_Dir  Target project root directory.
   --  @param Summary  Output test summary record.
   --  @param Success  True if a test result file was found and parsed.
   procedure Parse_Test_Result_From_Project
     (Target_Dir : String;
      Summary    : out Types.Implementation.Test_Summary;
      Success    : out Boolean)
   with Pre => Target_Dir'Length > 0;

end Adacovex.Parsers.Tests;
