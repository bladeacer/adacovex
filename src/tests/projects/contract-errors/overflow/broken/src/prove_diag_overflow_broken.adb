package body Prove_Diag_Overflow_Broken
  with SPARK_Mode => On
is

   function Quad (X : Integer) return Integer is
   begin
      return 4 * X;
   end Quad;
end Prove_Diag_Overflow_Broken;
