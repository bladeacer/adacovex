package body Prove_Diag_Postcondition_Broken
  with SPARK_Mode => On
is

   function Magnitude (X : Integer) return Integer is
   begin
      return X;
   end Magnitude;
end Prove_Diag_Postcondition_Broken;
