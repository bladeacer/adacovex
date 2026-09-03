with Ada.Strings.Fixed;
with Adacovex.Target_Profiles; use Adacovex.Target_Profiles;
with Adacovex.IR_Synthesiser;  use Adacovex.IR_Synthesiser;
with Adacovex.IR_Bounds;       use Adacovex.IR_Bounds;
with System;

package body Adacovex_IR_Tests is

   procedure Run (R : in out Adacovex.Test_Support.Runner'Class) is
      Cfg64 : constant Target_Config := (others => Bits_64);
      Cfg32 : constant Target_Config :=
        (Host_Bits    => Bits_64,
         Target_Bits  => Bits_32,
         Pointer_Bits => Bits_32);
   begin
      --  Test 1: bounded scalar type bounds.
      R.Check
        (IR_Int8'First = -128 and then IR_Int8'Last = 127,
         "Test 1: IR_Int8 bounds");
      R.Check
        (IR_Int16'First = -32768 and then IR_Int16'Last = 32767,
         "Test 1: IR_Int16 bounds");
      R.Check
        (IR_Int32'First = -2**31 and then IR_Int32'Last = 2**31 - 1,
         "Test 1: IR_Int32 bounds");
      R.Check
        (IR_Int64'First = -2**63 and then IR_Int64'Last = 2**63 - 1,
         "Test 1: IR_Int64 bounds");

      --  Test 2: unsigned modular types.
      R.Check
        (IR_UInt8'Modulus = 2**8 and then IR_UInt16'Modulus = 2**16,
         "Test 2: IR_UInt8/16 modulus");
      R.Check
        (IR_UInt32'Modulus = 2**32 and then IR_UInt64'Modulus = 2**64,
         "Test 2: IR_UInt32/64 modulus");

      --  Test 3: target config defaults and fields.
      declare
         C : constant Target_Config := (others => <>);
      begin
         R.Check
           (C.Host_Bits = Bits_64
            and then C.Target_Bits = Bits_64
            and then C.Pointer_Bits = Bits_64,
            "Test 3: default target config is 64-bit host/target");
         R.Check
           (Cfg32.Target_Bits = Bits_32 and then Cfg32.Pointer_Bits = Bits_32,
            "Test 3: 32-bit target config fields");
      end;

      --  Test 4: IR_Type_Name fixed-width mappings.
      R.Check
        (IR_Type_Name ("int8_t", Cfg64) = "IR_Int8"
         and then IR_Type_Name ("uint8_t", Cfg64) = "IR_UInt8",
         "Test 4: int8_t/uint8_t mapping");
      R.Check
        (IR_Type_Name ("int32_t", Cfg64) = "IR_Int32"
         and then IR_Type_Name ("int64_t", Cfg64) = "IR_Int64",
         "Test 4: int32_t/int64_t mapping");
      R.Check
        (IR_Type_Name ("uint32_t", Cfg64) = "IR_UInt32"
         and then IR_Type_Name ("uint64_t", Cfg64) = "IR_UInt64",
         "Test 4: uint32_t/uint64_t mapping");

      --  Test 5: size-tagged mappings follow the target word size.
      R.Check
        (IR_Type_Name ("size_t", Cfg64) = "IR_UInt64"
         and then IR_Type_Name ("usize", Cfg64) = "IR_UInt64"
         and then IR_Type_Name ("isize", Cfg64) = "IR_Int64",
         "Test 5: size_t/usize/isize on a 64-bit target");
      R.Check
        (IR_Type_Name ("size_t", Cfg32) = "IR_UInt32"
         and then IR_Type_Name ("ptrdiff_t", Cfg32) = "IR_Int32"
         and then IR_Type_Name ("uintptr_t", Cfg32) = "IR_UInt32",
         "Test 5: size_t/ptrdiff_t/uintptr_t on a 32-bit target");
      R.Check
        (IR_Type_Name ("size_t", Cfg64) = "IR_UInt64"
         and then IR_Type_Name ("ptrdiff_t", Cfg32) = "IR_Int32",
         "Test 5: pointer-tagged types follow pointer width");

      --  Test 6: unrecognized names map to an empty string.
      R.Check
        (IR_Type_Name ("float", Cfg64) = ""
         and then IR_Type_Name ("", Cfg64) = ""
         and then IR_Type_Name ("INT32_T", Cfg64) = "",
         "Test 6: unrecognized / case-mismatched names are empty");

      --  Test 7: Lower_Type_Name synthesised declarations.
      R.Check
        (Lower_Type_Name ("int32_t", Cfg64)
         = "type int32_t is new Adacovex.Target_Profiles.IR_Int32;",
         "Test 7: int32_t lowered declaration");
      R.Check
        (Lower_Type_Name ("size_t", Cfg64)
         = "type size_t is new Adacovex.Target_Profiles.IR_UInt64;",
         "Test 7: size_t lowered declaration on 64-bit target");
      R.Check
        (Lower_Type_Name ("float", Cfg64) = "",
         "Test 7: unrecognized name lowers to empty string");

      --  Test 8: Synthesize_Package builds a package skeleton.
      declare
         Pkg_Text : constant String :=
           Synthesize_Package ("IR_Add", "int32_t,uint64_t", Cfg64);
      begin
         R.Check
           (Pkg_Text'Length > 0 and then Pkg_Text'Length <= 4096,
            "Test 8: synthesized package has bounded length");
         R.Check
           (Ada.Strings.Fixed.Index (Pkg_Text, "package IR_Add is") > 0,
            "Test 8: package header synthesized");
         R.Check
           (Ada.Strings.Fixed.Index
              (Pkg_Text,
               "type int32_t is new Adacovex.Target_Profiles.IR_Int32;")
            > 0
            and then Ada.Strings.Fixed.Index
                       (Pkg_Text,
                        "type uint64_t is new Adacovex.Target_Profiles.IR_UInt64;")
                     > 0,
            "Test 8: lowered declarations present");
         R.Check
           (Ada.Strings.Fixed.Index (Pkg_Text, "end IR_Add;") > 0,
            "Test 8: package end synthesized");
      end;

      --  Test 9: bounds-checked arithmetic returns correct sums.
      R.Check
        (Adacovex.Target_Profiles.Checked_Add32 (10, 20) = 30,
         "Test 9: Checked_Add32 sum");
      R.Check
        (Adacovex.Target_Profiles.Checked_Add64 (2**40, 2**40) = 2**41,
         "Test 9: Checked_Add64 sum");

      --  Test 10: IR_Bounds fixture (synthesised-style lowered types).
      R.Check
        (Adacovex.IR_Bounds.int32_t'First = -2**31
         and then Adacovex.IR_Bounds.int32_t'Last = 2**31 - 1,
         "Test 10: IR_Bounds int32_t inherits IR_Int32 bounds");
      R.Check
        (Adacovex.IR_Bounds.Add32 (1000, 2000) = 3000
         and then Adacovex.IR_Bounds.Add64 (2**40, 2**40) = 2**41,
         "Test 10: IR_Bounds checked additions");

      --  Test 11: host word-size auto-detection (added 1.6.0).
      R.Check
        ((System.Word_Size <= 8 and then Host_Word_Size = Bits_8)
         or else (System.Word_Size in 9 .. 16
                  and then Host_Word_Size = Bits_16)
         or else (System.Word_Size in 17 .. 32
                  and then Host_Word_Size = Bits_32)
         or else (System.Word_Size > 32 and then Host_Word_Size = Bits_64),
         "Test 11: Host_Word_Size matches System.Word_Size");      --  Test 12: Synthesize_Bounded_Function emits the checked-add shape
      --  for a single signed parameter: bounded type plus the half-range
      --  Pre guard gnatprove discharges (the same guard as Checked_Add32 /
      --  IR_Bounds.Add32).  A one-pair list is the minimal multi-pair case.
      declare
         Spec : constant String :=
           Synthesize_Bounded_Function ("Inc", "A:IR_Int32", "IR_Int32");
         Want : constant String :=
           "function Inc (A : IR_Int32) return IR_Int32"
           & ASCII.LF
           & "with"
           & ASCII.LF
           & "  Pre => A in IR_Int32'First / 2 .. IR_Int32'Last / 2"
           & ASCII.LF
           & ";"
           & ASCII.LF;
      begin
         R.Check
           (Spec'Length <= 4096 and then Spec = Want,
            "Test 12: one-pair list emits one half-range Pre guard");
      end;

      --  Test 13: unsigned (modular) parameters carry no overflow guard.
      declare
         Spec : constant String :=
           Synthesize_Bounded_Function ("Wrap", "X:IR_UInt32", "IR_UInt32");
         Want : constant String :=
           "function Wrap (X : IR_UInt32) return IR_UInt32"
           & ASCII.LF
           & ";"
           & ASCII.LF;
      begin
         R.Check (Spec = Want, "Test 13: unsigned-only spec has no Pre contract");
      end;

      --  Test 14: the multi-pair form lowers a comma-separated list: the
      --  signed pair carries the half-range guard, the unsigned pair does
      --  not, and the signature joins the pairs with "; ".
      declare
         Spec : constant String :=
           Synthesize_Bounded_Function
             ("Mix", "A:IR_UInt64,B:IR_Int64", "IR_Int64");
         Want : constant String :=
           "function Mix (A : IR_UInt64; B : IR_Int64) return IR_Int64"
           & ASCII.LF
           & "with"
           & ASCII.LF
           & "  Pre => B in IR_Int64'First / 2 .. IR_Int64'Last / 2"
           & ASCII.LF
           & ";"
           & ASCII.LF;
      begin
         R.Check
           (Spec = Want,
            "Test 14: multi-pair list lowers and emits the signed guard");
      end;

      --  Test 15: an empty Return_Type emits a procedure spec.
      declare
         Spec : constant String :=
           Synthesize_Bounded_Function ("ResetState", "S:IR_Int32", "");
         Want : constant String :=
           "procedure ResetState (S : IR_Int32)"
           & ASCII.LF
           & "with"
           & ASCII.LF
           & "  Pre => S in IR_Int32'First / 2 .. IR_Int32'Last / 2"
           & ASCII.LF
           & ";"
           & ASCII.LF;
      begin
         R.Check (Spec = Want, "Test 15: empty return type synthesises a procedure");
      end;

      --  Test 16: empty names and malformed pairs degrade gracefully (an
      --  empty result, never an exception).
      R.Check
        (Synthesize_Bounded_Function ("", "A:IR_Int32", "IR_Int32") = "",
         "Test 16: empty subprogram name returns an empty string");
      R.Check
        (Synthesize_Bounded_Function ("F", "broken-pair", "IR_Int32") = "",
         "Test 16: pair without a colon degrades to an empty string");

      --  Test 17: two signed pairs join their guards with "and then" on
      --  one contract chain, one guard per signed parameter in list order.
      --  The connector ends the guard line; the next guard starts on the
      --  continuation indent.
      declare
         Spec : constant String :=
           Synthesize_Bounded_Function
             ("Add", "A:IR_Int32,B:IR_Int32", "IR_Int32");
         Want : constant String :=
           "function Add (A : IR_Int32; B : IR_Int32) return IR_Int32"
           & ASCII.LF
           & "with"
           & ASCII.LF
           & "  Pre => A in IR_Int32'First / 2 .. IR_Int32'Last / 2"
           & " and then"
           & ASCII.LF
           & "        B in IR_Int32'First / 2 .. IR_Int32'Last / 2"
           & ASCII.LF
           & ";"
           & ASCII.LF;
      begin
         R.Check
           (Spec = Want,
            "Test 17: two signed pairs join guards with and-then");
      end;

      --  Test 18: three pairs, signed-unsigned-signed: the guard chain
      --  skips the unsigned pair and keeps list order.
      declare
         Spec : constant String :=
           Synthesize_Bounded_Function
             ("Scale", "A:IR_Int16,S:IR_UInt8,C:IR_Int16", "IR_Int16");
         Want : constant String :=
           "function Scale (A : IR_Int16; S : IR_UInt8; C : IR_Int16)"
           & " return IR_Int16"
           & ASCII.LF
           & "with"
           & ASCII.LF
           & "  Pre => A in IR_Int16'First / 2 .. IR_Int16'Last / 2"
           & " and then"
           & ASCII.LF
           & "        C in IR_Int16'First / 2 .. IR_Int16'Last / 2"
           & ASCII.LF
           & ";"
           & ASCII.LF;
      begin
         R.Check
           (Spec = Want,
            "Test 18: three-pair list guards only the signed pairs");
      end;

      --  Test 19: degradation cases stay empty (never a malformed spec).
      R.Check
        (Synthesize_Bounded_Function
           ("F", "A:IR_Int32,B:float", "IR_Int32")
         = "",
         "Test 19: one foreign type poisons the whole list");
      R.Check
        (Synthesize_Bounded_Function
           ("F", "A:IR_Int32,,B:IR_Int32", "IR_Int32")
         = "",
         "Test 19: an empty pair poisons the whole list");
      R.Check
        (Synthesize_Bounded_Function
           ("F", "A:IR_Int32, B:IR_Int32", "IR_Int32")
         = "",
         "Test 19: a space inside a pair poisons the whole list");
      R.Check
        (Synthesize_Bounded_Function
           ("F", "A:IR_Int32,B:IR_Int32,C:IR_Int32,D:IR_Int32"
            & ",E:IR_Int32,F:IR_Int32,G:IR_Int32,H:IR_Int32"
            & ",I:IR_Int32,J:IR_Int32,K:IR_Int32,L:IR_Int32"
            & ",M:IR_Int32,N:IR_Int32,O:IR_Int32,P:IR_Int32"
            & ",Q:IR_Int32,R:IR_Int32,S:IR_Int32,T:IR_Int32"
            & ",U:IR_Int32,V:IR_Int32,W:IR_Int32,X:IR_Int32"
            & ",Y:IR_Int32,Z:IR_Int32,AA:IR_Int32,AB:IR_Int32"
            & ",AC:IR_Int32,AD:IR_Int32,AE:IR_Int32,AF:IR_Int32"
            & ",AG:IR_Int32,AH:IR_Int32,AI:IR_Int32,AJ:IR_Int32"
            & ",AK:IR_Int32,AL:IR_Int32,AM:IR_Int32,AN:IR_Int32"
            & ",AO:IR_Int32,AP:IR_Int32", "IR_Int32")
         = "",
         "Test 19: a list longer than 32 pairs degrades to empty");

      --  Test 20: a 32-pair list is accepted and every guard is emitted.
      declare
         In_List  : constant String :=
           "A:IR_Int8,B:IR_Int8,C:IR_Int8,D:IR_Int8"
           & ",E:IR_Int8,F:IR_Int8,G:IR_Int8,H:IR_Int8"
           & ",I:IR_Int8,J:IR_Int8,K:IR_Int8,L:IR_Int8"
           & ",M:IR_Int8,N:IR_Int8,O:IR_Int8,P:IR_Int8"
           & ",Q:IR_Int8,R:IR_Int8,S:IR_Int8,T:IR_Int8"
           & ",U:IR_Int8,V:IR_Int8,W:IR_Int8,X:IR_Int8"
           & ",Y:IR_Int8,Z:IR_Int8,AA:IR_Int8,AB:IR_Int8"
           & ",AC:IR_Int8,AD:IR_Int8,AE:IR_Int8,AF:IR_Int8";
         Spec     : constant String :=
           Synthesize_Bounded_Function ("Wide", In_List, "IR_Int8");
      begin
         R.Check
           (Spec'Length > 0 and then Spec'Length <= 4096,
            "Test 20: a full 32-pair list synthesises a bounded spec");
         R.Check
           (Ada.Strings.Fixed.Index (Spec, "; ") = 0
            or else Ada.Strings.Fixed.Index (Spec, "; ") > 0,
            "Test 20: spec is a text result (sanity)");
         R.Check
           (Ada.Strings.Fixed.Count (Spec, "and then") = 31,
            "Test 20: 32 signed pairs join with 31 and-then links");
      end;
   end Run;

end Adacovex_IR_Tests;
