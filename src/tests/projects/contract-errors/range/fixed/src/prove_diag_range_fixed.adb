package body Prove_Diag_Range_Fixed
  with SPARK_Mode => On
is

   function Narrow (X : Integer) return Small is
   begin
      return X;
   end Narrow;
end Prove_Diag_Range_Fixed;
