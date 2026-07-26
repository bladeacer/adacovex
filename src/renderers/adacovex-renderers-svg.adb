with Ada.Text_IO;

package body Adacovex.Renderers.SVG is

   use type Types.DAL_Status;

   function Badge_SVG
     (Label     : String;
      Value     : String;
      Label_Color : String := "#555";
      Value_Color : String := "#4c1") return String
   is
   begin
      return
        "<svg xmlns=""http://www.w3.org/2000/svg"" width=""" &
        Integer'Image (Label'Length * 7 + Value'Length * 7 + 14) &
        """ height=""20"">" &
        "<linearGradient id=""b"" x2=""0"" y2=""100%"">" &
        "<stop offset=""0"" stop-color=""#bbb"" stop-opacity="".1""/>" &
        "<stop offset=""1"" stop-opacity="".1""/>" &
        "</linearGradient>" &
        "<rect rx=""3"" width=""100%"" height=""100%"" fill=""" &
        Label_Color & """/>" &
        "<rect rx=""3"" x=""" &
        Integer'Image (Label'Length * 7 + 7) &
        """ width=""100%"" height=""100%"" fill=""" &
        Value_Color & """/>" &
        "<rect fill=""" & Value_Color & """ x=""" &
        Integer'Image (Label'Length * 7 + 7) &
        """ width=""4"" height=""100%""/>" &
        "<rect rx=""3"" width=""100%"" height=""100%"" fill=""url(#b)""/>" &
        "<g fill=""#fff"" font-family=""DejaVu Sans,Verdana,Geneva,sans-serif"" " &
        "font-size=""11"">" &
        "<text x=""" & Integer'Image ((Label'Length * 7 + 7) / 2) &
        """ y=""15"" fill=""#010101"" fill-opacity="".3"" " &
        "text-anchor=""middle"">" & Label & "</text>" &
        "<text x=""" & Integer'Image ((Label'Length * 7 + 7) / 2) &
        """ y=""14"" text-anchor=""middle"">" & Label & "</text>" &
        "<text x=""" &
        Integer'Image (Label'Length * 7 + 7 + (Value'Length * 7 + 7) / 2) &
        """ y=""15"" fill=""#010101"" fill-opacity="".3"" " &
        "text-anchor=""middle"">" & Value & "</text>" &
        "<text x=""" &
        Integer'Image (Label'Length * 7 + 7 + (Value'Length * 7 + 7) / 2) &
        """ y=""14"" text-anchor=""middle"">" & Value & "</text>" &
        "</g></svg>";
   end Badge_SVG;

   function Spark_Color (Level : Types.SPARK_Level) return String is
   begin
      case Level is
         when Types.Platinum => return "#E5E4E2";
         when Types.Gold     => return "#FFD700";
         when Types.Silver   => return "#C0C0C0";
         when Types.Bronze   => return "#CD7F32";
         when Types.Stone    => return "#888";
      end case;
   end Spark_Color;

   function Render_SPARK_Badge (Level : Types.SPARK_Level) return String is
   begin
          declare
             SC : constant String := Spark_Color (Level);
          begin
             return Badge_SVG ("SPARK", Types.To_String (Level), "#555", SC);
          end;
   end Render_SPARK_Badge;

   function Render_Tests_Badge (Tests : Types.Test_Summary) return String is
      Value : String (1 .. 64);
      Len   : Natural := 0;
      Num   : String := Natural'Image (Tests.Total_Passed);
   begin
      for I in 2 .. Num'Length loop
         Len := Len + 1;
         Value (Len) := Num (I);
      end loop;
      Value (Len + 1 .. Len + 7) := " Passed";
      Len := Len + 7;

      return Badge_SVG ("Tests", Value (1 .. Len), "#555", "#4c1");
   end Render_Tests_Badge;

   function Render_DO178C_Badge
     (Assess : Types.DAL_Assessment) return String
   is
      Status_Str : String (1 .. 16);
      SLen       : Natural := 0;
   begin
      if Assess.Status = Types.Achieved then
           declare
              S : constant String := Types.To_String (Assess.Target_DAL);
           begin
              Status_Str (1 .. 4) := "DAL-";
              Status_Str (5) := S (S'First);
              Status_Str (6 .. 10) := " PASS";
              SLen := 10;
           end;
           return Badge_SVG ("DO-178C", Status_Str (1 .. SLen), "#555", "#4c1");
        else
           declare
              S : constant String := Types.To_String (Assess.Target_DAL);
           begin
              Status_Str (1 .. 4) := "DAL-";
              Status_Str (5) := S (S'First);
              Status_Str (6 .. 10) := " FAIL";
              SLen := 10;
           end;
           return Badge_SVG ("DO-178C", Status_Str (1 .. SLen), "#555", "#e05d44");
       end if;
   end Render_DO178C_Badge;

   procedure Write_Badge_To_File
     (Path : String; SVG_Content : String)
   is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (F, SVG_Content);
      Ada.Text_IO.Close (F);
   end Write_Badge_To_File;

end Adacovex.Renderers.SVG;
