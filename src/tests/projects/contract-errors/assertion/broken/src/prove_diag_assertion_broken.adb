package body Prove_Diag_Assertion_Broken
  with SPARK_Mode => On
is

   function Half (X : Integer) return Integer is
   begin
      pragma Assert (X <= 100);
      return X / 2;
   end Half;
end Prove_Diag_Assertion_Broken;
