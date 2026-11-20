package body Prove_Diag_Discriminant_Broken
  with SPARK_Mode => On
is

   function Get_X (R : Rec) return Integer is
   begin
      return R.X;
   end Get_X;
end Prove_Diag_Discriminant_Broken;
