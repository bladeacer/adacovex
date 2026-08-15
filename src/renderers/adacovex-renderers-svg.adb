with Ada.Text_IO;
with Ada.Directories;

package body Adacovex.Renderers.SVG is

   use type Types.DAL_Status;

   --  Decimal string of a non-negative integer.  The fixed 10-character
   --  buffer and the loop invariant prove the write cursor never underflows.
   function I2S (N : Natural) return String
   with
     SPARK_Mode => On,
     Post       =>
       I2S'Result'First in 1 .. 10
       and I2S'Result'Last in 1 .. 10
       and I2S'Result'Length in 1 .. 10
   is
      Pow10 : constant array (1 .. 10) of Long_Long_Integer :=
        (10,
         100,
         1_000,
         10_000,
         100_000,
         1_000_000,
         10_000_000,
         100_000_000,
         1_000_000_000,
         10_000_000_000);
      Buf   : String (1 .. 10) := (others => '0');
      Pos   : Natural := 10;
      R     : Natural := N;
   begin
      if N = 0 then
         return "0";
      end if;
      while R > 0 loop
         pragma Loop_Invariant (Pos in 1 .. 10);
         pragma Loop_Invariant (Long_Long_Integer (R) < Pow10 (Pos));
         pragma Loop_Variant (Decreases => R);
         Buf (Pos) := Character'Val (Character'Pos ('0') + (R mod 10));
         R := R / 10;
         exit when R = 0;
         Pos := Pos - 1;
      end loop;
      return Buf (Pos .. 10);
   end I2S;

   function Badge_SVG
     (Label            : String;
      Value            : String;
      Label_Color      : String := "#555";
      Value_Color      : String := "#4c1";
      Value_Text_Color : String := "#fff") return String
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
        & """ y=""14"" text-anchor=""middle"">"
        & Label
        & "</text>"
        & "<text x="""
        & I2S (VX)
        & """ y=""14"" fill="""
        & Value_Text_Color
        & """ text-anchor=""middle"">"
        & Value
        & "</text>"
        & "</g></svg>";
   end Badge_SVG;

   function Spark_Color (Level : Types.SPARK_Level) return String
   with SPARK_Mode => On, Post => Spark_Color'Result'Length in 4 .. 7
   is
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

   --  Text color with sufficient contrast on the level background.
   --  Light metals (Platinum, Gold, Silver) take dark text; Bronze and
   --  Stone keep white text.
   function Spark_Text_Color (Level : Types.SPARK_Level) return String
   with SPARK_Mode => On, Post => Spark_Text_Color'Result'Length in 4 .. 7
   is
   begin
      case Level is
         when Types.Platinum | Types.Gold | Types.Silver =>
            return "#1a1a1a";

         when Types.Bronze | Types.Stone                 =>
            return "#fff";
      end case;
   end Spark_Text_Color;

   --  Text color with sufficient contrast on the value background: dark text
   --  on the light green (#4c1) and yellow (#dfb317) pass colors, white on
   --  the dark red (#e05d44) failure color.
   function Badge_Text_Color (Value_Color : String) return String is
   begin
      if Value_Color = "#4c1" or else Value_Color = "#dfb317" then
         return "#1a1a1a";
      else
         return "#fff";
      end if;
   end Badge_Text_Color;

   function Render_SPARK_Badge (Level : Types.SPARK_Level) return String is
   begin
      declare
         SC : constant String := Spark_Color (Level);
         TC : constant String := Spark_Text_Color (Level);
      begin
         return Badge_SVG ("SPARK", Types.To_String (Level), "#555", SC, TC);
      end;
   end Render_SPARK_Badge;

   function Render_Tests_Badge
     (Tests : Types.Implementation.Test_Summary) return String
   is
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

      return
        Badge_SVG
          ("Tests",
           Value (1 .. Len),
           "#555",
           "#4c1",
           Badge_Text_Color ("#4c1"));
   end Render_Tests_Badge;

   function Render_DO178C_Badge
     (Assess : Types.Implementation.DAL_Assessment) return String
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
         return
           Badge_SVG
             ("DO-178C",
              Status_Str (1 .. SLen),
              "#555",
              "#4c1",
              Badge_Text_Color ("#4c1"));
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
         return
           Badge_SVG
             ("docs",
              Val (1 .. Len),
              "#555",
              "#4c1",
              Badge_Text_Color ("#4c1"));
      elsif Pct >= 50 then
         return
           Badge_SVG
             ("docs",
              Val (1 .. Len),
              "#555",
              "#dfb317",
              Badge_Text_Color ("#dfb317"));
      else
         return
           Badge_SVG
             ("docs",
              Val (1 .. Len),
              "#555",
              "#e05d44",
              Badge_Text_Color ("#e05d44"));
      end if;
   end Render_Docstring_Badge;

   procedure Write_Badge_To_File (Path : String; SVG_Content : String) is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Directories.Create_Path
        (Ada.Directories.Containing_Directory (Path));
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (F, SVG_Content);
      Ada.Text_IO.Close (F);
   end Write_Badge_To_File;

end Adacovex.Renderers.SVG;
