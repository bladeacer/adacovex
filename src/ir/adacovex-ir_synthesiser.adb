package body Adacovex.IR_Synthesiser is
   pragma SPARK_Mode (On);

   --  Returns the decimal digit string for a word size.
   --  @param W  The word size.
   --  @return "8", "16", "32", or "64".
   function Bits (W : Word_Size) return String
   with Global => null, Post => Bits'Result'Length in 1 .. 2
   is
   begin
      case W is
         when Bits_8  =>
            return "8";

         when Bits_16 =>
            return "16";

         when Bits_32 =>
            return "32";

         when Bits_64 =>
            return "64";
      end case;
   end Bits;

   function IR_Type_Name (Name : String; Cfg : Target_Config) return String is
   begin
      if Name = "int8_t" then
         return "IR_Int8";
      elsif Name = "int16_t" then
         return "IR_Int16";
      elsif Name = "int32_t" then
         return "IR_Int32";
      elsif Name = "int64_t" then
         return "IR_Int64";
      elsif Name = "uint8_t" then
         return "IR_UInt8";
      elsif Name = "uint16_t" then
         return "IR_UInt16";
      elsif Name = "uint32_t" then
         return "IR_UInt32";
      elsif Name = "uint64_t" then
         return "IR_UInt64";
      elsif Name = "size_t" or else Name = "usize" then
         pragma
           Assert (String'("IR_UInt" & Bits (Cfg.Target_Bits))'Length <= 9);
         return "IR_UInt" & Bits (Cfg.Target_Bits);
      elsif Name = "isize" then
         pragma
           Assert (String'("IR_Int" & Bits (Cfg.Target_Bits))'Length <= 9);
         return "IR_Int" & Bits (Cfg.Target_Bits);
      elsif Name = "ptrdiff_t" then
         pragma
           Assert (String'("IR_Int" & Bits (Cfg.Pointer_Bits))'Length <= 9);
         return "IR_Int" & Bits (Cfg.Pointer_Bits);
      elsif Name = "uintptr_t" then
         pragma
           Assert (String'("IR_UInt" & Bits (Cfg.Pointer_Bits))'Length <= 9);
         return "IR_UInt" & Bits (Cfg.Pointer_Bits);
      else
         return "";
      end if;
   end IR_Type_Name;

   function Lower_Type_Name (Name : String; Cfg : Target_Config) return String
   is
      IR : constant String := IR_Type_Name (Name, Cfg);
   begin
      if IR'Length = 0 then
         return "";
      end if;
      return "type " & Name & " is new Adacovex.Target_Profiles." & IR & ";";
   end Lower_Type_Name;

   function Synthesize_Package
     (Pkg_Name : String; Type_Names : String; Cfg : Target_Config)
      return String
   is
      Result : String (1 .. Max_Pkg_Len) := (others => ' ');
      RLen   : Natural range 0 .. Max_Pkg_Len := 0;

      --  Appends a string to the synthesised text buffer.  The buffer is
      --  bounded.  Appended text is truncated (it never overflows) at the
      --  fixed-size limit.  The precondition gives the procedure a contract.
      --  gnatprove then analyses it as a unit instead of re-proving the body
      --  at every call site.
      --  @param S  Text to append.
      procedure Append (S : String)
      with Pre => S'First >= 1 and S'Last < Natural'Last
      is
      begin
         for I in S'Range loop
            pragma Loop_Invariant (RLen <= Result'Last);
            if RLen < Result'Last then
               RLen := RLen + 1;
               Result (RLen) := S (I);
            end if;
         end loop;
      end Append;
   begin
      Append ("--  Synthesized by Adacovex.IR_Synthesiser." & ASCII.LF);
      Append ("with Adacovex.Target_Profiles;" & ASCII.LF);
      Append (String'(1 => ASCII.LF));
      Append ("package " & Pkg_Name & " is" & ASCII.LF);

      declare
         I : Natural := Type_Names'First;
      begin
         while I <= Type_Names'Last loop
            pragma
              Loop_Invariant (I in Type_Names'First .. Type_Names'Last + 1);
            pragma Loop_Invariant (RLen <= Result'Last);
            pragma Loop_Variant (Increases => I);
            declare
               J    : Natural := I;
               Sub  : String (1 .. Type_Names'Length) := (others => ' ');
               SLen : Natural := 0;
            begin
               while J <= Type_Names'Last and then Type_Names (J) /= ',' loop
                  if Type_Names (J) /= ' ' then
                     SLen := SLen + 1;
                     Sub (SLen) := Type_Names (J);
                  end if;
                  J := J + 1;
                  pragma Loop_Invariant (SLen <= J - Type_Names'First);
                  pragma
                    Loop_Invariant
                      (J in Type_Names'First .. Type_Names'Last + 1);
                  pragma Loop_Invariant (J >= I);
                  pragma Loop_Variant (Increases => J);
               end loop;
               if SLen > 0 then
                  declare
                     Decl : constant String :=
                       Lower_Type_Name (Sub (1 .. SLen), Cfg);
                  begin
                     if Decl'Length > 0 then
                        Append ("   " & Decl & ASCII.LF);
                     end if;
                  end;
               end if;
               if J > Type_Names'Last then
                  I := Type_Names'Last + 1;
               else
                  I := J + 1;
               end if;
            end;
         end loop;
      end;

      Append ("end " & Pkg_Name & ";" & ASCII.LF);
      return Result (1 .. RLen);
   end Synthesize_Package;

   --  True when T is one of the signed bounded IR types (unsigned modular
   --  types need no overflow guard; wrapping arithmetic cannot raise).
   function Is_Signed_IR (T : String) return Boolean is
   begin
      return
        T = "IR_Int8"
        or else T = "IR_Int16"
        or else T = "IR_Int32"
        or else T = "IR_Int64";
   end Is_Signed_IR;

   --  Index of the first C at or after Start in S, or S'Last + 1 when C
   --  does not occur.  Single-condition scan loop, the same canonical shape
   --  gnatprove discharges in Skip_Blanks / Subprogram_Name: the Pre bounds
   --  every "+1" on the cursor, the Post gives callers the bounds they need
   --  for slices and "past the token" arithmetic.
   function Find_Char
     (S : String; Start : Natural; C : Character) return Natural
   with
     Pre  =>
       S'First >= 1 and S'Last < Natural'Last and Start in S'First .. S'Last,
     Post => Find_Char'Result in Start .. S'Last + 1
   is
      I : Natural := Start;
   begin
      while I <= S'Last and then S (I) /= C loop
         pragma Loop_Invariant (I in Start .. S'Last + 1);
         pragma Loop_Variant (Increases => I);
         I := I + 1;
      end loop;
      return I;
   end Find_Char;

   function Synthesize_Bounded_Function
     (Name : String; Param_List : String; Return_Type : String) return String
   is
      Result : String (1 .. Max_Pkg_Len) := (others => ' ');
      RLen   : Natural range 0 .. Max_Pkg_Len := 0;

      --  Appends a string to the synthesised text buffer.  The buffer is
      --  bounded.  Appended text is truncated (it never overflows) at the
      --  fixed-size limit.  Same contract as Synthesize_Package.Append: the
      --  precondition makes gnatprove analyse this procedure as a unit
      --  instead of re-proving (and inlining) the body at every call site --
      --  the inlined copy is what leaves those 41 loop-invariant and range
      --  checks unproved under the pair-scan context.
      procedure Append (S : String)
      with Pre => S'First >= 1 and S'Last < Natural'Last
      is
      begin
         for I in S'Range loop
            pragma Loop_Invariant (RLen <= Result'Last);
            if RLen < Result'Last then
               RLen := RLen + 1;
               Result (RLen) := S (I);
            end if;
         end loop;
      end Append;

      --  Whether the space-free token that starts at From and ends just
      --  before End_At is a well-formed "P:Type" pair: a ':' at Colon_At
      --  with at least one character on each side.  When well formed,
      --  Name_Last and Type_Last bound the name and type text so the caller
      --  can slice and emit without re-scanning.  A token that runs to the
      --  end of the list has End_At = S'Last + 1.
      procedure Pair_Text
        (S         : String;
         From      : Natural;
         Colon_At  : Natural;
         End_At    : Natural;
         Name_Last : out Natural;
         Type_Last : out Natural;
         Ok        : out Boolean)
      with
        Pre  =>
          S'First >= 1
          and then S'Last <= Natural'Last - 2
          and then From in S'First .. S'Last
          and then Colon_At in S'First .. S'Last + 1
          and then End_At in S'First .. S'Last + 1,
        Post =>
          (if Ok
           then
             Name_Last in From .. S'Last
             and then Type_Last in Colon_At + 1 .. S'Last)
      is
      begin
         Ok := False;
         Name_Last := From;
         Type_Last := Colon_At;
         --  Colon_At <= S'Last is checked before any "+ 2" arithmetic so
         --  the cursor math provably stays in range (a ':' may be missing
         --  only at S'Last + 1).
         if Colon_At <= S'Last
           and then Colon_At >= From + 1
           and then End_At >= Colon_At + 2
         then
            Name_Last := Colon_At - 1;
            Type_Last := End_At - 1;
            Ok := True;
         end if;
      end Pair_Text;
   begin
      if Name'Length = 0 then
         return "";
      end if;

      if Param_List'Length > 0 then
         declare
            P       : Natural;
            Colon   : Natural;
            Comma   : Natural;
            Nxt     : Natural;
            P_Ok    : Boolean;
            N_Last  : Natural;
            T_Last  : Natural;
            --  Pair and signed-parameter counts.  Each pair needs at least
            --  three characters, so the counts stay far below Max_Pkg_Len;
            --  the explicit caps below keep the increments provably in
            --  range whatever the input.
            Count   : Natural range 0 .. Max_Pkg_Len - 1 := 0;
            Signed  : Natural range 0 .. Max_Pkg_Len - 1 := 0;
            First_C : Boolean;
         begin
            --  First pass: count well-formed pairs and signed types.
            P := Param_List'First;
            while P <= Param_List'Last loop
               pragma
                 Loop_Invariant (P in Param_List'First .. Param_List'Last + 1);
               pragma Loop_Variant (Increases => P);
               Comma := Find_Char (Param_List, P, ',');
               Colon := Find_Char (Param_List, P, ':');
               if Comma > Param_List'Last then
                  Nxt := Param_List'Last + 1;
               else
                  Nxt := Comma + 1;
               end if;
               Pair_Text (Param_List, P, Colon, Comma, N_Last, T_Last, P_Ok);
               if P_Ok then
                  --  A well-formed pair carries a non-empty name: the ':'
                  --  sits at least one character after the start (Pair_Text
                  --  Post bounds Name_Last from below).  Reads N_Last so the
                  --  count pass leaves no out-parameter unread (gnatprove
                  --  warns on set-but-never-read flow here otherwise).
                  pragma Assert (N_Last >= P);
                  if Count < Max_Pkg_Len - 1 then
                     Count := Count + 1;
                  end if;
                  if Signed < Max_Pkg_Len - 1
                    and then Is_Signed_IR (Param_List (Colon + 1 .. T_Last))
                  then
                     Signed := Signed + 1;
                  end if;
               end if;
               P := Nxt;
            end loop;

            --  Signature ("procedure" when no return type).  Every Append
            --  argument is a literal, a parameter string, or a slice -- no
            --  chained concatenations, so the solver sees one range check
            --  at a time.
            if Count = 0 then
               if Return_Type'Length > 0 then
                  Append ("function ");
                  Append (Name);
               else
                  Append ("procedure ");
                  Append (Name);
               end if;
            else
               First_C := True;
               if Return_Type'Length > 0 then
                  Append ("function ");
                  Append (Name);
                  Append (" (");
               else
                  Append ("procedure ");
                  Append (Name);
                  Append (" (");
               end if;
               P := Param_List'First;
               while P <= Param_List'Last loop
                  pragma
                    Loop_Invariant
                      (P in Param_List'First .. Param_List'Last + 1);
                  pragma Loop_Variant (Increases => P);
                  Comma := Find_Char (Param_List, P, ',');
                  Colon := Find_Char (Param_List, P, ':');
                  if Comma > Param_List'Last then
                     Nxt := Param_List'Last + 1;
                  else
                     Nxt := Comma + 1;
                  end if;
                  Pair_Text
                    (Param_List, P, Colon, Comma, N_Last, T_Last, P_Ok);
                  if P_Ok then
                     if First_C then
                        First_C := False;
                     else
                        Append ("; ");
                     end if;
                     --  One slice per Append call: a single bounded slice per
                     --  argument keeps the range checks small (chained "&"
                     --  arguments blow up the solver, as recorded in the
                     --  16.1.0 ledger for string assembly).
                     Append (Param_List (P .. N_Last));
                     Append (" : ");
                     Append (Param_List (Colon + 1 .. T_Last));
                  end if;
                  P := Nxt;
               end loop;
               Append (")");
            end if;
            if Return_Type'Length > 0 then
               Append (" return ");
               Append (Return_Type);
            end if;
            Append (String'(1 => ASCII.LF));

            --  Pre contract: one half-range guard per signed parameter, the
            --  same shapes gnatprove discharges for Checked_Add32 /
            --  IR_Bounds.Add32.  Unsigned (modular) parameters need no
            --  guard.
            if Signed > 0 then
               Append ("with" & ASCII.LF);
               Append ("  Pre => ");
               First_C := True;
               P := Param_List'First;
               while P <= Param_List'Last loop
                  pragma
                    Loop_Invariant
                      (P in Param_List'First .. Param_List'Last + 1);
                  pragma Loop_Variant (Increases => P);
                  Comma := Find_Char (Param_List, P, ',');
                  Colon := Find_Char (Param_List, P, ':');
                  if Comma > Param_List'Last then
                     Nxt := Param_List'Last + 1;
                  else
                     Nxt := Comma + 1;
                  end if;
                  Pair_Text
                    (Param_List, P, Colon, Comma, N_Last, T_Last, P_Ok);
                  if P_Ok
                    and then Is_Signed_IR (Param_List (Colon + 1 .. T_Last))
                  then
                     if First_C then
                        First_C := False;
                     else
                        Append (String'(1 => ASCII.LF));
                        Append ("         and then ");
                     end if;
                     Append (Param_List (P .. N_Last));
                     Append (" in ");
                     Append (Param_List (Colon + 1 .. T_Last));
                     Append ("'First / 2 .. ");
                     Append (Param_List (Colon + 1 .. T_Last));
                     Append ("'Last / 2");
                  end if;
                  P := Nxt;
               end loop;
               Append (String'(1 => ASCII.LF));
            end if;
            Append (String'(1 => ';'));
            Append (String'(1 => ASCII.LF));
         end;
      else
         --  Empty parameter list: nullary spec, no contract.
         if Return_Type'Length > 0 then
            Append ("function ");
            Append (Name);
            Append (" return ");
            Append (Return_Type);
         else
            Append ("procedure ");
            Append (Name);
         end if;
         Append (String'(1 => ASCII.LF));
         Append (String'(1 => ';'));
         Append (String'(1 => ASCII.LF));
      end if;
      return Result (1 .. RLen);
   end Synthesize_Bounded_Function;

end Adacovex.IR_Synthesiser;
