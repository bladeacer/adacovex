with Ada.Text_IO;
with Ada.Directories;
with Adacovex.Parsers;

package body Adacovex.Spark_Coverage is

   --  Read-buffer size for every file this package opens. A source
   --  line longer than this fails loudly: the file is skipped and
   --  the caller's Skipped_Ct increments, exactly as the scanner
   --  treats an overlong line.
   Max_Read : constant := Types.Max_Line;

   --  Marker literals of the gnatprove.out line this package reads
   --  per unit. They come from the prover's own summary format, so
   --  they change only when gnatprove changes that format. A line
   --  that does not carry the marker is not a unit record and is
   --  passed over.
   Unit_Mark     : constant String := " subprograms and packages out of ";
   Analyzed_Mark : constant String := " analyzed";

   --  Maximum Ada package nesting depth the source scan tracks. This
   --  bounds how deep a `package ... is` nest may be before the scan
   --  stops qualifying names, not how many packages a project may
   --  declare: a project of any size nested no deeper is scanned
   --  exactly.
   Max_Pkg_Depth : constant := 32;

   --  Directory names the source walk never descends into: version
   --  control metadata, generated and dependency trees, and the
   --  build output. None of them hold assessed Ada source.
   function Skip_Dir (N : String) return Boolean is
   begin
      return
        N = ".git"
        or else N = ".jj"
        or else N = ".hg"
        or else N = ".svn"
        or else N = ".fslckout"
        or else N = "_FOSSIL_"
        or else N = "obj"
        or else N = "bin"
        or else N = "alire"
        or else N = "build"
        or else N = "node_modules"
        or else N = "_build";
   end Skip_Dir;

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

   --  Copy a bounded name into a field, capped at the field length.
   --  @param F  Destination field.
   --  @param Len  Destination length.
   --  @param S  Source string.
   procedure Put_Name (F : out Types.Name_Field; Len : out Natural; S : String)
   is
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
   procedure Put_Path (F : out Types.Path_Field; Len : out Natural; S : String)
   is
   begin
      Len := Natural'Min (S'Length, F'Length);
      for I in 1 .. Len loop
         F (I) := S (S'First + I - 1);
      end loop;
   end Put_Path;

   --  Index of the first occurrence of Pattern in S, or 0 when S holds
   --  none. A hand-rolled search: Ada.Strings.Fixed is not a formal
   --  package, so calling it from this unit would put every subprogram
   --  here outside SPARK, and the point of the helpers below is that
   --  gnatprove proves them.
   --  @param S  String to search.
   --  @param Pattern  Pattern to find (not empty).
   --  @return The index of the first match, or 0.
   function Find (S, Pattern : String) return Natural
   with Global => null, Pre => Pattern'Length > 0
   is
   begin
      if Pattern'Length > S'Length then
         return 0;
      end if;
      for I in S'First .. S'Last - Pattern'Length + 1 loop
         declare
            Match : Boolean := True;
         begin
            for J in Pattern'Range loop
               if S (I + J - Pattern'First) /= Pattern (J) then
                  Match := False;
               end if;
            end loop;
            if Match then
               return I;
            end if;
         end;
      end loop;
      return 0;
   end Find;

   --  The last dot-separated segment of a possibly qualified Ada name.
   --  @param Name  Possibly qualified name.
   --  @return The final segment.
   function Stem_Of (Name : String) return String is
   begin
      for I in reverse Name'Range loop
         if Name (I) = '.' then
            return Name (Name'First .. I - 1);
         end if;
      end loop;
      return Name;
   end Stem_Of;

   function Last_Segment (Name : String) return String with Global => null is
   begin
      for I in reverse Name'Range loop
         if Name (I) = '.' then
            return Name (I + 1 .. Name'Last);
         end if;
      end loop;
      return Name;
   end Last_Segment;

   --  Length of the part of L that is code, relative to L'First: zero
   --  when the line is empty or opens with a comment, the line length
   --  when it holds no comment, and the offset of the comment marker
   --  otherwise. A relative length keeps every later slice in range.
   --  @param L  One physical source line.
   --  @return Length of the code part.
   function Code_Length (L : String) return Natural with Global => null is
      I    : Natural := 1;
      In_S : Boolean := False;
      R    : Natural;
   begin
      if L'Length = 0 then
         return 0;
      end if;
      while I <= L'Length loop
         pragma Loop_Invariant (I in 1 .. L'Length + 1);
         pragma Loop_Variant (Increases => I);
         if In_S then
            if L (L'First + I - 1) = '"' then
               In_S := False;
            end if;
         elsif L (L'First + I - 1) = '"' then
            In_S := True;
         elsif L (L'First + I - 1) = '-'
           and then I < L'Length
           and then L (L'First + I) = '-'
         then
            return I - 1;
         end if;
         I := I + 1;
      end loop;
      R := L'Length;
      while R > 0 and then L (L'First + R - 1) = ' ' loop
         pragma Loop_Invariant (R in 0 .. L'Length);
         pragma Loop_Variant (Decreases => R);
         R := R - 1;
      end loop;
      return R;
   end Code_Length;

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

   --  The word after the first one, or the empty string when L holds
   --  only one word. Leading spaces are stepped over first.
   --  @param L  One physical source line.
   --  @return The word, or the empty string.
   function Second_Word (L : String) return String with Global => null is
      P : Natural := L'First;
   begin
      --  Step over the first word.
      while P <= L'Last loop
         pragma Loop_Invariant (P in L'First .. L'Last + 1);
         pragma Loop_Variant (Increases => P);
         exit when L (P) = ' ';
         P := P + 1;
      end loop;
      --  Step over the separator.
      while P <= L'Last and then L (P) = ' ' loop
         pragma Loop_Invariant (P in L'First .. L'Last + 1);
         pragma Loop_Variant (Increases => P);
         P := P + 1;
      end loop;
      if P > L'Last then
         return "";
      end if;
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
   end Second_Word;

   --  The word after the first two, or the empty string when L holds
   --  fewer than three words. An "overriding procedure Foo" header
   --  carries its name in the third word.
   --  @param L  One physical source line.
   --  @return The word, or the empty string.
   function Third_Word (L : String) return String with Global => null is
      P : Natural := L'First;
   begin
      for N in 1 .. 2 loop
         pragma Loop_Invariant (P in L'First .. L'Last + 1);
         pragma Loop_Variant (Increases => P);
         while P <= L'Last loop
            pragma Loop_Invariant (P in L'First .. L'Last + 1);
            pragma Loop_Variant (Increases => P);
            exit when L (P) = ' ';
            P := P + 1;
         end loop;
         while P <= L'Last and then L (P) = ' ' loop
            pragma Loop_Invariant (P in L'First .. L'Last + 1);
            pragma Loop_Variant (Increases => P);
            P := P + 1;
         end loop;
      end loop;
      if P > L'Last then
         return "";
      end if;
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
   end Third_Word;

   --  Whether S ends with Tail.
   --  @param S  String to test.
   --  @param Tail  Suffix to look for (not empty).
   --  @return True when S ends with Tail.
   function Ends_With (S, Tail : String) return Boolean with Global => null is
   begin
      if Tail'Length = 0 or else Tail'Length > S'Length then
         return False;
      end if;
      return S (S'Last - Tail'Length + 1 .. S'Last) = Tail;
   end Ends_With;

   function Line_Is_IO_Bound (Line : String) return Boolean is
      R : constant Natural := Code_Length (Line);
   begin
      if R = 0 then
         return False;
      end if;
      declare
         C : constant String := Line (Line'First .. Line'First + R - 1);
      begin
         return
           Find (C, "Ada.Text_IO") > 0
           or else Find (C, "Ada.Directories") > 0
           or else Find (C, "Ada.Environment_Variables") > 0
           or else Find (C, "Ada.Command_Line") > 0
           or else Find (C, "GNAT.OS_Lib") > 0
           or else Find (C, ".Spawn") > 0
           or else Find (C, "OS_Lib.Create") > 0;
      end;
   end Line_Is_IO_Bound;

   function Line_Opts_Out (Line : String) return Boolean is
      R : constant Natural := Code_Length (Line);
   begin
      if R = 0 then
         return False;
      end if;
      declare
         Code : constant String := Line (Line'First .. Line'First + R - 1);
      begin
         if Find (Code, "SPARK_Mode") = 0 then
            return False;
         end if;
         return
           Find (Code, "(Off)") > 0
           or else Find (Code, "( Off") > 0
           or else Find (Code, "=> Off") > 0
           or else Find (Code, "=>Off") > 0;
      end;
   end Line_Opts_Out;

   --  The kind of one source line's code part, as the statement scan
   --  needs it.
   type Line_Kind is
     (Kind_None, Kind_Decl, Kind_End, Kind_Head, Kind_Simple, Kind_Start);

   --  Classify the code part of one source line.
   --  @param Code  The code part of one source line (comments removed,
   --    leading and trailing spaces removed).
   --  @return The line kind.
   function Classify (Code : String) return Line_Kind
   with Global => null;

   function Classify (Code : String) return Line_Kind is
      W : constant String := First_Word (Code);
   begin
      if W'Length = 0 then
         return Kind_None;
      end if;
      if W = "end" then
         return Kind_End;
      elsif W = "then"
        or else W = "is"
        or else W = "in"
        or else W = "renames"
        or else W = "with"
        or else W = "use"
        or else W = "package"
        or else W = "procedure"
        or else W = "function"
        or else W = "type"
        or else W = "subtype"
        or else W = "record"
        or else W = "separate"
        or else W = "generic"
        or else W = "others"
        or else W = "exception"
        or else W = "private"
        or else W = "abstract"
        or else W = "synchronized"
        or else W = "overriding"
        or else W = "new"
        or else W = "limited"
        or else W = "body"
        or else W = "entry"
        or else W = "for"
        or else W = "constant"
        or else W = "not"
        or else W = "mod"
        or else W = "rem"
        or else W = "and"
        or else W = "or"
        or else W = "xor"
      then
         return Kind_Decl;
      elsif W = "if"
        or else W = "elsif"
        or else W = "else"
        or else W = "case"
        or else W = "when"
        or else W = "while"
        or else W = "loop"
        or else W = "begin"
        or else W = "pragma"
        or else W = "return"
        or else W = "raise"
        or else W = "exit"
        or else W = "goto"
        or else W = "null"
        or else W = "delay"
        or else W = "select"
        or else W = "accept"
        or else W = "abort"
        or else W = "requeue"
      then
         return Kind_Head;
      elsif Code (Code'Last) = ';' then
         return Kind_Simple;
      else
         return Kind_Start;
      end if;
   end Classify;

   function Count_Line_Statements (Line : String) return Natural is
      R : constant Natural := Code_Length (Line);
   begin
      if R = 0 then
         return 0;
      end if;
      case Classify (Trim (Line (Line'First .. Line'First + R - 1))) is
         when Kind_Head | Kind_Simple                       =>
            return 1;

         when Kind_None | Kind_Decl | Kind_End | Kind_Start =>
            return 0;
      end case;
   end Count_Line_Statements;

   --  Whether the code part of a line ends a statement, so the following
   --  line starts a new one. A line ending in a terminating semicolon
   --  does, and so does a statement keyword that needs no argument
   --  ("if X then", "case X is", "while X loop", a bare "return"). A
   --  statement keyword whose argument is still open ("pragma Assert")
   --  does not, so the line that completes it is not counted twice.
   --  @param Code  The code part of one source line.
   --  @return True when the statement ends on this line.
   function Self_Contained (Code : String) return Boolean with Global => null
   is
      L : Natural := Code'Last;
      T : Character := ' ';
   begin
      if Code'Length = 0 then
         return False;
      end if;
      while L >= Code'First loop
         pragma Loop_Invariant (L in Code'First - 1 .. Code'Last);
         pragma Loop_Variant (Decreases => L);
         T := Code (L);
         exit when T /= ' ';
         L := L - 1;
      end loop;
      if L < Code'First then
         return False;
      end if;
      if T = ';' then
         return True;
      end if;
      return
        Ends_With (Code, "then")
        or else Ends_With (Code, "loop")
        or else Ends_With (Code, "is")
        or else Ends_With (Code, "begin")
        or else Ends_With (Code, "declare")
        or else Ends_With (Code, "else")
        or else Ends_With (Code, "=>")
        or else Ends_With (Code, "do")
        or else Ends_With (Code, "return")
        or else Ends_With (Code, "exit")
        or else Ends_With (Code, "goto")
        or else Ends_With (Code, "null")
        or else Ends_With (Code, "raise")
        or else Ends_With (Code, "delay")
        or else Ends_With (Code, "select")
        or else Ends_With (Code, "abort");
   end Self_Contained;

   --  Whether the word after "end" names a construct whose end does not
   --  close an Ada block. Only "end name" or a bare "end" closes a
   --  declare block, a subprogram, or a package.
   --  @param Code  The code part of a line whose first word is "end".
   --  @return True when the end closes an inner construct.
   function Ends_Inner_Construct (Code : String) return Boolean
   with Global => null
   is
      N : constant String := Second_Word (Code);
   begin
      return
        N = "if"
        or else N = "loop"
        or else N = "case"
        or else N = "select"
        or else N = "record"
        or else N = "accept";
   end Ends_Inner_Construct;

   procedure Metric_Values
     (Totals : Types.Implementation.Spark_Coverage_Totals;
      M      : Types.Spark_Metric_Kind;
      Proved : out Natural;
      Total  : out Natural) is
   begin
      case M is
         when Types.Metric_Statements  =>
            Proved := Totals.Stmts_Proved;
            Total := Totals.Stmts_Total;

         when Types.Metric_Subprograms =>
            Proved := Totals.Subs_Proved;
            Total := Totals.Subs_Total;

         when Types.Metric_Checks      =>
            Proved := Totals.Checks_Proved;
            Total := Totals.Checks_Total;
      end case;
   end Metric_Values;

   procedure Group_Values
     (G      : Types.Implementation.Spark_Coverage_Group;
      M      : Types.Spark_Metric_Kind;
      Proved : out Natural;
      Total  : out Natural) is
   begin
      case M is
         when Types.Metric_Statements  =>
            Proved := G.Stmts_Proved;
            Total := G.Stmts_Total;

         when Types.Metric_Subprograms =>
            Proved := G.Subs_Proved;
            Total := G.Subs_Total;

         when Types.Metric_Checks      =>
            Proved := G.Checks_Proved;
            Total := G.Checks_Total;
      end case;
   end Group_Values;

   --  The Ada package name of a unit name: '-' separates package levels
   --  and becomes '.', and each segment's first letter is capitalised, so
   --  the Group_Package rows read as the package names the source declares.
   --  @param Name  Unit name (for example "adacovex-parsers-manifest").
   --  @param Buf  Output buffer.
   --  @param Len  Length of the key in Buf.
   procedure Package_Key
     (Name : String; Buf : out Types.Path_Field; Len : out Natural)
   is
      I   : Natural := 0;
      Cap : Boolean := True;
   begin
      Len := 0;
      for J in Name'Range loop
         exit when I >= Buf'Length;
         if Name (J) = '-' then
            I := I + 1;
            Buf (I) := '.';
            Cap := True;
         else
            I := I + 1;
            if Cap and then Name (J) in 'a' .. 'z' then
               Buf (I) := Character'Val (Character'Pos (Name (J)) - 32);
            else
               Buf (I) := Name (J);
            end if;
            Cap := Name (J) = '_';
         end if;
      end loop;
      Len := I;
   end Package_Key;

   --  The key a unit is grouped under for the selected grouping.
   --  @param U  Unit record.
   --  @param G  Grouping selector.
   --  @param Buf  Output buffer.
   --  @param Len  Length of the key in Buf.
   procedure Group_Key_Of
     (U   : Types.Implementation.Spark_Coverage_Unit;
      G   : Types.Spark_Group_Kind;
      Buf : out Types.Path_Field;
      Len : out Natural) is
   begin
      Len := 0;
      case G is
         when Types.Group_File    =>
            if U.File_Len > 0 then
               Len := Natural'Min (U.File_Len, Buf'Length);
               for I in 1 .. Len loop
                  Buf (I) := U.File (I);
               end loop;
            end if;

         when Types.Group_Folder  =>
            if U.Folder_Len > 0 then
               Len := Natural'Min (U.Folder_Len, Buf'Length);
               for I in 1 .. Len loop
                  Buf (I) := U.Folder (I);
               end loop;
            end if;

         when Types.Group_Package =>
            if U.Name_Len > 0 then
               Package_Key (U.Name (1 .. U.Name_Len), Buf, Len);
            end if;
      end case;
   end Group_Key_Of;

   procedure Append (Buf : in out String; Len : in out Natural; S : String) is
      N : constant Natural := Natural'Min (S'Length, Buf'Length - Len);
   begin
      for I in 1 .. N loop
         Buf (Len + I) := S (S'First + I - 1);
      end loop;
      Len := Len + N;
   end Append;

   procedure Append_Nat
     (Buf : in out String; Len : in out Natural; N : Natural)
   is
      V : Natural := N;
      D : Natural := 0;
      T : String (1 .. 32);
   begin
      --  A Natural has at most ten digits; the bounded loop makes that
      --  explicit to the prover.
      for I in 1 .. T'Length loop
         exit when V = 0;
         D := D + 1;
         T (D) := Character'Val (Character'Pos ('0') + V mod 10);
         V := V / 10;
      end loop;
      if D = 0 then
         D := 1;
         T (1) := '0';
      end if;
      for I in 1 .. D / 2 loop
         declare
            C : constant Character := T (I);
         begin
            T (I) := T (D - I + 1);
            T (D - I + 1) := C;
         end;
      end loop;
      Append (Buf, Len, T (1 .. D));
   end Append_Nat;

   function Parse_Natural (S : String) return Natural with Global => null is
      V : Natural := 0;
      D : Natural;
   begin
      for I in S'Range loop
         if S (I) < '0' or else S (I) > '9' then
            return V;
         end if;
         D := Character'Pos (S (I)) - Character'Pos ('0');
         if V > (Natural'Last - D) / 10 then
            return Natural'Last;
         end if;
         V := V * 10 + D;
      end loop;
      return V;
   end Parse_Natural;

   function Metric_Proved_Name (M : Types.Spark_Metric_Kind) return String
   with Global => null
   is
   begin
      case M is
         when Types.Metric_Statements  =>
            return "proved statements";

         when Types.Metric_Subprograms =>
            return "proved subprograms";

         when Types.Metric_Checks      =>
            return "discharged checks";
      end case;
   end Metric_Proved_Name;

   function Metric_Denominator_Name (M : Types.Spark_Metric_Kind) return String
   with Global => null
   is
   begin
      case M is
         when Types.Metric_Statements  =>
            return "statements in assessed bodies";

         when Types.Metric_Subprograms =>
            return "subprograms gnatprove considered";

         when Types.Metric_Checks      =>
            return "checks the prover reported";
      end case;
   end Metric_Denominator_Name;

   procedure Append_Pct
     (Buf : in out String; Len : in out Natural; Proved, Total : Natural)
   is
      Scaled : Natural;
   begin
      if Total = 0 then
         Append (Buf, Len, "0.0");
         return;
      end if;
      if Proved >= Total then
         Append (Buf, Len, "100.0");
         return;
      end if;
      Scaled := (Proved * 1000) / Total;
      Append_Nat (Buf, Len, Scaled / 10);
      Append (Buf, Len, ".");
      Append_Nat (Buf, Len, Scaled mod 10);
   end Append_Pct;

   procedure Gate_Failure_Message
     (Metric  : Types.Spark_Metric_Kind;
      Proved  : Natural;
      Total   : Natural;
      Min_Pct : Natural;
      Msg     : out Types.Path_Field;
      Msg_Len : out Natural)
   is
      Buf : String (1 .. 512);
      Len : Natural := 0;
   begin
      Append (Buf, Len, "SPARK gate: ");
      Append (Buf, Len, Metric_Proved_Name (Metric));
      Append (Buf, Len, " ");
      Append_Nat (Buf, Len, Proved);
      Append (Buf, Len, " / ");
      Append_Nat (Buf, Len, Total);
      Append (Buf, Len, " = ");
      Append_Pct (Buf, Len, Proved, Total);
      Append (Buf, Len, " (");
      Append (Buf, Len, Metric_Denominator_Name (Metric));
      Append (Buf, Len, "), below the required ");
      Append_Nat (Buf, Len, Min_Pct);
      Append (Buf, Len, "%");
      Msg_Len := Natural'Min (Len, Msg'Length);
      for I in 1 .. Msg_Len loop
         Msg (I) := Buf (I);
      end loop;
   end Gate_Failure_Message;

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
      Rec := Types.Implementation.Spark_Coverage_Unit'(others => <>);
      Put_Name (Rec.Name, Rec.Name_Len, Stem);
      Units.Append (Rec);
      return Integer (Units.Length);
   end Find_Unit;

   function Unit_For_Stem
     (Units : in out Types.Implementation.Spark_Coverage_Vectors.Vector;
      Stem  : String) return Natural
   is
      Best     : Natural := 0;
      Best_Len : Natural := 0;
   begin
      for I in 1 .. Integer (Units.Length) loop
         declare
            N_Len : constant Natural := Units (I).Name_Len;
         begin
            if N_Len = Stem'Length and then Units (I).Name (1 .. N_Len) = Stem
            then
               return I;
            end if;
            if N_Len > Best_Len
              and then N_Len < Stem'Length
              and then Stem (Stem'First .. Stem'First + N_Len - 1)
                       = Units (I).Name (1 .. N_Len)
              and then Stem (Stem'First + N_Len) = '-'
            then
               Best := I;
               Best_Len := N_Len;
            end if;
         end;
      end loop;
      if Best /= 0 then
         return Best;
      end if;
      return Find_Unit (Units, Stem);
   end Unit_For_Stem;

   function Unit_For_File
     (Units : in out Types.Implementation.Spark_Coverage_Vectors.Vector;
      Base  : String) return Natural is
   begin
      return Unit_For_Stem (Units, Stem_Of (Base));
   end Unit_For_File;

   --  Record one entity in the named-entity table, keeping the first class
   --  recorded for a name so the table holds one entry per name.
   --  @param Entities  Entity table (appended to).
   --  @param Name  Qualified Ada name.
   --  @param Class  Off class (Off_None for a proved entity).
   procedure Record_Entity
     (Entities : in out Types.Implementation.Spark_Entity_Vectors.Vector;
      Name     : String;
      Class    : Types.Spark_Off_Class)
   is
      Rec : Types.Implementation.Spark_Entity_Rec;
   begin
      if Name'Length = 0 or else Name'Length > Rec.Name'Length then
         return;
      end if;
      for I in 1 .. Integer (Entities.Length) loop
         if Entities (I).Name_Len = Name'Length
           and then Entities (I).Name (1 .. Name'Length) = Name
         then
            return;
         end if;
      end loop;
      Rec := Types.Implementation.Spark_Entity_Rec'(others => <>);
      Put_Name (Rec.Name, Rec.Name_Len, Name);
      Rec.Class := Class;
      Entities.Append (Rec);
   end Record_Entity;

   --  The off class recorded for a name, or Off_None when the table holds
   --  no entry for it.
   --  @param Entities  Entity table.
   --  @param Name  Qualified Ada name.
   --  @return The recorded class.
   function Class_Of
     (Entities : Types.Implementation.Spark_Entity_Vectors.Vector;
      Name     : String) return Types.Spark_Off_Class is
   begin
      for I in 1 .. Integer (Entities.Length) loop
         if Entities (I).Name_Len = Name'Length
           and then Entities (I).Name (1 .. Name'Length) = Name
         then
            return Entities (I).Class;
         end if;
      end loop;
      return Types.Off_None;
   end Class_Of;

   --  Discard a boolean result. The gnatprove.out line parsers report
   --  whether a line held the record they read; a line that did not is
   --  simply passed over, so the caller does not act on the result.
   --  @param B  Result to discard.
   procedure Discard (B : Boolean) with Global => null is
      pragma Unreferenced (B);
   begin
      null;
   end Discard;

   procedure Join
     (Dir  : String;
      Name : String;
      Buf  : out Types.Path_Field;
      Len  : out Natural;
      Ok   : out Boolean) is
   begin
      Ok := Dir'Length + 1 + Name'Length <= Buf'Length;
      if not Ok then
         Len := 0;
         return;
      end if;
      Len := 0;
      for I in Dir'Range loop
         Len := Len + 1;
         Buf (Len) := Dir (I);
      end loop;
      Len := Len + 1;
      Buf (Len) := '/';
      for I in Name'Range loop
         Len := Len + 1;
         Buf (Len) := Name (I);
      end loop;
   end Join;

   function Parse_Unit_Line
     (L     : String;
      Units : in out Types.Implementation.Spark_Coverage_Vectors.Vector)
      return Boolean
   is
      Comma  : Natural;
      Out_At : Natural;
      M_End  : Natural;
      NLen   : Natural;
      Idx    : Natural;
      U      : Types.Implementation.Spark_Coverage_Unit;
   begin
      if L'Length < 9 or else L (L'First .. L'First + 7) /= "in unit " then
         return False;
      end if;
      Comma := Find (L, ",");
      Out_At := Find (L, Unit_Mark);
      if Comma = 0
        or else Out_At = 0
        or else Comma <= L'First + 8
        or else Out_At <= Comma
        or else L'Length < Unit_Mark'Length + Analyzed_Mark'Length
      then
         return False;
      end if;
      M_End := L'Last - Analyzed_Mark'Length;
      if L (M_End + 1 .. L'Last) /= Analyzed_Mark then
         return False;
      end if;
      NLen := Comma - (L'First + 8);
      if NLen = 0 or else NLen > Types.Max_Filename then
         return False;
      end if;
      Idx := Find_Unit (Units, L (L'First + 8 .. Comma - 1));
      U := Units (Idx);
      U.Subs_Proved := Parse_Natural (L (Comma + 2 .. Out_At - 1));
      U.Subs_Total := Parse_Natural (L (Out_At + Unit_Mark'Length .. M_End));
      U.In_Proof_Run := True;
      Units.Replace_Element (Idx, U);
      return True;
   end Parse_Unit_Line;

   --  Record one skipped entity from a gnatprove.out line, which reads
   --  "<entity> at <file>:<line> skipped; <reason>".
   --  @param L  One trimmed gnatprove.out line.
   --  @param Skips  Skip records (appended to).
   --  @return True when the line was a skip record.
   function Parse_Skip_Line
     (L     : String;
      Skips : in out Types.Implementation.Spark_Skip_Vectors.Vector)
      return Boolean
   is
      At_Pos : Natural;
      Rest   : Natural;
      Col    : Natural;
      Sk     : Natural;
      Rec    : Types.Implementation.Spark_Skip_Rec;
   begin
      if L'Length < 8 then
         return False;
      end if;
      At_Pos := Find (L, " at ");
      if At_Pos = 0 then
         return False;
      end if;
      Rest := At_Pos + 4;
      if Rest > L'Last or else Find (L (Rest .. L'Last), ":") = 0 then
         return False;
      end if;
      declare
         Tail_Str : constant String := L (Rest .. L'Last);
      begin
         Col := Find (Tail_Str, ":");
         Sk := Find (Tail_Str, " skipped;");
         if Sk = 0 or else Sk <= Col then
            return False;
         end if;
         if Col - 1 = 0 or else Col - 1 > Rec.File'Length then
            return False;
         end if;
         Put_Name (Rec.File, Rec.File_Len, Tail_Str (Rest .. Col - 1));
         Rec.Line := Parse_Natural (Tail_Str (Col + 1 .. Sk - 1));
      end;
      if At_Pos - L'First = 0 or else At_Pos - L'First > Rec.Name'Length then
         return False;
      end if;
      Put_Name (Rec.Name, Rec.Name_Len, L (L'First .. At_Pos - 1));
      Skips.Append (Rec);
      return True;
   end Parse_Skip_Line;

   procedure Sarif_Value
     (L : String; Key : String; Buf : out Types.Path_Field; Len : out Natural)
   is
      Q : constant Natural := Find (L, Key);
   begin
      Len := 0;
      if Q = 0 then
         return;
      end if;
      declare
         After : constant Natural := Q + Key'Length;
      begin
         if After + 3 > L'Last then
            return;
         end if;
         if L (After) /= ':'
           or else L (After + 1) /= ' '
           or else L (After + 2) /= '"'
         then
            return;
         end if;
         declare
            V : constant Natural := After + 3;
            E : Natural := V;
         begin
            while E <= L'Last loop
               pragma Loop_Invariant (E in V .. L'Last + 1);
               pragma Loop_Variant (Increases => E);
               exit when L (E) = '"';
               E := E + 1;
            end loop;
            if E > L'Last or else E <= V then
               return;
            end if;
            Len := Natural'Min (E - V, Buf'Length);
            for I in 1 .. Len loop
               Buf (I) := L (V + I - 1);
            end loop;
         end;
      end;
   end Sarif_Value;

   --  The qualified name gnatprove records in a SARIF result, taken from
   --  the logicalLocations entry every prover result carries. That name is
   --  what lets the statement scan recognise a proved subprogram by name
   --  instead of by line range.
   --  @param L  One SARIF line.
   --  @param Buf  Output buffer.
   --  @param Len  Length of the name in Buf.
   procedure Sarif_Entity
     (L : String; Buf : out Types.Name_Field; Len : out Natural)
   is
      N : constant Natural := Find (L, """name""");
   begin
      Len := 0;
      if N = 0 then
         return;
      end if;
      --  The field reads "name": "value".
      if N + 10 > L'Last or else L (N + 8) /= ' ' or else L (N + 9) /= '"' then
         return;
      end if;
      declare
         V : constant Natural := N + 10;
         E : Natural := V;
      begin
         while E <= L'Last loop
            pragma Loop_Invariant (E in V .. L'Last + 1);
            pragma Loop_Variant (Increases => E);
            exit when L (E) = '"';
            E := E + 1;
         end loop;
         if E > L'Last or else E <= V then
            return;
         end if;
         Len := Natural'Min (E - V, Buf'Length);
         for I in 1 .. Len loop
            Buf (I) := L (V + I - 1);
         end loop;
      end;
   end Sarif_Entity;

   procedure Read_Proof_Summary
     (Path  : String;
      Units : in out Types.Implementation.Spark_Coverage_Vectors.Vector;
      Skips : in out Types.Implementation.Spark_Skip_Vectors.Vector;
      Ok    : out Boolean)
   is
      use Ada.Text_IO;
      F        : File_Type;
      Line     : String (1 .. Max_Read);
      Last     : Natural;
      Overflow : Boolean;
      No       : Natural := 0;
   begin
      Ok := False;
      if not Ada.Directories.Exists (Path) then
         return;
      end if;
      Open (F, In_File, Path);
      while not End_Of_File (F) loop
         No := No + 1;
         Adacovex.Parsers.Read_Line (F, Path, No, Line, Last, Overflow);
         if Overflow then
            Close (F);
            return;
         end if;
         declare
            L : constant String := Trim (Line (1 .. Last));
         begin
            if Find (L, Unit_Mark) > 0 then
               Discard (Parse_Unit_Line (L, Units));
            elsif Find (L, " skipped;") > 0 then
               Discard (Parse_Skip_Line (L, Skips));
            end if;
         end;
      end loop;
      Close (F);
      Ok := True;
   end Read_Proof_Summary;

   --  Block size for reading the compact SARIF stream, plus a short carry
   --  so a key or a value that straddles a block boundary is seen whole.
   --  The prover writes the file as one long line, so it is read in blocks
   --  rather than by line.
   Sarif_Chunk : constant := 65536;
   Sarif_Carry : constant := 64;

   procedure Read_Sarif
     (Path     : String;
      Units    : in out Types.Implementation.Spark_Coverage_Vectors.Vector;
      Entities : in out Types.Implementation.Spark_Entity_Vectors.Vector;
      Ok       : out Boolean)
   is
      use Ada.Text_IO;
      Buf         : String (1 .. Sarif_Chunk + Sarif_Carry);
      Fill        : Natural := 0;
      From        : Natural := 1;
      Got         : Natural := 0;
      P           : Natural;
      Keep        : Natural;
      F           : File_Type;
      R_Kind      : Types.Path_Field;
      R_Kind_Len  : Natural := 0;
      R_Level     : Types.Path_Field;
      R_Level_Len : Natural := 0;
      R_Uri       : Types.Path_Field;
      R_Uri_Len   : Natural := 0;
      R_Name      : Types.Path_Field;
      R_Name_Len  : Natural := 0;
      R_Open      : Boolean := False;

      --  Whether the scan buffer holds the quoted JSON key K at Q.
      --  @param Q  Index to test.
      --  @param K  Key literal including its quotes.
      --  @return True when the key starts at Q.
      function At_Key (Q : Natural; K : String) return Boolean is
      begin
         if Q < Buf'First or else Q + K'Length - 1 > Fill then
            return False;
         end if;
         return Buf (Q .. Q + K'Length - 1) = K;
      end At_Key;

      --  The string value of the key whose closing quote is at Q. The layout
      --  is a colon, a space, an opening quote, the value, and a closing
      --  quote.
      --  @param Q  Index of the key's closing quote.
      --  @param Val  Output buffer.
      --  @param VLen  Length of the value in Val.
      --  @return False when the value is not a complete string in the buffer.
      function Value_At
        (Q : Natural; Val : out Types.Path_Field; VLen : out Natural)
         return Boolean
      is
         V : Natural := Q + 1;
         E : Natural;
      begin
         VLen := 0;
         --  The prover writes compact JSON, so the separator is a colon
         --  with no space after it; a pretty-printed file is accepted too.
         if V + 1 > Fill or else Buf (V) /= ':' then
            return False;
         end if;
         V := V + 1;
         while V <= Fill and then Buf (V) = ' ' loop
            pragma Loop_Invariant (V in Q + 1 .. Fill + 1);
            pragma Loop_Variant (Increases => V);
            V := V + 1;
         end loop;
         if V > Fill or else Buf (V) /= '"' then
            return False;
         end if;
         V := V + 1;
         E := V;
         while E <= Fill loop
            pragma Loop_Invariant (E in V .. Fill + 1);
            pragma Loop_Variant (Increases => E);
            exit when Buf (E) = '"';
            E := E + 1;
         end loop;
         if E > Fill or else E <= V then
            return False;
         end if;
         VLen := Natural'Min (E - V, Val'Length);
         for I in 1 .. VLen loop
            Val (I) := Buf (V + I - 1);
         end loop;
         return True;
      end Value_At;

      --  Record the accumulated result on its unit, record the entity the
      --  result names when the check passed, and reset the accumulator.
      procedure Flush is
         Idx     : Natural;
         U       : Types.Implementation.Spark_Coverage_Unit;
         Passed  : Boolean;
         Is_Warn : Boolean;
      begin
         if not R_Open or else R_Uri_Len = 0 then
            R_Kind_Len := 0;
            R_Level_Len := 0;
            R_Uri_Len := 0;
            R_Name_Len := 0;
            R_Open := False;
            return;
         end if;
         Passed := R_Kind_Len = 4 and then R_Kind (1 .. 4) = "pass";
         Is_Warn := R_Level_Len = 7 and then R_Level (1 .. 7) = "warning";
         Idx := Unit_For_File (Units, R_Uri (1 .. R_Uri_Len));
         U := Units (Idx);
         U.In_Proof_Run := True;
         if Is_Warn then
            --  A result whose level is "warning" is a proof warning, not a
            --  verification condition, so it never enters the VC metric.
            U.Warnings := U.Warnings + 1;
         else
            U.Checks_Total := U.Checks_Total + 1;
            if Passed then
               U.Checks_Proved := U.Checks_Proved + 1;
            end if;
         end if;
         Units.Replace_Element (Idx, U);
         if Passed and then R_Name_Len > 0 then
            Record_Entity (Entities, R_Name (1 .. R_Name_Len), Types.Off_None);
         end if;
         R_Kind_Len := 0;
         R_Level_Len := 0;
         R_Uri_Len := 0;
         R_Name_Len := 0;
         R_Open := False;
      end Flush;

      --  Scan the valid part of the buffer for the fields one result
      --  carries. A result opens at its "ruleId" key.
      procedure Scan is
      begin
         if From < Buf'First then
            From := Buf'First;
         end if;
         P := From;
         while P <= Fill loop
            if At_Key (P, """ruleId""") then
               Flush;
               R_Open := True;
               P := P + 8;
            elsif At_Key (P, """kind""") then
               declare
                  Tmp : Natural := 0;
               begin
                  if Value_At (P + 5, R_Kind, Tmp) then
                     R_Kind_Len := Natural'Min (Tmp, R_Kind'Length);
                  end if;
               end;
               P := P + 6;
            elsif At_Key (P, """level""") then
               declare
                  Tmp : Natural := 0;
               begin
                  if Value_At (P + 6, R_Level, Tmp) then
                     R_Level_Len := Natural'Min (Tmp, R_Level'Length);
                  end if;
               end;
               P := P + 7;
            elsif At_Key (P, """uri""") then
               declare
                  Tmp : Natural := 0;
               begin
                  if Value_At (P + 4, R_Uri, Tmp) then
                     R_Uri_Len := Natural'Min (Tmp, R_Uri'Length);
                  end if;
               end;
               P := P + 5;
            elsif At_Key (P, """name""") then
               declare
                  Tmp : Natural := 0;
               begin
                  if Value_At (P + 5, R_Name, Tmp) then
                     R_Name_Len := Natural'Min (Tmp, Types.Max_Filename);
                  end if;
               end;
               P := P + 6;
            else
               P := P + 1;
            end if;
         end loop;
      end Scan;

   begin
      Ok := False;
      if not Ada.Directories.Exists (Path) then
         return;
      end if;
      Open (F, In_File, Path);
      loop
         --  The stream may end without a final newline, so End_Of_File is
         --  not a sufficient guard: the read itself reports the end.
         Got := 0;
         declare
            More : Boolean := True;
         begin
            while Got < Sarif_Chunk and then More loop
               begin
                  Get (F, Buf (Fill + 1));
                  Got := Got + 1;
                  Fill := Fill + 1;
               exception
                  when End_Error =>
                     More := False;
               end;
            end loop;
         end;
         Scan;
         exit when Got = 0;
         --  Keep the tail of the block so a key split across the boundary is
         --  seen whole in the next block.
         Keep := Natural'Min (Fill, Sarif_Carry);
         for I in 0 .. Keep - 1 loop
            Buf (Keep - I) := Buf (Fill - I);
         end loop;
         Fill := Keep;
         From := 1;
      end loop;
      Close (F);
      Flush;
      Ok := True;
   end Read_Sarif;

   procedure File_Opts_Out
     (Path : String; Opted : out Boolean; Read_OK : out Boolean)
   is
      use Ada.Text_IO;
      F        : File_Type;
      Line     : String (1 .. Max_Read);
      Last     : Natural;
      Overflow : Boolean;
      No       : Natural := 0;
   begin
      Opted := False;
      Read_OK := False;
      if not Ada.Directories.Exists (Path) then
         return;
      end if;
      Open (F, In_File, Path);
      Read_OK := True;
      while not End_Of_File (F) loop
         No := No + 1;
         Adacovex.Parsers.Read_Line (F, Path, No, Line, Last, Overflow);
         exit when Overflow;
         if Line_Opts_Out (Line (1 .. Last)) then
            Opted := True;
            exit;
         end if;
      end loop;
      Close (F);
   end File_Opts_Out;

   --  Whether the unit that declares the source file File opts out of SPARK
   --  explicitly. The file itself is read first, then the spec of the same
   --  stem, which is where a separate body's parent unit is declared. The
   --  opt-out is a unit-level pragma, so it is declared once for the unit.
   --  @param Target_Dir  Project root.
   --  @param File  Source file base name.
   --  @return Whether the unit opts out.
   function Unit_Opts_Out (Target_Dir, File : String) return Boolean is
      Path    : Types.Path_Field;
      PLen    : Natural := 0;
      Ok      : Boolean;
      Opted   : Boolean := False;
      Read_OK : Boolean;
      Stem    : constant String := Stem_Of (File);
   begin
      Join (Target_Dir, File, Path, PLen, Ok);
      if Ok then
         File_Opts_Out (Path (1 .. PLen), Opted, Read_OK);
         if Read_OK then
            return Opted;
         end if;
      end if;
      Join (Target_Dir, Stem & ".ads", Path, PLen, Ok);
      if Ok then
         File_Opts_Out (Path (1 .. PLen), Opted, Read_OK);
         return Opted and Read_OK;
      end if;
      return False;
   end Unit_Opts_Out;

   --  Classify the entities the skip records declare in one source file.
   --  Consecutive skip lines in the file bound the source that belongs to
   --  each skipped entity, so one forward pass classifies every skip it
   --  holds. A unit that opts out of SPARK explicitly is irreducible; a
   --  skipped entity whose source performs input or output is I/O-bound;
   --  anything else is the work queue. Every skip is classified, so the
   --  three classes always sum to the skip count.
   --  @param Dir  Directory holding the source.
   --  @param Name  File base name.
   --  @param Skips  Skip records from gnatprove.out.
   --  @param Entities  Named-entity table (updated).
   procedure Classify_File_Skips
     (Dir      : String;
      Name     : String;
      Skips    : Types.Implementation.Spark_Skip_Vectors.Vector;
      Entities : in out Types.Implementation.Spark_Entity_Vectors.Vector)
   is
      use Ada.Text_IO;

      Path        : Types.Path_Field;
      PLen        : Natural := 0;
      Ok          : Boolean;
      Line        : String (1 .. Max_Read);
      Last        : Natural;
      Overflow    : Boolean;
      Line_No     : Natural;
      F           : File_Type;
      Ix          : Natural := 1;
      Stop_Ix     : Natural := 1;
      Cur_IO      : Boolean := False;
      Irreducible : constant Boolean := Unit_Opts_Out (Dir, Name);

      --  This file's own skip records, in the prover's order. gnatprove
      --  emits a unit's skips entity by entity, so a file's records are not
      --  contiguous in the global list; they are filtered here.
      Mine : Types.Implementation.Spark_Skip_Vectors.Vector;

      --  Record the off class of the skip at Ix. The caller advances Ix
      --  after the flush, so the current skip is always the one recorded.
      procedure Flush is
      begin
         if Ix > Integer (Mine.Length) then
            return;
         end if;
         declare
            Ent : constant Types.Implementation.Spark_Skip_Rec :=
              Mine (Positive (Ix));
         begin
            Record_Entity
              (Entities,
               Ent.Name (1 .. Ent.Name_Len),
               (if Irreducible
                then Types.Off_Irreducible
                elsif Cur_IO
                then Types.Off_IO_Bound
                else Types.Off_Work_Queue));
         end;
      end Flush;

   begin
      for I in 1 .. Integer (Skips.Length) loop
         if Skips (I).File_Len = Name'Length
           and then Skips (I).File (1 .. Name'Length) = Name
         then
            Mine.Append (Skips (I));
         end if;
      end loop;
      if Integer (Mine.Length) = 0 then
         return;
      end if;
      --  gnatprove emits a unit's skips entity by entity, so this file's
      --  records are not in line order. The forward pass below needs them
      --  ascending, so they are sorted here.
      for I in 2 .. Integer (Mine.Length) loop
         declare
            Key : constant Types.Implementation.Spark_Skip_Rec := Mine (I);
            J   : Natural := I - 1;
         begin
            while J >= 1 and then Mine (Positive (J)).Line > Key.Line loop
               Mine.Replace_Element (Positive (J + 1), Mine (Positive (J)));
               J := J - 1;
            end loop;
            Mine.Replace_Element (Positive (J + 1), Key);
         end;
      end loop;
      Stop_Ix := Integer (Mine.Length);
      PLen := 0;
      Ok := False;
      Join (Dir, Name, Path, PLen, Ok);
      if Ok and then Ada.Directories.Exists (Path (1 .. PLen)) then
         Open (F, In_File, Path (1 .. PLen));
         Line_No := 0;
         Ix := 1;
         Cur_IO := False;
         while not End_Of_File (F) loop
            Line_No := Line_No + 1;
            Adacovex.Parsers.Read_Line
              (F, Path (1 .. PLen), Line_No, Line, Last, Overflow);
            exit when Overflow;
            --  Reaching the next skip closes the current one.
            if Ix < Stop_Ix and then Line_No = Mine (Positive (Ix + 1)).Line
            then
               Flush;
               Ix := Ix + 1;
               Cur_IO := False;
            end if;
            if Line_No >= Mine (Positive (Ix)).Line
              and then Line_Is_IO_Bound (Line (1 .. Last))
            then
               Cur_IO := True;
            end if;
         end loop;
         Close (F);
         Flush;
      end if;
   end Classify_File_Skips;

   --  Walk the source tree and classify every skipped entity from its own
   --  source. This runs before the statement scan, so the named-entity
   --  table is complete when the statements are attributed.
   --  @param Dir  Directory to walk.
   --  @param Skips  Skip records from gnatprove.out.
   --  @param Entities  Named-entity table (updated).
   --  @param Skipped_Ct  Incremented when a declaring source is unreadable.
   procedure Walk_And_Classify
     (Dir        : String;
      Skips      : Types.Implementation.Spark_Skip_Vectors.Vector;
      Entities   : in out Types.Implementation.Spark_Entity_Vectors.Vector;
      Skipped_Ct : in out Natural)
   is
      use Ada.Directories;
      Search : Search_Type;
      Ent    : Directory_Entry_Type;
   begin
      if not Exists (Dir) then
         return;
      end if;
      Start_Search (Search, Dir, "*");
      while More_Entries (Search) loop
         Get_Next_Entry (Search, Ent);
         declare
            N : constant String := Simple_Name (Ent);
         begin
            if N = "." or else N = ".." then
               null;
            elsif Kind (Ent) = Directory then
               if not Skip_Dir (N) then
                  Walk_And_Classify
                    (Dir & "/" & N, Skips, Entities, Skipped_Ct);
               end if;
            elsif Kind (Ent) = Ordinary_File then
               if N'Length > 4
                 and then (N (N'Last - 3 .. N'Last) = ".adb"
                           or else N (N'Last - 3 .. N'Last) = ".ads")
               then
                  for I in 1 .. Integer (Skips.Length) loop
                     if Skips (I).File_Len = N'Length
                       and then Skips (I).File (1 .. N'Length) = N
                     then
                        Classify_File_Skips (Dir, N, Skips, Entities);
                        exit;
                     end if;
                  end loop;
               end if;
            end if;
         end;
      end loop;
      End_Search (Search);
   end Walk_And_Classify;

   --  The package-name stack the source scan maintains so every subprogram
   --  header can be turned into the qualified name gnatprove records. A
   --  separate body states its parent in `separate (...)`, so it needs no
   --  stack entry.
   type Pkg_Entry is record
      Name     : Types.Name_Field;
      Name_Len : Natural := 0;
   end record;

   type Pkg_Stack is array (1 .. Max_Pkg_Depth) of Pkg_Entry;

   --  The name an `end` closes, without its terminating semicolon, so a
   --  package or subprogram name can be compared against it directly.
   --  @param Code  The code part of a line whose first word is "end".
   --  @return The bare name.
   function End_Close_Name (Code : String) return String with Global => null is
      N : constant String := Second_Word (Code);
   begin
      if N'Length > 0 and then N (N'Last) = ';' then
         return N (N'First .. N'Last - 1);
      end if;
      return N;
   end End_Close_Name;

   --  Append "." and a name to a bounded qualified-name buffer.
   --  @param Buf  Buffer to append to.
   --  @param Len  Current length in Buf (updated).
   --  @param S  Name to append.
   procedure Append_Dotted
     (Buf : in out Types.Name_Field; Len : in out Natural; S : String) is
   begin
      if Len >= Buf'Length then
         return;
      end if;
      if Len > 0 then
         Len := Len + 1;
         Buf (Len) := '.';
      end if;
      for I in S'Range loop
         exit when Len >= Buf'Length;
         Len := Len + 1;
         Buf (Len) := S (I);
      end loop;
   end Append_Dotted;

   --  Statement scan of one Ada source file. Every statement is attributed
   --  to the subprogram that declares it: the scan tracks the enclosing
   --  package names and the `separate (...)` parent, builds the qualified
   --  name gnatprove uses, and looks that name up in the named-entity table.
   --  A statement in a unit gnatprove never analysed is not covered. A
   --  statement in an entity the table does not name is proved when its unit
   --  was analysed, because gnatprove did see that unit.
   --  @param Dir  Directory holding the source.
   --  @param Name  File base name (an ".adb" name).
   --  @param Entities  Named-entity table.
   --  @param Units  Unit records (updated and appended to).
   --  @param Skipped_Ct  Incremented when the file cannot be scanned.
   procedure Scan_Source
     (Dir        : String;
      Name       : String;
      Entities   : Types.Implementation.Spark_Entity_Vectors.Vector;
      Units      : in out Types.Implementation.Spark_Coverage_Vectors.Vector;
      Skipped_Ct : in out Natural)
   is
      use Ada.Text_IO;

      Path       : Types.Path_Field;
      PLen       : Natural := 0;
      Ok         : Boolean;
      Line       : String (1 .. Max_Read);
      Last       : Natural;
      Overflow   : Boolean;
      No         : Natural := 0;
      Stack      : Pkg_Stack := (others => (others => <>));
      Depth      : Natural := 0;
      Sep_Unit   : Types.Name_Field;
      Sep_Len    : Natural := 0;
      Cur        : Types.Name_Field;
      Cur_Len    : Natural := 0;
      In_Stmts   : Boolean := False;
      Declare_Ct : Natural := 0;
      Pending    : Boolean := False;
      Idx        : Natural;
      U          : Types.Implementation.Spark_Coverage_Unit;
      Stem       : constant String := Stem_Of (Name);
      Covered    : Boolean;
      Stmts      : Natural := 0;
      Proved     : Natural := 0;
      Not_Cov    : Natural := 0;
      Off_Irred  : Natural := 0;
      Off_IO     : Natural := 0;
      Off_WQ     : Natural := 0;
      Body_Subs  : Natural := 0;
      F          : File_Type;

      --  Push a package name onto the stack, qualifying a relative name
      --  with the enclosing package.
      --  @param N  Package name as declared.
      procedure Push_Pkg (N : String) is
      begin
         if Depth >= Max_Pkg_Depth or else N'Length = 0 then
            return;
         end if;
         Depth := Depth + 1;
         if Find (N, ".") > 0 or else Depth = 1 then
            Put_Name (Stack (Depth).Name, Stack (Depth).Name_Len, N);
         else
            Stack (Depth).Name := Stack (Depth - 1).Name;
            Stack (Depth).Name_Len := Stack (Depth - 1).Name_Len;
            Append_Dotted (Stack (Depth).Name, Stack (Depth).Name_Len, N);
         end if;
      end Push_Pkg;

      --  Whether an `end <name>` closes the package at the top of the stack.
      --  @param Close  The name after "end", without its semicolon.
      --  @return True when a package is closed.
      function Closes_Pkg (Close : String) return Boolean is
         Seg     : Types.Name_Field;
         Seg_Len : Natural;
      begin
         if Depth = 0 or else Close'Length = 0 then
            return False;
         end if;
         Put_Name
           (Seg, Seg_Len, Stack (Depth).Name (1 .. Stack (Depth).Name_Len));
         if Seg_Len = 0 then
            return False;
         end if;
         return Last_Segment (Seg (1 .. Seg_Len)) = Close;
      end Closes_Pkg;

   begin
      PLen := 0;
      Ok := False;
      Join (Dir, Name, Path, PLen, Ok);
      if not Ok then
         Skipped_Ct := Skipped_Ct + 1;
         return;
      end if;
      if not Ada.Directories.Exists (Path (1 .. PLen)) then
         return;
      end if;

      Idx := Unit_For_Stem (Units, Stem);
      U := Units (Idx);
      --  A unit gnatprove reported no entity for was never analysed, so
      --  nothing in it is proved.
      Covered := U.In_Proof_Run and then U.Subs_Total > 0;
      Put_Path (U.File, U.File_Len, Name);
      Put_Path (U.Folder, U.Folder_Len, Dir);
      Units.Replace_Element (Idx, U);

      Open (F, In_File, Path (1 .. PLen));
      while not End_Of_File (F) loop
         No := No + 1;
         Adacovex.Parsers.Read_Line
           (F, Path (1 .. PLen), No, Line, Last, Overflow);
         if Overflow then
            Close (F);
            Skipped_Ct := Skipped_Ct + 1;
            return;
         end if;
         declare
            R : constant Natural := Code_Length (Line (1 .. Last));
         begin
            if R > 0 then
               declare
                  Code    : constant String :=
                    Trim (Line (1 .. Last) (1 .. R));
                  W       : constant String := First_Word (Code);
                  K       : constant Line_Kind := Classify (Code);
                  W2      : constant String := Second_Word (Code);
                  Counted : Boolean := False;
               begin
                  --  A separate body states its parent unit explicitly.
                  if W = "separate" and then Find (Code, "(") > 0 then
                     declare
                        A : constant Natural := Find (Code, "(");
                        P : Natural := A;
                        B : Natural := A;
                     begin
                        while P <= Code'Last loop
                           pragma Loop_Invariant (P in A .. Code'Last + 1);
                           pragma Loop_Variant (Increases => P);
                           exit when Code (P) = ')';
                           P := P + 1;
                        end loop;
                        B := P;
                        if B > A + 1 and then B <= Code'Last then
                           Sep_Len := Natural'Min (B - A - 1, Sep_Unit'Length);
                           for J in 1 .. Sep_Len loop
                              Sep_Unit (J) := Code (A + J);
                           end loop;
                        end if;
                     end;
                  end if;
                  --  Package nesting, so a later header can be qualified.
                  if W = "package" and then Find (Code, " is") > 0 then
                     Push_Pkg
                       ((if W2 = "body" then Third_Word (Code) else W2));
                  end if;
                  --  A subprogram header names the entity that owns the
                  --  statements which follow it.
                  if W = "procedure"
                    or else W = "function"
                    or else (W = "overriding"
                             and then (W2 = "procedure"
                                       or else W2 = "function"))
                  then
                     declare
                        N : constant String :=
                          (if W = "overriding" then Third_Word (Code) else W2);
                     begin
                        Body_Subs := Body_Subs + 1;
                        Cur_Len := 0;
                        if N'Length > 0 then
                           if Find (N, ".") > 0 then
                              Put_Name (Cur, Cur_Len, N);
                           elsif Sep_Len > 0 then
                              Put_Name (Cur, Cur_Len, Sep_Unit (1 .. Sep_Len));
                              Append_Dotted (Cur, Cur_Len, N);
                           elsif Depth > 0 then
                              Put_Name
                                (Cur,
                                 Cur_Len,
                                 Stack (Depth).Name
                                   (1 .. Stack (Depth).Name_Len));
                              Append_Dotted (Cur, Cur_Len, N);
                           else
                              Put_Name (Cur, Cur_Len, N);
                           end if;
                        end if;
                     end;
                  end if;
                  case K is
                     when Kind_End              =>
                        Pending := False;
                        if not Ends_Inner_Construct (Code) then
                           if Closes_Pkg (End_Close_Name (Code)) then
                              Depth := Depth - 1;
                           end if;
                           if Declare_Ct > 0 then
                              Declare_Ct := Declare_Ct - 1;
                              In_Stmts := True;
                           else
                              In_Stmts := False;
                           end if;
                        end if;

                     when Kind_Head             =>
                        if W = "begin" then
                           In_Stmts := True;
                           Stmts := Stmts + 1;
                           Counted := True;
                           Pending := False;
                        elsif W = "declare" and then In_Stmts then
                           Declare_Ct := Declare_Ct + 1;
                           In_Stmts := False;
                           Stmts := Stmts + 1;
                           Counted := True;
                           Pending := False;
                        else
                           if In_Stmts then
                              Stmts := Stmts + 1;
                              Counted := True;
                           end if;
                           Pending := not Self_Contained (Code);
                        end if;

                     when Kind_Simple           =>
                        if In_Stmts and then not Pending then
                           Stmts := Stmts + 1;
                           Counted := True;
                        end if;
                        Pending := False;

                     when Kind_Start            =>
                        Pending := True;

                     when Kind_None | Kind_Decl =>
                        null;
                  end case;
                  if Counted then
                     if not Covered then
                        Not_Cov := Not_Cov + 1;
                     else
                        case Class_Of (Entities, Cur (1 .. Cur_Len)) is
                           when Types.Off_Irreducible =>
                              Off_Irred := Off_Irred + 1;

                           when Types.Off_IO_Bound    =>
                              Off_IO := Off_IO + 1;

                           when Types.Off_Work_Queue  =>
                              Off_WQ := Off_WQ + 1;

                           when Types.Off_None        =>
                              Proved := Proved + 1;
                        end case;
                     end if;
                  end if;
               end;
            end if;
         end;
      end loop;
      Close (F);

      --  A unit may have several bodies (a parent plus its separate
      --  bodies), so the unit totals accumulate rather than replace.
      U := Units (Idx);
      U.Stmts_Total := U.Stmts_Total + Stmts;
      U.Stmts_Proved := U.Stmts_Proved + Proved;
      U.Stmts_Not_Covered := U.Stmts_Not_Covered + Not_Cov;
      U.Off_Irreducible := U.Off_Irreducible + Off_Irred;
      U.Off_IO_Bound := U.Off_IO_Bound + Off_IO;
      U.Off_Work_Queue := U.Off_Work_Queue + Off_WQ;
      if not U.In_Proof_Run then
         --  A unit the prover never reported on: the subprograms its body
         --  declares are its not-covered count.
         U.Not_Covered_Subs := U.Not_Covered_Subs + Body_Subs;
      end if;
      Units.Replace_Element (Idx, U);
   end Scan_Source;

   procedure Walk_Source
     (Dir        : String;
      Entities   : Types.Implementation.Spark_Entity_Vectors.Vector;
      Units      : in out Types.Implementation.Spark_Coverage_Vectors.Vector;
      Skipped_Ct : in out Natural)
   is
      use Ada.Directories;
      Search : Search_Type;
      Ent    : Directory_Entry_Type;
   begin
      if not Exists (Dir) then
         return;
      end if;
      Start_Search (Search, Dir, "*");
      while More_Entries (Search) loop
         Get_Next_Entry (Search, Ent);
         declare
            N : constant String := Simple_Name (Ent);
         begin
            if N = "." or else N = ".." then
               null;
            elsif Kind (Ent) = Directory then
               if not Skip_Dir (N) then
                  Walk_Source (Dir & "/" & N, Entities, Units, Skipped_Ct);
               end if;
            elsif Kind (Ent) = Ordinary_File then
               if N'Length > 4 and then N (N'Last - 3 .. N'Last) = ".adb" then
                  Scan_Source (Dir, N, Entities, Units, Skipped_Ct);
               end if;
            end if;
         end;
      end loop;
      End_Search (Search);
   end Walk_Source;

   --  Add one unit's counts to a group rollup. Every count is a sum, so a
   --  group percentage is always a ratio of sums and never a mean of its
   --  children.
   --  @param G  Group rollup (updated).
   --  @param U  Unit record.
   procedure Accum_Group
     (G : in out Types.Implementation.Spark_Coverage_Group;
      U : Types.Implementation.Spark_Coverage_Unit) is
   begin
      G.Stmts_Total := G.Stmts_Total + U.Stmts_Total;
      G.Stmts_Proved := G.Stmts_Proved + U.Stmts_Proved;
      G.Stmts_Not_Covered := G.Stmts_Not_Covered + U.Stmts_Not_Covered;
      G.Subs_Total := G.Subs_Total + U.Subs_Total;
      G.Subs_Proved := G.Subs_Proved + U.Subs_Proved;
      G.Checks_Total := G.Checks_Total + U.Checks_Total;
      G.Checks_Proved := G.Checks_Proved + U.Checks_Proved;
      G.Warnings := G.Warnings + U.Warnings;
      G.Off_Irreducible := G.Off_Irreducible + U.Off_Irreducible;
      G.Off_IO_Bound := G.Off_IO_Bound + U.Off_IO_Bound;
      G.Off_Work_Queue := G.Off_Work_Queue + U.Off_Work_Queue;
      G.Not_Covered_Subs := G.Not_Covered_Subs + U.Not_Covered_Subs;
      G.Unit_Ct := G.Unit_Ct + 1;
   end Accum_Group;

   --  Add one unit's counts to the whole-tree rollup.
   --  @param T  Whole-tree rollup (updated).
   --  @param U  Unit record.
   procedure Accum_Totals
     (T : in out Types.Implementation.Spark_Coverage_Totals;
      U : Types.Implementation.Spark_Coverage_Unit)
   is
      G : Types.Implementation.Spark_Coverage_Group :=
        Types.Implementation.Spark_Coverage_Group'(others => <>);
   begin
      Accum_Group (G, U);
      T.Stmts_Total := T.Stmts_Total + G.Stmts_Total;
      T.Stmts_Proved := T.Stmts_Proved + G.Stmts_Proved;
      T.Stmts_Not_Covered := T.Stmts_Not_Covered + G.Stmts_Not_Covered;
      T.Subs_Total := T.Subs_Total + G.Subs_Total;
      T.Subs_Proved := T.Subs_Proved + G.Subs_Proved;
      T.Checks_Total := T.Checks_Total + G.Checks_Total;
      T.Checks_Proved := T.Checks_Proved + G.Checks_Proved;
      T.Warnings := T.Warnings + G.Warnings;
      T.Off_Irreducible := T.Off_Irreducible + G.Off_Irreducible;
      T.Off_IO_Bound := T.Off_IO_Bound + G.Off_IO_Bound;
      T.Off_Work_Queue := T.Off_Work_Queue + G.Off_Work_Queue;
      T.Not_Covered_Subs := T.Not_Covered_Subs + G.Not_Covered_Subs;
      T.Unit_Ct := T.Unit_Ct + G.Unit_Ct;
   end Accum_Totals;

   --  Roll the per-unit records up into the group rows and the whole-tree
   --  totals. Every group count is a sum over its member units.
   --  @param Group  Row grouping selector.
   --  @param Units  Per-unit records.
   --  @param Groups  Group rollups (appended to).
   --  @param Totals  Whole-tree rollup.
   procedure Build_Groups
     (Group  : Types.Spark_Group_Kind;
      Units  : Types.Implementation.Spark_Coverage_Vectors.Vector;
      Groups : in out Types.Implementation.Spark_Group_Vectors.Vector;
      Totals : out Types.Implementation.Spark_Coverage_Totals)
   is
      KBuf : Types.Path_Field;
      KLen : Natural := 0;
   begin
      Totals := Types.Implementation.Spark_Coverage_Totals'(others => <>);
      for I in 1 .. Integer (Units.Length) loop
         declare
            U  : constant Types.Implementation.Spark_Coverage_Unit :=
              Units (I);
            Gx : Natural := 0;
         begin
            Group_Key_Of (U, Group, KBuf, KLen);
            if KLen > 0 then
               for J in 1 .. Integer (Groups.Length) loop
                  if Gx = 0
                    and then Groups (J).Key_Len = KLen
                    and then Groups (J).Key (1 .. KLen) = KBuf (1 .. KLen)
                  then
                     Gx := J;
                  end if;
               end loop;
            end if;
            if Gx = 0 then
               declare
                  G : Types.Implementation.Spark_Coverage_Group :=
                    Types.Implementation.Spark_Coverage_Group'(others => <>);
               begin
                  for J in 1 .. KLen loop
                     G.Key (J) := KBuf (J);
                  end loop;
                  G.Key_Len := KLen;
                  Groups.Append (G);
                  Gx := Integer (Groups.Length);
               end;
            end if;
            declare
               G : Types.Implementation.Spark_Coverage_Group := Groups (Gx);
            begin
               Accum_Group (G, U);
               Groups.Replace_Element (Positive (Gx), G);
            end;
            Accum_Totals (Totals, U);
         end;
      end loop;
   end Build_Groups;

   procedure Analyze
     (Target_Dir : String;
      Proof_Dir  : String;
      Group      : Types.Spark_Group_Kind;
      Units      : in out Types.Implementation.Spark_Coverage_Vectors.Vector;
      Groups     : in out Types.Implementation.Spark_Group_Vectors.Vector;
      Totals     : out Types.Implementation.Spark_Coverage_Totals;
      Skipped_Ct : out Natural;
      Proof_Ok   : out Boolean)
   is
      PDir     : constant String :=
        (if Proof_Dir'Length = 0
         then Target_Dir & "/obj/gnatprove"
         else Proof_Dir);
      Skips    : Types.Implementation.Spark_Skip_Vectors.Vector;
      Entities : Types.Implementation.Spark_Entity_Vectors.Vector;
      Ok_Out   : Boolean;
      Ok_Sarif : Boolean;
   begin
      Units.Clear;
      Groups.Clear;
      Skipped_Ct := 0;
      Read_Proof_Summary (PDir & "/gnatprove.out", Units, Skips, Ok_Out);
      Read_Sarif (PDir & "/gnatprove.sarif", Units, Entities, Ok_Sarif);
      Walk_And_Classify (Target_Dir, Skips, Entities, Skipped_Ct);
      Walk_Source (Target_Dir, Entities, Units, Skipped_Ct);
      Build_Groups (Group, Units, Groups, Totals);
      Proof_Ok := Ok_Out and Ok_Sarif;
   end Analyze;

   --  Write a count without Natural'Image's leading space, which the
   --  prover handles imprecisely.
   --  @param N  Value to write.
   procedure Put_Nat (N : Natural) is
      B : String (1 .. 32);
      L : Natural := 0;
   begin
      Append_Nat (B, L, N);
      Ada.Text_IO.Put (B (1 .. L));
   end Put_Nat;

   --  Write a percentage with one decimal and a percent sign.
   --  @param Proved  Numerator.
   --  @param Total  Denominator.
   procedure Put_Pct (Proved, Total : Natural) is
      B : String (1 .. 32);
      L : Natural := 0;
   begin
      Append_Pct (B, L, Proved, Total);
      B (L + 1) := '%';
      Ada.Text_IO.Put (B (1 .. L + 1));
   end Put_Pct;

   --  Write a field left-aligned in a fixed column.
   --  @param F  Field to write.
   --  @param Len  Length of the field.
   --  @param Col  Column width.
   procedure Put_Field (F : String; Len, Col : Natural) is
      N : constant Natural := Natural'Min (Len, Col);
   begin
      Ada.Text_IO.Put (F (F'First .. F'First + N - 1));
      for I in N + 1 .. Col loop
         Ada.Text_IO.Put (' ');
      end loop;
   end Put_Field;

   procedure Print_Report
     (Totals  : Types.Implementation.Spark_Coverage_Totals;
      Groups  : Types.Implementation.Spark_Group_Vectors.Vector;
      Group   : Types.Spark_Group_Kind;
      Min_Pct : Natural := 0)
   is
      use Ada.Text_IO;

      --  Write one metric's overall block: the proved count over both
      --  denominators, each named.
      --  @param M  Metric to report.
      procedure Metric_Block (M : Types.Spark_Metric_Kind) is
         P, Total, Off : Natural;
      begin
         Metric_Values (Totals, M, P, Total);
         case M is
            when Types.Metric_Statements  =>
               Off := Total - P - Totals.Stmts_Not_Covered;

            when Types.Metric_Subprograms =>
               Off := Total - P;

            when Types.Metric_Checks      =>
               Off := 0;
         end case;
         Put (Metric_Proved_Name (M));
         Put (" / ");
         Put (Metric_Denominator_Name (M));
         New_Line;
         Put ("  proved / (proved + off)  ");
         Put_Nat (P);
         Put (" / ");
         Put_Nat (P + Off);
         Put (" = ");
         Put_Pct (P, P + Off);
         New_Line;
         Put ("  proved / total           ");
         Put_Nat (P);
         Put (" / ");
         Put_Nat (Total);
         Put (" = ");
         Put_Pct (P, Total);
         New_Line;
      end Metric_Block;

      --  Write one labelled count.
      --  @param Label  Row label.
      --  @param N  Count.
      procedure Count_Block (Label : String; N : Natural) is
      begin
         Put (Label);
         for I in Label'Length + 1 .. 24 loop
            Put (' ');
         end loop;
         Put_Nat (N);
         New_Line;
      end Count_Block;

   begin
      Put_Line ("SPARK proof coverage");
      New_Line;

      Put_Line ("Statement coverage");
      Metric_Block (Types.Metric_Statements);
      Put ("  statements not covered    ");
      Put_Nat (Totals.Stmts_Not_Covered);
      New_Line;
      New_Line;

      Put_Line ("Subprogram coverage");
      Metric_Block (Types.Metric_Subprograms);
      New_Line;

      Put_Line ("VC coverage");
      Metric_Block (Types.Metric_Checks);
      Put ("  proof warnings (not VCs)  ");
      Put_Nat (Totals.Warnings);
      New_Line;
      New_Line;

      Put_Line ("Off classes (statements in subprograms gnatprove skipped)");
      Count_Block ("irreducible", Totals.Off_Irreducible);
      Count_Block ("io-bound", Totals.Off_IO_Bound);
      Count_Block ("work queue", Totals.Off_Work_Queue);
      New_Line;

      Put ("Statement coverage by ");
      Put (Types.To_String (Group));
      Put_Line (" (proved / (proved + off))");
      Put_Line
        ("  key                              proved  off     rel%     abs%");
      for I in 1 .. Integer (Groups.Length) loop
         declare
            G   : constant Types.Implementation.Spark_Coverage_Group :=
              Groups (I);
            P   : constant Natural := G.Stmts_Proved;
            Off : constant Natural := G.Stmts_Total - P - G.Stmts_Not_Covered;
         begin
            if Min_Pct = 0 or else P * 100 >= Min_Pct * (P + Off) then
               if G.Key_Len > 0 then
                  Put_Field (G.Key (1 .. G.Key_Len), G.Key_Len, 34);
               else
                  Put_Field ("(unnamed)", 9, 34);
               end if;
               Put_Nat (P);
               Put ("    ");
               Put_Nat (Off);
               Put ("     ");
               Put_Pct (P, P + Off);
               Put ("   ");
               Put_Pct (P, G.Stmts_Total);
               New_Line;
            end if;
         end;
      end loop;
   end Print_Report;

   --  Write one JSON string, escaping a quote and a backslash.
   --  @param S  Text to write.
   procedure Put_Json_String (S : String) is
      use Ada.Text_IO;
   begin
      Put ('"');
      for I in S'Range loop
         if S (I) = '"' or else S (I) = '\' then
            Put ('\');
         end if;
         Put (S (I));
      end loop;
      Put ('"');
   end Put_Json_String;

   --  Write one JSON field: the key, a colon, and a quoted count.
   --  @param First  True when this is the first field in the object.
   --  @param Key  Field name.
   --  @param N  Field value.
   procedure Put_Json_Nat (First : Boolean; Key : String; N : Natural) is
      use Ada.Text_IO;
   begin
      if not First then
         Put (",");
      end if;
      Put_Json_String (Key);
      Put (": ");
      Put_Nat (N);
   end Put_Json_Nat;

   procedure Print_JSON
     (Totals : Types.Implementation.Spark_Coverage_Totals;
      Units  : Types.Implementation.Spark_Coverage_Vectors.Vector;
      Groups : Types.Implementation.Spark_Group_Vectors.Vector;
      Group  : Types.Spark_Group_Kind)
   is
      use Ada.Text_IO;
      Off : constant Natural :=
        Totals.Stmts_Total - Totals.Stmts_Proved - Totals.Stmts_Not_Covered;
   begin
      Put_Line ("{");
      Put ("  ");
      Put_Json_String ("group");
      Put (": ");
      Put_Json_String (Types.To_String (Group));
      Put_Line (",");
      Put_Line ("  ""metrics"": {");
      Put ("    ""statements"": {""proved"": ");
      Put_Nat (Totals.Stmts_Proved);
      Put (", ""off"": ");
      Put_Nat (Off);
      Put (", ""not_covered"": ");
      Put_Nat (Totals.Stmts_Not_Covered);
      Put (", ""total"": ");
      Put_Nat (Totals.Stmts_Total);
      Put_Line ("},");
      Put ("    ""subprograms"": {""proved"": ");
      Put_Nat (Totals.Subs_Proved);
      Put (", ""total"": ");
      Put_Nat (Totals.Subs_Total);
      Put_Line ("},");
      Put ("    ""checks"": {""proved"": ");
      Put_Nat (Totals.Checks_Proved);
      Put (", ""total"": ");
      Put_Nat (Totals.Checks_Total);
      Put_Line ("}");
      Put_Line ("  },");
      Put_Line ("  ""off_classes"": {""irreducible"": ");
      Put_Nat (Totals.Off_Irreducible);
      Put (", ""io_bound"": ");
      Put_Nat (Totals.Off_IO_Bound);
      Put (", ""work_queue"": ");
      Put_Nat (Totals.Off_Work_Queue);
      Put_Line ("},");
      Put ("  ""proof_warnings"": ");
      Put_Nat (Totals.Warnings);
      Put_Line (",");
      Put ("  ""unit_count"": ");
      Put_Nat (Totals.Unit_Ct);
      Put_Line (",");
      Put_Line ("  ""units"": [");
      for I in 1 .. Integer (Units.Length) loop
         declare
            U : constant Types.Implementation.Spark_Coverage_Unit := Units (I);
         begin
            if I > 1 then
               Put_Line (",");
            end if;
            Put ("    {");
            Put_Json_Nat (True, "stmts_proved", U.Stmts_Proved);
            Put (", ");
            Put_Json_Nat (False, "stmts_not_covered", U.Stmts_Not_Covered);
            Put (", ");
            Put_Json_Nat (False, "stmts_total", U.Stmts_Total);
            Put (", ");
            Put_Json_Nat (False, "subs_proved", U.Subs_Proved);
            Put (", ");
            Put_Json_Nat (False, "subs_total", U.Subs_Total);
            Put (", ");
            Put_Json_Nat (False, "checks_proved", U.Checks_Proved);
            Put (", ");
            Put_Json_Nat (False, "checks_total", U.Checks_Total);
            Put (", ");
            Put_Json_Nat (False, "warnings", U.Warnings);
            Put (", ");
            Put_Json_Nat (False, "off_irreducible", U.Off_Irreducible);
            Put (", ");
            Put_Json_Nat (False, "off_io_bound", U.Off_IO_Bound);
            Put (", ");
            Put_Json_Nat (False, "off_work_queue", U.Off_Work_Queue);
            Put (", ");
            Put_Json_Nat (False, "not_covered_subs", U.Not_Covered_Subs);
            Put ("    }");
         end;
      end loop;
      Put_Line ("");
      Put_Line ("  ],");
      Put_Line ("  ""groups"": [");
      for I in 1 .. Integer (Groups.Length) loop
         declare
            G : constant Types.Implementation.Spark_Coverage_Group :=
              Groups (I);
         begin
            if I > 1 then
               Put_Line (",");
            end if;
            Put ("    {");
            Put_Json_Nat (True, "stmts_proved", G.Stmts_Proved);
            Put (", ");
            Put_Json_Nat
              (False,
               "stmts_off",
               G.Stmts_Total - G.Stmts_Proved - G.Stmts_Not_Covered);
            Put (", ");
            Put_Json_Nat (False, "stmts_not_covered", G.Stmts_Not_Covered);
            Put (", ");
            Put_Json_Nat (False, "stmts_total", G.Stmts_Total);
            Put (", ");
            Put_Json_Nat (False, "subs_proved", G.Subs_Proved);
            Put (", ");
            Put_Json_Nat (False, "subs_total", G.Subs_Total);
            Put (", ");
            Put_Json_Nat (False, "checks_proved", G.Checks_Proved);
            Put (", ");
            Put_Json_Nat (False, "checks_total", G.Checks_Total);
            Put (", ");
            Put_Json_Nat (False, "unit_count", G.Unit_Ct);
            Put ("    }");
         end;
      end loop;
      Put_Line ("");
      Put_Line ("  ]");
      Put_Line ("}");
   end Print_JSON;

end Adacovex.Spark_Coverage;
