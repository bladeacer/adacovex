with Adacovex.Types;

--  SVG badge renderer.
--  Generates Shields.io-style SVG badges for SPARK level, test status,
--  and DO-178C compliance status.
--  HLR-RENDER-SVG: SVG badge generation

package Adacovex.Renderers.SVG is
   pragma SPARK_Mode (On);

   --  Render a SPARK-level badge (Stone/Bronze/Silver/Gold/Platinum).
   --  Returns SVG markup for a Shields.io-style badge with the SPARK level
   --  as the label and the level name as the value, color-coded by level.
   --  @param Level  SPARK certification level.
   --  @return SVG badge markup.
   function Render_SPARK_Badge (Level : Types.SPARK_Level) return String
   with Post => Render_SPARK_Badge'Result'Length > 0, Global => null;

   --  Render a test-status badge showing passed / failed counts.
   --  Returns SVG markup showing the total test count and pass/fail breakdown.
   --  @param Tests  Test result summary.
   --  @return SVG badge markup.
   function Render_Tests_Badge (Tests : Types.Test_Summary) return String
   with Post => Render_Tests_Badge'Result'Length > 0, Global => null;

   --  Render a DO-178C compliance badge (Achieved / Unmet).
   --  Returns SVG markup with "DO-178C" as the label and the compliance
   --  status as the value, green for Achieved, red for Unmet.
   --  @param Assess  DAL assessment record.
   --  @return SVG badge markup.
   function Render_DO178C_Badge (Assess : Types.DAL_Assessment) return String
   with Post => Render_DO178C_Badge'Result'Length > 0, Global => null;

   --  Render a docstring-coverage badge showing documented percentage.
   --  @param Doc_Metrics  Docstring coverage metrics.
   --  @return SVG badge markup with coverage percentage.
   function Render_Docstring_Badge
     (Doc_Metrics : Types.Docstring_Metrics) return String
   with Post => Render_Docstring_Badge'Result'Length > 0, Global => null;

   --  Write raw SVG text to a file at the given path.
   --  Creates or overwrites the file at Path with SVG_Content as the body.
   --  @param Path  Filesystem path to write the badge to.
   --  @param SVG_Content  SVG markup to write.
   procedure Write_Badge_To_File (Path : String; SVG_Content : String)
   with Pre => Path'Length > 0;

end Adacovex.Renderers.SVG;
