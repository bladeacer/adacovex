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

   --  True when T is one of the bounded IR scalar type names (the signed
   --  types above plus the unsigned modular types).  A parameter type must
   --  be one of these names for the pair to lower onto a bounded scalar.
   function Is_IR_Type (T : String) return Boolean is
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

   --  Lean slice of the gnatprove-friendly IR: synthesises a
   --  contract-carrying bounded-function spec for ONE "P:Type" parameter
   --  pair.  The pair lowers onto a bounded IR scalar type and, when the
   --  type is signed, the emitted text carries the half-range Pre guard
   --  that gnatprove discharges for the checked arithmetic (the same guard
   --  as Adacovex.Target_Profiles.Checked_Add32 / the Adacovex.IR_Bounds
   --  fixture).  The slice is deliberately straight-line: a single pair
   --  needs no comma-splitting passes, so the proof cost stays near the
   --  type-lowering helpers instead of the multi-pair form (whose VC ledger
   --  is documented in docs/contributing/ir.md).  Comma-separated lists,
   --  malformed pairs, and unknown types yield "".
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

      --  Cursor positions in Param_List.  Colon is the first ':' and Comma
      --  the first ','; each is Param_List'Last + 1 when absent.  A
      --  well-formed single pair needs a ':' with a non-empty name before
      --  it (Colon in First + 1 .. Last - 1 bounds the slices below), no
      --  ',' inside the name (Comma >= Colon; a ',' after the ':' would sit
      --  inside the type slice, which Is_IR_Type then rejects), and a type
      --  that is one of the bounded IR type names.
      Colon : Natural;
      Comma : Natural;
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

      Colon := Find_Char (Param_List, Param_List'First, ':');
      Comma := Find_Char (Param_List, Param_List'First, ',');
      if Colon in Param_List'First + 1 .. Param_List'Last - 1
        and then Comma >= Colon
        and then Is_IR_Type (Param_List (Colon + 1 .. Param_List'Last))
      then
         declare
            --  Slice the pair once into named constants: each slice's range
            --  is then proved at one declaration site instead of at every
            --  Append call, and the emission below only ever appends whole
            --  strings or single-character literals.
            P_Name : constant String :=
              Param_List (Param_List'First .. Colon - 1);
            P_Type : constant String :=
              Param_List (Colon + 1 .. Param_List'Last);
         begin
            if Return_Type'Length > 0 then
               Append ("function ");
            else
               Append ("procedure ");
            end if;
            Append (Name);
            Append (" (");
            Append (P_Name);
            Append (" : ");
            Append (P_Type);
            Append (")");
            if Return_Type'Length > 0 then
               Append (" return ");
               Append (Return_Type);
            end if;
            Append (String'(1 => ASCII.LF));
            if Is_Signed_IR (P_Type) then
               --  Half-range Pre guard, the same shape gnatprove discharges
               --  for Checked_Add32 / IR_Bounds.Add32.  Unsigned (modular)
               --  parameters need no guard.
               Append ("with");
               Append (String'(1 => ASCII.LF));
               Append ("  Pre => ");
               Append (P_Name);
               Append (" in ");
               Append (P_Type);
               Append ("'First / 2 .. ");
               Append (P_Type);
               Append ("'Last / 2");
               Append (String'(1 => ASCII.LF));
            end if;
            Append (String'(1 => ';'));
            Append (String'(1 => ASCII.LF));
            return Result (1 .. RLen);
         end;
      end if;

      return "";
   end Synthesize_Bounded_Function;

end Adacovex.IR_Synthesiser;

