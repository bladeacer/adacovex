package body Prove_Diag_Precondition_Broken
  with SPARK_Mode => On
is

   function Non_Neg (X : Integer) return Integer is
   begin
      return X;
   end Non_Neg;

   function Unchecked_Call (X : Integer) return Integer is
   begin
      return Non_Neg (X);
   end Unchecked_Call;
end Prove_Diag_Precondition_Broken;
