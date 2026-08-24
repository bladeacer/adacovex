with Adacovex.Target_Profiles;

--  Bounds-verification fixture for IR synthesis.
--  A synthesized-style module whose declaration lines match the output of
--  Adacovex.IR_Synthesiser.Lower_Type_Name for int32_t / int64_t.
--  The checked-arithmetic functions operate on the bounded IR types.
--  gnatprove proves absence of integer overflow on the overflow checks of
--  those functions.
--  HLR-IR: IR bounds verification

package Adacovex.IR_Bounds is
   pragma SPARK_Mode (On);

   --  Lowered 32-bit signed type (synthesized declaration).
   type int32_t is new Adacovex.Target_Profiles.IR_Int32;

   --  Lowered 64-bit signed type (synthesized declaration).
   type int64_t is new Adacovex.Target_Profiles.IR_Int64;

   --  Bounds-checked addition on the lowered 32-bit type.  The
   --  inner-half precondition makes the overflow check provably safe.
   --  @param A  First operand.
   --  @param B  Second operand.
   --  @return The sum of A and B.
   function Add32 (A, B : int32_t) return int32_t
   with
     Pre =>
       A in int32_t'First / 2 .. int32_t'Last / 2
       and then B in int32_t'First / 2 .. int32_t'Last / 2;

--  Bounds-checked addition on the lowered 64-bit type.  It is the 64-bit
--  equivalent of Add32.
   --  @param A  First operand.
   --  @param B  Second operand.
   --  @return The sum of A and B.
   function Add64 (A, B : int64_t) return int64_t
   with
     Pre =>
       A in int64_t'First / 2 .. int64_t'Last / 2
       and then B in int64_t'First / 2 .. int64_t'Last / 2;

end Adacovex.IR_Bounds;
