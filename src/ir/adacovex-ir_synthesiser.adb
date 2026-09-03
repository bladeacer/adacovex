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
   --  The Global contract makes gnatprove analyse the equality chain once
   --  as a unit instead of contextually re-proving it at every call site
   --  (the re-analysis is what prints the "analyzing call ... in context"
   --  info notes and repeats the string-equality VCs per caller).
   function Is_Signed_IR (T : String) return Boolean with Global => null is
   begin
      return
        T = "IR_Int8"
        or else T = "IR_Int16"
        or else T = "IR_Int32"
        or else T = "IR_Int64";
   end Is_Signed_IR;

   --  True when T is one of the bounded IR scalar type names (the signed
   --  types above plus the unsigned modular types).  A parameter type must
   --  be one of these names for the pair to lower onto a bounded scalar.
   --  Global contract as for Is_Signed_IR.
   function Is_IR_Type (T : String) return Boolean with Global => null is
   begin
      return
        Is_Signed_IR (T)
        or else T = "IR_UInt8"
        or else T = "IR_UInt16"
        or else T = "IR_UInt32"
        or else T = "IR_UInt64";
   end Is_IR_Type;

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

   --  True when S holds a space or tab anywhere.  Parameter pairs are
   --  accepted only in the canonical space-free form, so a pair carrying
   --  whitespace never lowers (it would silently emit a signature whose
   --  spelling gnatprove cannot parse).
   function Has_Space (S : String) return Boolean
   with Global => null, Pre => S'First >= 1 and S'Last < Natural'Last
   is
   begin
      for I in S'Range loop
         pragma Loop_Invariant (I <= S'Last + 1);
         pragma Loop_Variant (Increases => I);
         if S (I) = ' ' or else S (I) = ASCII.HT then
            return True;
         end if;
      end loop;
      return False;
   end Has_Space;

   --  One lowered parameter pair: the parameter name and the bounded IR
   --  type name it lowers onto, both in fixed-size buffers with lengths
   --  (0 = empty).  Signed records whether the type is a signed IR scalar
   --  (unsigned modular types need no overflow guard).  A pair whose type
   --  is not a bounded IR name carries Valid => False and the whole
   --  synthesis degrades to the nullary spec (or ""), never a malformed
   --  spec text.
   Max_Pair_Name : constant := 64;
   type Lowered_Pair is record
      Valid  : Boolean := False;
      Signed : Boolean := False;
      P_Name : String (1 .. Max_Pair_Name) := (others => ' ');
      --  The length fields carry the bound in their subtype: an emission
      --  site slicing P_Name (1 .. N_Len) needs no further proof that the
      --  slice is in range (the assignment guards are local to the
      --  lowering pass).
      N_Len  : Natural range 0 .. Max_Pair_Name := 0;
      P_Type : String (1 .. 9) := (others => ' ');
      T_Len  : Natural range 0 .. 9 := 0;
   end record;

   --  Upper bound on pairs held in one synthesised parameter list.  The
   --  list must fit the Max_Pkg_Len output buffer with one line per pair
   --  (each line is well under 96 characters), so 32 pairs is a generous
   --  ceiling; a longer list degrades to "" (never a truncated spec).
   Max_Pairs : constant := 32;
   type Pair_List is array (1 .. Max_Pairs) of Lowered_Pair;

   --  Pass one of the multi-pair form: scan Param_List once, splitting on
   --  commas, and lower every well-formed "P:Type" pair onto its bounded
   --  IR scalar.  Pairs holds the lowered result; Count is the number of
   --  pairs seen; All_Valid reports whether every seen pair lowered (a
   --  single malformed or foreign-typed pair makes the whole list
   --  invalid).  Spaces inside a pair are rejected: the canonical input
   --  form is space-free ("A:IR_Int32,B:IR_UInt8"), and tolerating spaces
   --  would silently emit a signature gnatprove cannot parse.
   procedure Lower_Pairs
     (Param_List : String;
      Pairs      : out Pair_List;
      Count      : out Natural;
      All_Valid  : out Boolean)
   with
     Global => null,
     Pre    => Param_List'First >= 1 and then Param_List'Last < Natural'Last
   is
      I : Natural := Param_List'First;
   begin
      Pairs := (others => <>);
      Count := 0;
      All_Valid := True;
      while I <= Param_List'Last loop
         pragma Loop_Invariant (I in Param_List'First .. Param_List'Last + 1);
         pragma Loop_Invariant (Count <= Max_Pairs);
         pragma Loop_Variant (Increases => I);
         --  A list longer than Max_Pairs is invalid as a whole: it must
         --  degrade to "" at the caller, never truncate (a truncated
         --  parameter list would drop named pairs from a signature while
         --  keeping the contract that references them).
         if Count = Max_Pairs then
            All_Valid := False;
            exit;
         end if;

         declare
            --  The pair ends at the next ',' (or the end of the list).
            --  An empty pair (",," or a trailing ',') is malformed: it is
            --  recorded invalid and scan continues after the comma.  The
            --  Colon probe runs only when the pair is non-empty, because
            --  Find_Char's precondition requires Start in S'First ..
            --  S'Last and a null slice cannot satisfy it.
            Comma    : constant Natural := Find_Char (Param_List, I, ',');
            Last     : constant Natural := Comma - 1;
            Nonempty : constant Boolean := I <= Last;
            Colon    : constant Natural :=
              (if Nonempty
               then Find_Char (Param_List (I .. Last), I, ':')
               else I);
         begin
            if Count < Max_Pairs then
               Count := Count + 1;
               --  A well-formed pair needs a ':' with a non-empty name
               --  before it and a non-empty type after it, no spaces, and
               --  a type that is a bounded IR type name.
               if Nonempty
                 and then Colon in I + 1 .. Last - 1
                 and then Param_List (I .. Colon - 1)'Length <= Max_Pair_Name
                 and then Param_List (Colon + 1 .. Last)'Length <= 9
               then
                  declare
                     Sub_Name : constant String := Param_List (I .. Colon - 1);
                     Sub_Type : constant String :=
                       Param_List (Colon + 1 .. Last);
                  begin
                     if Has_Space (Sub_Name)
                       or else Has_Space (Sub_Type)
                       or else not Is_IR_Type (Sub_Type)
                     then
                        Pairs (Count) := (Valid => False, others => <>);
                        All_Valid := False;
                     else
                        Pairs (Count).Valid := True;
                        Pairs (Count).Signed := Is_Signed_IR (Sub_Type);
                        Pairs (Count).N_Len := Sub_Name'Length;
                        Pairs (Count).P_Name (1 .. Sub_Name'Length) :=
                          Sub_Name;
                        Pairs (Count).T_Len := Sub_Type'Length;
                        Pairs (Count).P_Type (1 .. Sub_Type'Length) :=
                          Sub_Type;
                     end if;
                  end;
               else
                  Pairs (Count) := (Valid => False, others => <>);
                  All_Valid := False;
               end if;
            end if;

            if Comma > Param_List'Last then
               I := Param_List'Last + 1;
            else
               I := Comma + 1;
            end if;
         end;
      end loop;
   end Lower_Pairs;

   --  Multi-pair form of the gnatprove-friendly IR: synthesises a
   --  contract-carrying bounded-function spec from a comma-separated
   --  "P:Type" parameter list.  Each pair lowers onto a bounded IR scalar
   --  type; the signed ones contribute a half-range Pre guard, joined
   --  with "and then" into one contract chain (the same guard shape
   --  gnatprove discharges for Adacovex.Target_Profiles.Checked_Add32 /
   --  the Adacovex.IR_Bounds fixture).  The three passes follow the
   --  recorded design: pass one lowers every pair exactly once (no
   --  re-proving of slices per emission site), pass two emits the
   --  signature, pass three emits the guard chain.  An empty list emits
   --  the nullary spec.  Malformed pairs, foreign type names, embedded
   --  spaces, and lists longer than Max_Pairs degrade to "" (never a
   --  malformed spec).
   function Synthesize_Bounded_Function
     (Name : String; Param_List : String; Return_Type : String) return String
   is
      Result : String (1 .. Max_Pkg_Len) := (others => ' ');
      RLen   : Natural range 0 .. Max_Pkg_Len := 0;

      --  Appends a string to the synthesised text buffer.  The buffer is
      --  bounded.  Appended text is truncated (it never overflows) at the
      --  fixed-size limit.  Same contract as Synthesize_Package.Append: the
      --  precondition makes gnatprove analyse this procedure as a unit
      --  instead of re-proving (and inlining) the body at every call site.
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

      Pairs     : Pair_List;
      Pair_Ct   : Natural;
      All_Valid : Boolean;
   begin
      if Name'Length = 0 then
         return "";
      end if;

      if Param_List'Length = 0 then
         --  Nullary spec (no parameter list, no Pre contract).
         if Return_Type'Length > 0 then
            Append ("function ");
         else
            Append ("procedure ");
         end if;
         Append (Name);
         if Return_Type'Length > 0 then
            Append (" return ");
            Append (Return_Type);
         end if;
         Append (String'(1 => ASCII.LF));
         Append (String'(1 => ';'));
         Append (String'(1 => ASCII.LF));
         return Result (1 .. RLen);
      end if;

      --  Pass one: lower every pair once.
      Lower_Pairs (Param_List, Pairs, Pair_Ct, All_Valid);
      if not All_Valid or else Pair_Ct = 0 or else Pair_Ct > Max_Pairs then
         return "";
      end if;

      --  Pass two: the signature.  Pairs are "name : type", joined with
      --  "; ".  Whole strings or single-character literals only: no
      --  chained '&' assembly of slices (the recorded 16.1.0 lesson).
      if Return_Type'Length > 0 then
         Append ("function ");
      else
         Append ("procedure ");
      end if;
      Append (Name);
      Append (" (");
      for P in 1 .. Pair_Ct loop
         pragma Loop_Invariant (RLen <= Result'Last);
         pragma Loop_Variant (Increases => P);
         if P > 1 then
            Append ("; ");
         end if;
         Append (Pairs (P).P_Name (1 .. Pairs (P).N_Len));
         Append (" : ");
         Append (Pairs (P).P_Type (1 .. Pairs (P).T_Len));
      end loop;
      Append (")");
      if Return_Type'Length > 0 then
         Append (" return ");
         Append (Return_Type);
      end if;
      Append (String'(1 => ASCII.LF));

      --  Pass three: the guard chain, one half-range guard per signed
      --  parameter, joined with "and then".  Unsigned (modular)
      --  parameters need no guard; a list with no signed parameter emits
      --  no contract at all.
      declare
         Signed_Ct : Natural range 0 .. Max_Pairs := 0;
      begin
         for P in 1 .. Pair_Ct loop
            pragma Loop_Invariant (Signed_Ct <= P - 1);
            pragma Loop_Variant (Increases => P);
            if Pairs (P).Signed then
               Signed_Ct := Signed_Ct + 1;
            end if;
         end loop;
         if Signed_Ct > 0 then
            Append ("with");
            Append (String'(1 => ASCII.LF));
            Append ("  Pre => ");
            declare
               Seen : Natural range 0 .. Max_Pairs := 0;
            begin
               for P in 1 .. Pair_Ct loop
                  --  Seen counts the signed pairs among iterations 1 ..
                  --  P - 1, so it never exceeds P - 1 (and Pair_Ct <=
                  --  Max_Pairs is checked before pass two runs).
                  pragma Loop_Invariant (Seen <= P - 1);
                  pragma Loop_Variant (Increases => P);
                  if Pairs (P).Signed then
                     Seen := Seen + 1;
                     if Seen > 1 then
                        Append (" and then");
                        Append (String'(1 => ASCII.LF));
                        Append ("        ");
                     end if;
                     Append (Pairs (P).P_Name (1 .. Pairs (P).N_Len));
                     Append (" in ");
                     Append (Pairs (P).P_Type (1 .. Pairs (P).T_Len));
                     Append ("'First / 2 .. ");
                     Append (Pairs (P).P_Type (1 .. Pairs (P).T_Len));
                     Append ("'Last / 2");
                  end if;
               end loop;
            end;
            Append (String'(1 => ASCII.LF));
         end if;
      end;

      Append (String'(1 => ';'));
      Append (String'(1 => ASCII.LF));
      return Result (1 .. RLen);
   end Synthesize_Bounded_Function;

end Adacovex.IR_Synthesiser;
