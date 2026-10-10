package body Adacovex.IR_Bounds is
   pragma SPARK_Mode (On);

   function Add32 (A, B : int32_t) return int32_t is
   begin
      return A + B;
   end Add32;

   function Add64 (A, B : int64_t) return int64_t is
   begin
      return A + B;
   end Add64;

end Adacovex.IR_Bounds;
