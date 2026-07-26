with Adacovex.Types;

--  SVG badge renderer.
--  Generates Shields.io-style SVG badges for SPARK level, test status,
--  and DO-178C compliance status.

package Adacovex.Renderers.SVG is

   --  Render a SPARK-level badge (Stone/Bronze/Silver/Gold/Platinum).
   function Render_SPARK_Badge (Level : Types.SPARK_Level) return String;

   --  Render a test-status badge showing passed / failed counts.
   function Render_Tests_Badge (Tests : Types.Test_Summary) return String;

   --  Render a DO-178C compliance badge (Achieved / Unmet).
   function Render_DO178C_Badge
     (Assess : Types.DAL_Assessment) return String;

   --  Write raw SVG text to a file at the given path.
   procedure Write_Badge_To_File
     (Path : String; SVG_Content : String);

end Adacovex.Renderers.SVG;
