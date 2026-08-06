with System;

package body Adacovex.Target_Profiles is
   pragma SPARK_Mode (On);

   function Host_Word_Size return Word_Size
   is (case System.Word_Size is
         when 8      => Bits_8,
         when 16     => Bits_16,
         when 32     => Bits_32,
         when others => Bits_64);

   function Checked_Add32 (A, B : IR_Int32) return IR_Int32 is
   begin
      return A + B;
   end Checked_Add32;

   function Checked_Add64 (A, B : IR_Int64) return IR_Int64 is
   begin
      return A + B;
   end Checked_Add64;

end Adacovex.Target_Profiles;
