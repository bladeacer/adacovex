package body Prove_Diag_Division_Fixed
  with SPARK_Mode => On
is

   function Ratio (X : Integer; Y : Integer) return Integer is
   begin
      return X / Y;
   end Ratio;
end Prove_Diag_Division_Fixed;
