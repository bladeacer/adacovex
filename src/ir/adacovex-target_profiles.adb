package body Adacovex.Target_Profiles is
   pragma SPARK_Mode (On);

   function Checked_Add32 (A, B : IR_Int32) return IR_Int32 is
   begin
      return A + B;
   end Checked_Add32;

   function Checked_Add64 (A, B : IR_Int64) return IR_Int64 is
   begin
      return A + B;
   end Checked_Add64;

end Adacovex.Target_Profiles;
