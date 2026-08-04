--  Bounded machine-integer profiles for IR synthesis.
--  Defines the explicit fixed-width scalar types (IR_Int8 .. IR_Int64 and
--  IR_UInt8 .. IR_UInt64) onto which foreign type names (int32_t, size_t,
--  usize, ...) are lowered, plus the host/target word-size configuration
--  that drives the lowering.  The types are SPARK-proved: bounds-checked
--  arithmetic on them is verified by gnatprove, demonstrating absence of
--  integer overflow for synthesized code that uses them.
--  HLR-IR: IR type profiles and bounds

package Adacovex.Target_Profiles is
   pragma SPARK_Mode (On);

   --  Signed two's-complement fixed-width integer types.  Each carries an
   --  explicit Size so that IR values map one-to-one onto target machine
   --  types.
   type IR_Int8  is range -2**7  .. 2**7 - 1  with Size => 8;
   type IR_Int16 is range -2**15 .. 2**15 - 1 with Size => 16;
   type IR_Int32 is range -2**31 .. 2**31 - 1 with Size => 32;
   type IR_Int64 is range -2**63 .. 2**63 - 1 with Size => 64;

   --  Unsigned fixed-width integer types.  Modular (wrapping) semantics
   --  mirror C/C++ unsigned behaviour: arithmetic cannot raise overflow.
   type IR_UInt8  is mod 2**8;
   type IR_UInt16 is mod 2**16;
   type IR_UInt32 is mod 2**32;
   type IR_UInt64 is mod 2**64;

   --  A machine word size, in bits.
   type Word_Size is (Bits_8, Bits_16, Bits_32, Bits_64);

   --  Host vs. target machine model:
   --    Host_Bits    -- word size adacovex itself executes on
   --    Target_Bits  -- word size of the target being synthesised
   --    Pointer_Bits -- target pointer width (drives size_t / usize)
   type Target_Config is record
      Host_Bits    : Word_Size := Bits_64;
      Target_Bits  : Word_Size := Bits_64;
      Pointer_Bits : Word_Size := Bits_64;
   end record;

   --  Bounds-checked 32-bit addition.  Restricting both operands to the
   --  inner half of the range guarantees the sum is representable; gnatprove
   --  discharges the overflow check, proving absence of integer overflow.
   --  @param A  First operand.
   --  @param B  Second operand.
   --  @return The sum of A and B.
   function Checked_Add32 (A, B : IR_Int32) return IR_Int32 with
     Pre => A in IR_Int32'First / 2 .. IR_Int32'Last / 2
       and then B in IR_Int32'First / 2 .. IR_Int32'Last / 2;

   --  Bounds-checked 64-bit addition, analogous to Checked_Add32.
   --  @param A  First operand.
   --  @param B  Second operand.
   --  @return The sum of A and B.
   function Checked_Add64 (A, B : IR_Int64) return IR_Int64 with
     Pre => A in IR_Int64'First / 2 .. IR_Int64'Last / 2
       and then B in IR_Int64'First / 2 .. IR_Int64'Last / 2;

end Adacovex.Target_Profiles;
