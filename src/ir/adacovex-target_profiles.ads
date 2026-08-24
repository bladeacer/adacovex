--  Bounded machine-integer profiles for IR synthesis.
--  This package defines the explicit fixed-width scalar types
--  (IR_Int8 .. IR_Int64 and IR_UInt8 .. IR_UInt64).  Foreign type names
--  (int32_t, size_t, usize, and more) are lowered onto them.  The
--  host/target word-size configuration drives the lowering.
--  The types are SPARK-proved.  gnatprove verifies the bounds-checked
--  arithmetic on them.  This proves absence of integer overflow for
--  synthesised code that uses the types.
--  HLR-IR: IR type profiles and bounds

package Adacovex.Target_Profiles is
   pragma SPARK_Mode (On);

   --  Signed two's-complement fixed-width integer types.  Each carries an
   --  explicit Size.  IR values map one-to-one onto target machine types.
   type IR_Int8 is range -2**7 .. 2**7 - 1 with Size => 8;
   type IR_Int16 is range -2**15 .. 2**15 - 1 with Size => 16;
   type IR_Int32 is range -2**31 .. 2**31 - 1 with Size => 32;
   type IR_Int64 is range -2**63 .. 2**63 - 1 with Size => 64;

   --  Unsigned fixed-width integer types.  Modular (wrapping) semantics
   --  match C/C++ unsigned behaviour.  Arithmetic cannot raise overflow.
   type IR_UInt8 is mod 2**8;
   type IR_UInt16 is mod 2**16;
   type IR_UInt32 is mod 2**32;
   type IR_UInt64 is mod 2**64;

   --  A machine word size, in bits.
   type Word_Size is (Bits_8, Bits_16, Bits_32, Bits_64);

   --  Host vs. target machine model:
   --    Host_Bits    -- Word size of the machine on which adacovex itself
   --                   -- executes.
   --    Target_Bits  -- Word size of the target being synthesised.
   --    Pointer_Bits -- Target pointer width (it drives size_t / usize).
   type Target_Config is record
      Host_Bits    : Word_Size := Bits_64;
      Target_Bits  : Word_Size := Bits_64;
      Pointer_Bits : Word_Size := Bits_64;
   end record;

   --  Auto-detects the host machine word size from the Ada runtime
   --  (System.Word_Size: 8, 16, 32, or 64 bits).  Callers use it to populate
   --  Target_Config.Host_Bits for the machine on which adacovex executes.
   --  @return Bits_8 .. Bits_64 matching the host word size.
   function Host_Word_Size return Word_Size
   with Global => null;

   --  Bounds-checked 32-bit addition.  Restricting both operands to the
   --  inner half of the range guarantees the sum is representable.  gnatprove
   --  discharges the overflow check and proves absence of integer overflow.
   --  @param A  First operand.
   --  @param B  Second operand.
   --  @return The sum of A and B.
   function Checked_Add32 (A, B : IR_Int32) return IR_Int32
   with
     Pre =>
       A in IR_Int32'First / 2 .. IR_Int32'Last / 2
       and then B in IR_Int32'First / 2 .. IR_Int32'Last / 2;

   --  Bounds-checked 64-bit addition, analogous to Checked_Add32.
   --  @param A  First operand.
   --  @param B  Second operand.
   --  @return The sum of A and B.
   function Checked_Add64 (A, B : IR_Int64) return IR_Int64
   with
     Pre =>
       A in IR_Int64'First / 2 .. IR_Int64'Last / 2
       and then B in IR_Int64'First / 2 .. IR_Int64'Last / 2;

end Adacovex.Target_Profiles;
