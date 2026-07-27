with Ada.Text_IO;

package body Adacovex.Renderers.SVG is

   use type Types.DAL_Status;

   function I2S (N : Natural) return String is
      Buf : String (1 .. 10);
      Pos : Natural := 10;
      R   : Natural := N;
   begin
      if N = 0 then
         return "0";
      end if;
      while R > 0 and Pos > 1 loop
         Buf (Pos) := Character'Val (Character'Pos ('0') + (R mod 10));
         R := R / 10;
         Pos := Pos - 1;
      end loop;
      return Buf (Pos + 1 .. 10);
   end I2S;

   function Badge_SVG
     (Label       : String;
      Value       : String;
      Label_Color : String := "#555";
      Value_Color : String := "#4c1") return String
   is
      LW : constant Natural := Label'Length * 7 + 10;
      VW : constant Natural := Value'Length * 7 + 10;
      TW : constant Natural := LW + VW;
      LX : constant Natural := LW / 2;
      VX : constant Natural := LW + VW / 2;
   begin
      return
        "<svg xmlns=""http://www.w3.org/2000/svg"" width="""
        & I2S (TW)
        & """ height=""20"">"
        & "<linearGradient id=""b"" x2=""0"" y2=""100%"">"
        & "<stop offset=""0"" stop-color=""#bbb"" stop-opacity="".1""/>"
        & "<stop offset=""1"" stop-opacity="".1""/>"
        & "</linearGradient>"
        & "<clipPath id=""r""><rect width="""
        & I2S (TW)
        & """ height=""20"" rx=""3"" fill=""#fff""/></clipPath>"
        & "<g clip-path=""url(#r)"">"
        & "<rect width="""
        & I2S (LW)
        & """ height=""20"" fill="""
        & Label_Color
        & """/>"
        & "<rect x="""
        & I2S (LW)
        & """ width="""
        & I2S (VW)
        & """ height=""20"" fill="""
        & Value_Color
        & """/>"
        & "<rect width="""
        & I2S (TW)
        & """ height=""20"" fill=""url(#b)""/>"
        & "</g>"
        & "<g fill=""#fff"" font-family=""DejaVu Sans,Verdana,Geneva,sans-serif"" "
        & "font-size=""11"">"
        & "<text x="""
        & I2S (LX)
        & """ y=""15"" fill=""#010101"" fill-opacity="".3"" "
        & "text-anchor=""middle"">"
        & Label
        & "</text>"
        & "<text x="""
        & I2S (LX)
        & """ y=""14"" text-anchor=""middle"">"
        & Label
        & "</text>"
        & "<text x="""
        & I2S (VX)
        & """ y=""15"" fill=""#010101"" fill-opacity="".3"" "
        & "text-anchor=""middle"">"
        & Value
        & "</text>"
        & "<text x="""
        & I2S (VX)
        & """ y=""14"" text-anchor=""middle"">"
        & Value
        & "</text>"
        & "</g></svg>";
   end Badge_SVG;

   function Spark_Color (Level : Types.SPARK_Level) return String is
   begin
      case Level is
         when Types.Platinum =>
            return "#E5E4E2";

         when Types.Gold     =>
            return "#FFD700";

         when Types.Silver   =>
            return "#C0C0C0";

         when Types.Bronze   =>
            return "#CD7F32";

         when Types.Stone    =>
            return "#888";
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

   function Render_DO178C_Badge (Assess : Types.DAL_Assessment) return String
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
         return
           Badge_SVG ("DO-178C", Status_Str (1 .. SLen), "#555", "#e05d44");
      end if;
   end Render_DO178C_Badge;

   function Render_Docstring_Badge
     (Doc_Metrics : Types.Docstring_Metrics) return String
   is
      Pct : constant Natural := Doc_Metrics.Coverage_Pct;
      Val : String (1 .. 64);
      Len : Natural := 0;
      Num : String := Natural'Image (Pct);
   begin
      for I in 2 .. Num'Length loop
         Len := Len + 1;
         Val (Len) := Num (I);
      end loop;
      Val (Len + 1 .. Len + 1) := "%";
      Len := Len + 1;
      if Pct >= 80 then
         return Badge_SVG ("docs", Val (1 .. Len), "#555", "#4c1");
      elsif Pct >= 50 then
         return Badge_SVG ("docs", Val (1 .. Len), "#555", "#dfb317");
      else
         return Badge_SVG ("docs", Val (1 .. Len), "#555", "#e05d44");
      end if;
   end Render_Docstring_Badge;

   procedure Write_Badge_To_File (Path : String; SVG_Content : String) is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (F, SVG_Content);
      Ada.Text_IO.Close (F);
   end Write_Badge_To_File;

end Adacovex.Renderers.SVG;
