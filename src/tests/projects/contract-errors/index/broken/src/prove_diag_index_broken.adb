package body Prove_Diag_Index_Broken
  with SPARK_Mode => On
is

   function Element (T : Table; I : Positive) return Integer is
   begin
      return T (I);
   end Element;
end Prove_Diag_Index_Broken;
