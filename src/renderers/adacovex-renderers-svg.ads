with Adacovex.Types;

package Adacovex.Renderers.SVG is

   function Render_SPARK_Badge (Level : Types.SPARK_Level) return String;

   function Render_Tests_Badge (Tests : Types.Test_Summary) return String;

   function Render_DO178C_Badge
     (Assess : Types.DAL_Assessment) return String;

   procedure Write_Badge_To_File
     (Path : String; SVG_Content : String);

end Adacovex.Renderers.SVG;
