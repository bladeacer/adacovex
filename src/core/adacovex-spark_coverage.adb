with Ada.Text_IO;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Containers.Vectors;
with Adacovex.Parsers;

package body Adacovex.Spark_Coverage is

   use type Types.Spark_Off_Class;

   --  One skipped entity from gnatprove.out: the file it is declared in
   --  and the line it is declared on. The line is the subprogram's first
   --  line, so consecutive skip lines in the same file bound the statement
   --  ranges that belong to each unproved subprogram.
   type Skip_Rec is record
      File     : Types.Name_Field;
      File_Len : Natural := 0;
      Line     : Natural := 0;
   end record;

   package Skip_Vectors is new Ada.Containers.Vectors (Positive, Skip_Rec);

   --  Add B to A, saturating instead of raising. A report must never abort
   --  on an arithmetic edge.
   --  @param A  Accumulator (updated).
   --  @param B  Addend.
   procedure Saturating_Add (A : in out Natural; B : Natural) is
   begin
      if A > Natural'Last - B then
         A := Natural'Last;
      else
         A := A + B;
      end if;
   end Saturating_Add;

   --  Copy a bounded name into a field, capped at the field length.
   --  @param F  Destination field.
   --  @param Len  Destination length.
   --  @param S  Source string.
   procedure Put_Name
     (F : out Types.Name_Field; Len : out Natural; S : String) is
   begin
      Len := Natural'Min (S'Length, F'Length);
      for I in 1 .. Len loop
         F (I) := S (S'First + I - 1);
      end loop;
   end Put_Name;

   --  Copy a bounded path into a field, capped at the field length.
   --  @param F  Destination field.
   --  @param Len  Destination length.
   --  @param S  Source string.
   procedure Put_Path
     (F : out Types.Path_Field; Len : out Natural; S : String) is
   begin
      Len := Natural'Min (S'Length, F'Length);
      for I in 1 .. Len loop
         F (I) := S (S'First + I - 1);
      end loop;
   end Put_Path;

   --  Strip leading and trailing spaces.
   --  @param S  String to trim.
   --  @return The trimmed string.
   function Trim (S : String) return String is
      F, L : Natural;
   begin
      F := S'First;
      while F <= S'Last and then S (F) = ' ' loop
         pragma Loop_Invariant (F in S'First .. S'Last + 1);
         pragma Loop_Variant (Increases => F);
         F := F + 1;
      end loop;
      L := S'Last;
      while L >= F and then S (L) = ' ' loop
         pragma Loop_Invariant (L in S'First .. S'Last);
         pragma Loop_Variant (Decreases => L);
         L := L - 1;
      end loop;
      if L < F then
         return "";
      end if;
      return S (F .. L);
   end Trim;

   --  The Ada source-unit stem of a file name: the base name without its
   --  extension ("adacovex-cache.adb" becomes "adacovex-cache").
   --  @param Name  File base name.
   --  @return The stem.
   function Stem_Of (Name : String) return String is
   begin
      for I in reverse Name'Range loop
         if Name (I) = '.' then
            return Name (Name'First .. I - 1);
         end if;
      end loop;
      return Name;
   end Stem_Of;

   --  Length of the part of L that is code (everything before the first
   --  Ada comment introducer outside a string literal).
   --  @param L  One physical source line.
   --  @param Code_Len  Length of the code part.
   procedure Strip_Comment (L : String; Code_Len : out Natural)
   with Global => null;

   procedure Strip_Comment (L : String; Code_Len : out Natural) is
      I    : Natural := L'First;
      In_S : Boolean := False;
   begin
      while I <= L'Last loop
         pragma Loop_Invariant (I in L'First .. L'Last + 1);
         pragma Loop_Variant (Increases => I);
         if In_S then
            if L (I) = '"' then
               In_S := False;
            end if;
         elsif L (I) = '"' then
            In_S := True;
         elsif L (I) = '-' and then I < L'Last and then L (I + 1) = '-' then
            Code_Len := I - 1;
            return;
         end if;
         I := I + 1;
      end loop;
      Code_Len := L'Last;
   end Strip_Comment;

   --  The first whitespace-delimited word of L.
   --  @param L  One physical source line.
   --  @return The word, or the empty string when L holds no word.
   function First_Word (L : String) return String
   with Global => null;

   function First_Word (L : String) return String is
      P : Natural := L'First;
   begin
      while P <= L'Last and then L (P) = ' ' loop
         pragma Loop_Invariant (P in L'First .. L'Last + 1);
         pragma Loop_Variant (Increases => P);
         P := P + 1;
      end loop;
      declare
         E : Natural := P - 1;
      begin
         while E < L'Last loop
            pragma Loop_Invariant (E in L'First - 1 .. L'Last);
            pragma Loop_Variant (Increases => E);
            exit when L (E + 1) = ' ';
            E := E + 1;
         end loop;
         if E < P then
            return "";
         end if;
         return L (P .. E);
      end;
   end First_Word;

   --  Whether the code part of L names input or output. Only code counts:
   --  a docstring that names Ada.Text_IO in prose never classifies a
   --  subprogram as I/O-bound.
   --  @param L  One physical source line.
   --  @return True when the line's code references input or output.
   function Code_Is_IO (L : String) return Boolean
   with Global => null;

   function Code_Is_IO (L : String) return Boolean is
      Code_Len : Natural;
   begin
      if L'Length = 0 then
         return False;
      end if;
      Strip_Comment (L, Code_Len);
      if Code_Len < L'First then
         return False;
      end if;
      declare
         C : constant String := L (L'First .. Code_Len);
      begin
         return
           Ada.Strings.Fixed.Index (C, "Ada.Text_IO") > 0
           or else Ada.Strings.Fixed.Index (C, "Ada.Directories") > 0
           or else Ada.Strings.Fixed.Index
             (C, "Ada.Environment_Variables") > 0
           or else Ada.Strings.Fixed.Index (C, "Ada.Command_Line") > 0
           or else Ada.Strings.Fixed.Index (C, "GNAT.OS_Lib") > 0
           or else Ada.Strings.Fixed.Index (C, ".Spawn") > 0;
      end;
   end Code_Is_IO;

   function Count_Line_Statements (Line : String) return Natural is
      Code_Len : Natural;
   begin
      if Line'Length = 0 then
         return 0;
      end if;
      Strip_Comment (Line, Code_Len);
      if Code_Len < Line'First then
         return 0;
      end if;
      declare
         W : constant String := First_Word (Line (Line'First .. Code_Len));
      begin
         if W'Length = 0 then
            return 0;
         elsif W = "end" or else W = "then" or else W = "is"
           or else W = "in" or else W = "renames" or else W = "with"
           or else W = "use" or else W = "package" or else W = "procedure"
           or else W = "function" or else W = "type" or else W = "subtype"
           or else W = "record" or else W = "separate" or else W = "generic"
           or else W = "overriding" or else W = "others"
           or else W = "exception" or else W = "private"
           or else W = "abstract" or else W = "synchronized"
         then
            --  Closing and connective keywords, and declarations. The
            --  caller filters declarations out anyway; returning zero here
            --  keeps the rule honest for a line read on its own.
            return 0;
         elsif W = "if" or else W = "elsif" or else W = "else"
           or else W = "case" or else W = "when" or else W = "while"
           or else W = "for" or else W = "loop" or else W = "declare"
           or else W = "begin" or else W = "pragma"
           or else W = "return" or else W = "raise" or else W = "exit"
           or else W = "goto" or else W = "null" or else W = "delay"
         then
            --  A compound-statement head, or a statement with its own
            --  keyword.
            return 1;
         else
            declare
               Last : Natural := Code_Len;
            begin
               while Last >= Line'First and then Line (Last) = ' ' loop
                  pragma Loop_Invariant (Last in Line'First .. Line'Last);
                  pragma Loop_Variant (Decreases => Last);
                  Last := Last - 1;
               end loop;
               if Last >= Line'First and then Line (Last) = ';' then
                  return 1;
               end if;
               return 0;
            end;
         end if;
      end;
   end Count_Line_Statements;

   function Text_Opts_Out (Text : String) return Boolean is
      P    : Natural := Text'First;
      In_C : Boolean := False;
      In_S : Boolean := False;
      Saw  : Boolean := False;
   begin
      if Text'Length = 0 then
         return False;
      end if;
      --  The opt-out is the only directive that makes a unit irreducible:
      --  it is a deliberate package-level pragma or aspect, never a
      --  subprogram that merely reaches a non-formal container. Prose
      --  that discusses the pragma is skipped with the rest of the
      --  comment text.
      while P <= Text'Last loop
         pragma Loop_Invariant (P in Text'First .. Text'Last + 1);
         pragma Loop_Variant (Increases => P);
         if In_C then
            if Text (P) = ASCII.LF then
               In_C := False;
            end if;
         elsif In_S then
            if Text (P) = '"' then
               In_S := False;
            end if;
         elsif Text (P) = '-' and then P < Text'Last
           and then Text (P + 1) = '-'
         then
            In_C := True;
            P := P + 1;
         elsif Text (P) = '"' then
            In_S := True;
         elsif Ada.Strings.Fixed.Index
           (Text (P .. Text'Last), "SPARK_Mode") = Text'First
         then
            Saw := True;
            exit;
         end if;
         P := P + 1;
      end loop;
      if not Saw then
         return False;
      end if;
      return
        Ada.Strings.Fixed.Index (Text, "(Off)") > 0
        or else Ada.Strings.Fixed.Index (Text, "( Off") > 0
        or else Ada.Strings.Fixed.Index (Text, "=> Off") > 0
        or else Ada.Strings.Fixed.Index (Text, "=>Off") > 0;
   end Text_Opts_Out;

   function Text_Is_IO_Bound (Text : String) return Boolean is
   begin
      return
        Ada.Strings.Fixed.Index (Text, "Ada.Text_IO") > 0
        or else Ada.Strings.Fixed.Index (Text, "Ada.Directories") > 0
        or else Ada.Strings.Fixed.Index
          (Text, "Ada.Environment_Variables") > 0
        or else Ada.Strings.Fixed.Index (Text, "Ada.Command_Line") > 0
        or else Ada.Strings.Fixed.Index (Text, "GNAT.OS_Lib") > 0
        or else Ada.Strings.Fixed.Index (Text, ".Spawn") > 0
        or else Ada.Strings.Fixed.Index (Text, "OS_Lib.Create") > 0;
   end Text_Is_IO_Bound;

   procedure Metric_Values
     (Totals : Types.Implementation.Spark_Coverage_Totals;
      M      : Types.Spark_Metric_Kind;
      Proved : out Natural;
      Total  : out Natural)
   is
   begin
      case M is
         when Types.Metric_Statements =>
            Proved := Totals.Stmts_Proved;
            Total  := Totals.Stmts_Total;

         when Types.Metric_Subprograms =>
            Proved := Totals.Subs_Proved;
            Total  := Totals.Subs_Total;

         when Types.Metric_Checks    =>
            Proved := Totals.Checks_Proved;
            Total  := Totals.Checks_Total;
      end case;
   end Metric_Values;

   procedure Group_Values
     (G      : Types.Implementation.Spark_Coverage_Group;
      M      : Types.Spark_Metric_Kind;
      Proved : out Natural;
      Total  : out Natural)
   is
   begin
      case M is
         when Types.Metric_Statements =>
            Proved := G.Stmts_Proved;
            Total  := G.Stmts_Total;

         when Types.Metric_Subprograms =>
            Proved := G.Subs_Proved;
            Total  := G.Subs_Total;

         when Types.Metric_Checks    =>
            Proved := G.Checks_Proved;
            Total  := G.Checks_Total;
      end case;
   end Group_Values;

   --  A verified percentage with one decimal, or "n/a" when the
   --  denominator is zero.
   --  @param Proved  Numerator.
   --  @param Total  Denominator.
   --  @return The percentage text.
   function Pct_Str (Proved, Total : Natural) return String is
      Img : constant String := Natural'Image (Proved);
   begin
      if Total = 0 then
         return "n/a";
      end if;
      declare
         Scale : constant Long_Long_Integer :=
           (Long_Long_Integer (Proved) * 1000) / Long_Long_Integer (Total);
         Whole : constant String :=
           Long_Long_Integer'Image (Scale / 10);
         Frac  : constant String :=
           Long_Long_Integer'Image (Scale mod 10);
      begin
         return Whole (Whole'First + 1 .. Whole'Last)
           & "." & Frac (Frac'First + 1 .. Frac'Last);
      end;
   end Pct_Str;

   function Gate_Failure_Message
     (Metric  : Types.Spark_Metric_Kind;
      Proved  : Natural;
      Total   : Natural;
      Min_Pct : Natural) return String
   is
   begin
      return
        "SPARK coverage below the required threshold: "
        & Types.To_String (Metric)
        & " coverage "
        & Pct_Str (Proved, Total)
        & "% (proved "
        & Natural'Image (Proved) (2 .. Natural'Image (Proved)'Last)
        & " of "
        & Natural'Image (Total) (2 .. Natural'Image (Total)'Last)
        & ") is below the required "
        & Natural'Image (Min_Pct) (2 .. Natural'Image (Min_Pct)'Last)
        & "%";
   end Gate_Failure_Message;

   --  Index of the unit with the given stem in Units, appending a fresh
   --  record when the stem is not present yet.
   --  @param Units  Unit records (updated).
   --  @param Stem  Ada package base name (file name without extension).
   --  @return The 1-based index of the unit.
   function Find_Unit
     (Units : in out Types.Implementation.Spark_Coverage_Vectors.Vector;
      Stem  : String) return Natural
   is
      Rec : Types.Implementation.Spark_Coverage_Unit;
   begin
      for I in 1 .. Integer (Units.Length) loop
         if Units (I).Name_Len = Stem'Length
           and then Units (I).Name (1 .. Stem'Length) = Stem
         then
            return I;
         end if;
      end loop;
      Put_Name (Rec.Name, Rec.Name_Len, Stem);
      Units.Append (Rec);
      return Integer (Units.Length);
   end Find_Unit;

   --  Whether Dir should not be descended into during the source walk.
   --  @param Name  Directory base name.
   --  @return True when the walk skips the directory.
   function Skip_Dir (Name : String) return Boolean is
   begin
      return
        Name = ".git" or else Name = ".jj" or else Name = ".hg"
        or else Name = ".svn" or else Name = ".adacovex"
        or else Name = "alire" or else Name = "obj" or else Name = "bin"
        or else Name = "_build" or else Name = "node_modules"
        or else Name = "__pycache__" or else Name = ".venv"
        or else Name = "tests";
   end Skip_Dir;

   --  Read a whole text file into Buf. A file with a physical line longer
   --  than Buf is reported as unreadable, never truncated: a truncated
   --  source file would report a false statement count.
   --  @param Path  File to read.
   --  @param Buf  Destination buffer.
   --  @param Len  Number of characters stored in Buf.
   --  @param Ok  False when the file is missing, unreadable, or overlong.
   procedure Read_Text
     (Path : String; Buf : out String; Len : out Natural; Ok : out Boolean);

   procedure Read_Text
     (Path : String; Buf : out String; Len : out Natural; Ok : out Boolean)
   is
      use Ada.Text_IO;
      F        : File_Type;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Overflow : Boolean;
      No       : Natural := 0;
   begin
      Len := 0;
      Ok  := False;
      begin
         Open (F, In_File, Path);
      exception
         when others =>
            return;
      end;
      begin
         while not End_Of_File (F) loop
            No := No + 1;
            Adacovex.Parsers.Read_Line (F, Path, No, Line, Last, Overflow);
            exit when Overflow;
            if Len + Last >= Buf'Length then
               Close (F);
               return;
            end if;
            Buf (Len + 1 .. Len + Last) := Line (1 .. Last);
            Len := Len + Last;
            Buf (Len + 1) := ASCII.LF;
            Len := Len + 1;
         end loop;
      exception
         when others =>
            if Is_Open (F) then
               Close (F);
            end if;
            return;
      end;
      Close (F);
      Ok := True;
   end Read_Text;

   --  Parse `in unit <name>, <n> subprograms and packages out of <m>
   --  analyzed`. Returns False for any other line.
   --  @param Line  One line of gnatprove.out.
   --  @param Unit  Unit name (out).
   --  @param Proved  Subprograms gnatprove proved in the unit (out).
   --  @param Total  Subprograms gnatprove considered in the unit (out).
   --  @return True when the line is a per-unit summary line.
   function Parse_Unit_Line
     (Line   : String;
      Unit   : out String;
      Proved : out Natural;
      Total  : out Natural) return Boolean
   with Global => null;

   function Parse_Unit_Line
     (Line   : String;
      Unit   : out String;
      Proved : out Natural;
      Total  : out Natural) return Boolean
   is
      Prefix : constant String := "in unit ";
      Mid    : constant String := ", ";
      Suffix : constant String := " subprograms and packages out of ";
      Suffix2 : constant String := " analyzed";
   begin
      Proved := 0;
      Total  := 0;
      Unit   := (1 .. 0);
      if Line'Length < Prefix'Length + Mid'Length + Suffix'Length then
         return False;
      end if;
      if Line (Line'First .. Line'First + Prefix'Length - 1) /= Prefix then
         return False;
      end if;
      declare
         P : constant Natural := Line'First + Prefix'Length;
         M : constant Natural :=
           Ada.Strings.Fixed.Index (Line (P .. Line'Last), Mid);
      begin
         if M = 0 then
            return False;
         end if;
         declare
            Name_Str : constant String := Line (P .. M - 1);
            Rest     : constant String := Line (M + Mid'Length .. Line'Last);
            Q        : constant Natural :=
              Ada.Strings.Fixed.Index (Rest, Suffix);
         begin
            if Q = 0
              or else Rest (Rest'Last - Suffix2'Length + 1 .. Rest'Last)
                       /= Suffix2
            then
               return False;
            end if;
            declare
               Head : constant String := Rest (Rest'First .. Q - 1);
               R    : constant Natural :=
                 Ada.Strings.Fixed.Index (Head, ", ");
               Proved_N : constant String :=
                 (if R = 0 then Head else Head (Head'First .. R - 1));
               Total_N  : constant String :=
                 (if R = 0
                  then ""
                  else Head (R + Mid'Length .. Head'Last));
            begin
               Proved := Parse_Natural (Proved_N, 0);
               Total  := Parse_Natural (Total_N, 0);
               Unit   := Name_Str;
               return True;
            end;
         end;
      end;
   end Parse_Unit_Line;

   --  Parse `<Entity> at <file>:<line> skipped; <reason>`. Returns False
   --  for any other line.
   --  @param Line  One line of gnatprove.out.
   --  @param File  File the entity is declared in (out).
   --  @param Line_No  Declaration line (out).
   --  @return True when the line reports a skipped entity.
   function Parse_Skip_Line
     (Line : String; File : out String; Line_No : out Natural) return Boolean
   with Global => null;

   function Parse_Skip_Line
     (Line : String; File : out String; Line_No : out Natural) return Boolean
   is
      At_Pos : constant Natural :=
        Ada.Strings.Fixed.Index (Line, " at ");
   begin
      File    := (1 .. 0);
      Line_No := 0;
      if At_Pos = 0 or else Ada.Strings.Fixed.Index (Line, " skipped; ") = 0
      then
         return False;
      end if;
      declare
         Tail : constant String :=
           Line (At_Pos + 4 .. Ada.Strings.Fixed.Index (Line, " skipped; ") - 1);
         Colon : constant Natural :=
           Ada.Strings.Fixed.Index (Tail, ":");
      begin
         if Colon = 0 then
            return False;
         end if;
         Line_No := Parse_Natural
           (Tail (Colon + 1 .. Tail'Last), 0);
         if Line_No = 0 then
            return False;
         end if;
         File := Tail (Tail'First .. Colon - 1);
         return True;
      end;
   end Parse_Skip_Line;

   --  Read gnatprove.out and record, per unit, the proved/total
   --  subprogram split and every skipped entity with its file and line.
   procedure Read_Proof_Summary
     (Path   : String;
      Units  : in out Types.Implementation.Spark_Coverage_Vectors.Vector;
      Skips  : out Skip_Vectors.Vector;
      Ok     : out Boolean);

   procedure Read_Proof_Summary
     (Path   : String;
      Units  : in out Types.Implementation.Spark_Coverage_Vectors.Vector;
      Skips  : out Skip_Vectors.Vector;
      Ok     : out Boolean)
   is
      use Ada.Text_IO;
      F        : File_Type;
      Line     : String (1 .. Types.Max_Line);
      Last     : Natural;
      Overflow : Boolean;
      No       : Natural := 0;
   begin
      Skips.Clear;
      Ok := False;
      begin
         Open (F, In_File, Path);
      exception
         when others =>
            return;
      end;
      begin
         while not End_Of_File (F) loop
            No := No + 1;
            Adacovex.Parsers.Read_Line (F, Path, No, Line, Last, Overflow);
            exit when Overflow;
            declare
               L : constant String := Trim (Line (1 .. Last));
            begin
               if Parse_Unit_Line (L, Unused, Unused_N, Unused_N2) then
                  null;
               end if;
            end;
         end loop;
      exception
         when others =>
            if Is_Open (F) then
               Close (F);
            end if;
            return;
      end;
      Close (F);
      Ok := True;
   end Read_Proof_Summary;

end Adacovex.Spark_Coverage;