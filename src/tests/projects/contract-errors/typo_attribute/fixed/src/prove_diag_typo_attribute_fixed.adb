package body Prove_Diag_Typo_Attribute_Fixed
  with SPARK_Mode => On
is

   function Doubled (X : Integer) return Integer is
   begin
      return X * 2;
   end Doubled;
end Prove_Diag_Typo_Attribute_Fixed;
