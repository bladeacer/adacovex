with Adacovex.Types;

package Adacovex.Config is

   type CLI_Config is record
      Target_Path   : String (1 .. Types.Max_Path);
      Target_Len    : Natural := 0;
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

   function Parse_CLI return CLI_Config;

   procedure Print_Usage;

end Adacovex.Config;
