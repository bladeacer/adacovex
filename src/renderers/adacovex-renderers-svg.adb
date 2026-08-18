with Ada.Text_IO;
with Ada.Directories;

package body Adacovex.Renderers.SVG is

   use type Types.DAL_Status;

   --  Maximum length of a badge label or value text run.  Badge segments
   --  are sized from measured glyph widths; bounding the text length keeps
   --  the width arithmetic provably within Natural.
   Max_Badge_Text : constant := 64;

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

   --  Advance width (px) of one character in the badge font (DejaVu Sans,
   --  Verdana, Geneva fallback chain) at font-size 11, rounded to the
   --  nearest pixel.  The values are DejaVu Sans's 2048-units-per-em
   --  advance widths scaled by 11/2048; unknown characters fall back to
   --  7px, the font's average glyph width.
   function Glyph_Width (C : Character) return Natural
   with SPARK_Mode => On,
        Post       => Glyph_Width'Result in 3 .. 10
   is
   begin
      case C is
         --  3px: space, punctuation, and narrow lowercase stems.
         when ' ' | '.' | '/' | '(' | ')' | 'I' | 'J' | 'f' | 'i' | 'j'
           | 'l' | 't'
         =>
            return 3;

         --  4px: hyphen and the short lowercase 'r'.
         when '-' | 'r'
         =>
            return 4;

         --  6px: narrow uppercase and lowercase glyphs.
         when 'F' | 'L' | 'Z' | 'a' | 'c' | 'e' | 'k' | 's' | 'v' | 'x'
           | 'y' | 'z'
         =>
            return 6;

         --  7px: digits (tabular) and the average-width letters.
         when '0' .. '9' | 'A' | 'B' | 'C' | 'D' | 'E' | 'G' | 'K' | 'P'
           | 'R' | 'S' | 'T' | 'V' | 'X' | 'Y' | 'b' | 'd' | 'g' | 'h'
           | 'n' | 'o' | 'p' | 'q' | 'u'
         =>
            return 7;

         --  8px: wide uppercase letters.
         when 'H' | 'N' | 'O' | 'Q' | 'U'
         =>
            return 8;

         --  9px: the widest common glyphs.
         when 'M' | 'w' | '%'
         =>
            return 9;

         --  10px: the two widest glyphs in the badge repertoire.
         when 'W' | 'm'
         =>
            return 10;

         when others
         =>
            return 7;
      end case;
   end Glyph_Width;

   --  Total advance width (px) of a badge text run at font-size 11: the
   --  sum of the per-glyph widths.  Replaces the flat 7px-per-character
   --  estimate so every badge carries the same side padding regardless of
   --  its letters -- the old estimate left uppercase-heavy labels (SPARK,
   --  DO-178C) nearly flush against their segment edge while narrow
   --  lowercase/digit text (docs, 100%) ended up with visibly wider
   --  padding.
   function Text_Width (S : String) return Natural
   with SPARK_Mode => On,
        Pre  => S'Length <= Max_Badge_Text,
        Post => Text_Width'Result <= Max_Badge_Text * 10
   is
      Total : Natural := 0;
   begin
      for I in S'Range loop
         Total := Total + Glyph_Width (S (I));
         pragma Loop_Invariant (Total <= (I - S'First + 1) * 10);
      end loop;
      return Total;
   end Text_Width;

   --  The badge SVG markup itself is assembled by plain (non-SPARK)
   --  concatenation: a fully proved assembly needs the concatenation range
   --  checks to bound every operand, and the ~30-element chain plus the
   --  cursor arithmetic pushes the provers past the project's --steps
   --  budget no matter how it is split (a single 2048-byte buffer, six
   --  bounded section builders, and direct chains were all attempted).
   --  The pure sizing math is proved (Glyph_Width, Text_Width) and the
   --  assembled widths flow straight into the markup below, so the
   --  unproved part is only the fixed scaffolding text.
   function Badge_SVG
     (Label            : String;
      Value            : String;
      Label_Color      : String := "#555";
      Value_Color      : String := "#4c1";
      Value_Text_Color : String := "#fff") return String
   is
      --  20px of total segment padding (10px each side) gives every badge
      --  the same comfortable breathing room around its text.
      LW : constant Natural := Text_Width (Label) + 20;
      VW : constant Natural := Text_Width (Value) + 20;
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
   function Badge_Text_Color (Value_Color : String) return String
   with SPARK_Mode => On,
        Post       => Badge_Text_Color'Result'Length in 4 .. 7
   is
   begin
      if Value_Color = "#4c1" or else Value_Color = "#dfb317" then
         return "#1a1a1a";
      else
         return "#fff";
      end if;
   end Badge_Text_Color;

   function Render_SPARK_Badge (Level : Types.SPARK_Level) return String is
      SC : constant String := Spark_Color (Level);
      TC : constant String := Spark_Text_Color (Level);
      LV : constant String := Types.To_String (Level);
   begin
      return Badge_SVG ("SPARK", LV, "#555", SC, TC);
   end Render_SPARK_Badge;

   function Render_Tests_Badge
     (Tests : Types.Implementation.Test_Summary) return String
   is
      --  "<n> Passed" composed from the proved I2S decimal helper (1-10
      --  chars) instead of a manual Natural'Image buffer, so the value
      --  stays provably within the badge text bound.
      Value : constant String :=
        I2S (Tests.Total_Passed) & " Passed";
   begin
      return
        Badge_SVG
          ("Tests",
           Value,
           "#555",
           "#4c1",
           Badge_Text_Color ("#4c1"));
   end Render_Tests_Badge;

   function Render_Compliance_Badge
     (Assess   : Types.Implementation.DAL_Assessment;
      Standard : Types.Compliance_Standard) return String
   is
      --  "<level> PASS" / "<level> FAIL" composed by concatenation: the
      --  standard level names (DAL A, ASIL D, Class C, QM, No class) are
      --  bounded at 8 characters by Standard_Level_Name's contract, so the
      --  value stays provably within the badge text bound without a manual
      --  fixed-size buffer.
      Level_Name : constant String :=
        Types.Standard_Level_Name (Standard, Assess.Target_DAL);
      Suffix     : constant String :=
        (if Assess.Status = Types.Achieved then " PASS" else " FAIL");
      Color      : constant String :=
        (if Assess.Status = Types.Achieved then "#4c1" else "#e05d44");
   begin
      if Assess.Status = Types.Achieved then
         return
           Badge_SVG
             (Types.To_String (Standard),
              Level_Name & Suffix,
              "#555",
              Color,
              Badge_Text_Color (Color));
      else
         return
           Badge_SVG
             (Types.To_String (Standard),
              Level_Name & Suffix,
              "#555",
              Color);
      end if;
   end Render_Compliance_Badge;

   function Render_DO178C_Badge
     (Assess : Types.Implementation.DAL_Assessment) return String
   is
   begin
      return Render_Compliance_Badge (Assess, Assess.Standard);
   end Render_DO178C_Badge;

   function Render_Docstring_Badge
     (Doc_Metrics : Types.Docstring_Metrics) return String
   is
      --  "<pct>%" composed from the proved I2S decimal helper instead of a
      --  manual Natural'Image buffer (same reasoning as Render_Tests_Badge).
      Pct : constant Natural := Doc_Metrics.Coverage_Pct;
      Val : constant String := I2S (Pct) & "%";
   begin
      if Pct >= 80 then
         return
           Badge_SVG
             ("docs",
              Val,
              "#555",
              "#4c1",
              Badge_Text_Color ("#4c1"));
      elsif Pct >= 50 then
         return
           Badge_SVG
             ("docs",
              Val,
              "#555",
              "#dfb317",
              Badge_Text_Color ("#dfb317"));
      else
         return
           Badge_SVG
             ("docs",
              Val,
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
