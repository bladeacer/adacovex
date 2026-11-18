package body Prove_Diag_Typo_Identifier_Broken
  with SPARK_Mode => On
is

   function Doubled (X : Integer) return Integer is
   begin
      return X * 2;
   end Doubled;
end Prove_Diag_Typo_Identifier_Broken;
