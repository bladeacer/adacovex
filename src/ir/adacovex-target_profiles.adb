with System;

package body Adacovex.Target_Profiles is
   pragma SPARK_Mode (On);

   function Host_Word_Size return Word_Size is
   begin
      if System.Word_Size <= 8 then
         return Bits_8;
      elsif System.Word_Size <= 16 then
         return Bits_16;
      elsif System.Word_Size <= 32 then
         return Bits_32;
      else
         return Bits_64;
      end if;
   end Host_Word_Size;

   function Checked_Add32 (A, B : IR_Int32) return IR_Int32 is
   begin
      return A + B;
   end Checked_Add32;

   function Checked_Add64 (A, B : IR_Int64) return IR_Int64 is
   begin
      return A + B;
   end Checked_Add64;

end Adacovex.Target_Profiles;
