with Adacovex.Types;

--  Command-line argument parser for adacovex.
--  Parses short and long option forms (--key=value and --key value)
--  and returns a populated CLI_Config record.
--  HLR-CLI: CLI argument parsing

package Adacovex.Config is
   pragma SPARK_Mode (On);

   type CLI_Config is record
      Target_Path   : String (1 .. Types.Max_Path);
      Target_Len    : Natural := 0;
      Manifest_Path : String (1 .. Types.Max_Path);
      Manifest_Len  : Natural := 0;
      DAL_Target    : Types.DAL_Level := Types.DAL_C;
      Serve_Mode    : Boolean := False;
      Port          : Positive := 8080;
      Emit_SVG      : Boolean := False;
      SVG_Path      : String (1 .. Types.Max_Path);
      SVG_Path_Len  : Natural := 0;
      Emit_Markdown : Boolean := False;
      MD_Path       : String (1 .. Types.Max_Path);
      MD_Path_Len   : Natural := 0;
      Verbose       : Boolean := False;
   end record;

   --  Parse Ada.Command_Line arguments and return a fully populated config.
   --  Reads command-line arguments via Ada.Command_Line; default values are
   --  used for any option not provided.  Resolves relative target paths to
   --  absolute and checks that the target's manifest file exists.
   function Parse_CLI return CLI_Config
     with Post => Parse_CLI'Result.Target_Len <= Types.Max_Path
                  and then Parse_CLI'Result.Manifest_Len <= Types.Max_Path
                  and then Parse_CLI'Result.SVG_Path_Len <= Types.Max_Path
                  and then Parse_CLI'Result.MD_Path_Len <= Types.Max_Path;

   --  Print usage help text to standard output.
   --  Displays all CLI options, default values, and usage examples.
   procedure Print_Usage;

end Adacovex.Config;
