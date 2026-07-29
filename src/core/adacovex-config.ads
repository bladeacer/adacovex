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
      No_SVG        : Boolean := False;
      Emit_SVG      : Boolean := True;
      SVG_Path      : String (1 .. Types.Max_Path);
      SVG_Path_Len  : Natural := 0;
      Emit_Markdown : Boolean := False;
      MD_Path       : String (1 .. Types.Max_Path);
      MD_Path_Len   : Natural := 0;
      Verbose       : Boolean := False;
      Strict_Mode   : Boolean := True;
      CLI_Error     : Boolean := False;
      Skip_Dir_Ct   : Natural := 0;
      Skip_Dirs     : Types.Name_Field;
   end record;

   --  Parse Ada.Command_Line arguments and return a fully populated config.
   --  Reads command-line arguments via Ada.Command_Line; default values are
   --  used for any option not provided.  Resolves relative target paths to
   --  absolute and checks that the target's manifest file exists.
   --  @return Fully populated CLI_Config from parsed command-line arguments.
   function Parse_CLI return CLI_Config
   with
     Post =>
       Parse_CLI'Result.Target_Len <= Types.Max_Path
       and then Parse_CLI'Result.Manifest_Len <= Types.Max_Path
       and then Parse_CLI'Result.SVG_Path_Len <= Types.Max_Path
       and then Parse_CLI'Result.MD_Path_Len <= Types.Max_Path;

   --  Add a directory name to the comma-separated skip list.
   --  Appends Name to the Skip_Dirs field, inserting ',' separator if
   --  the list is non-empty.
   --  @param Cfg  Config record to modify.
   --  @param Name  Directory name to add to skip list.
   procedure Add_Skip_Dir (Cfg : in out CLI_Config; Name : String);

   --  Print usage help text to standard output.
   --  Displays all CLI options, default values, and usage examples.
   --  @return Prints usage information to stdout.
   procedure Print_Usage;

end Adacovex.Config;
