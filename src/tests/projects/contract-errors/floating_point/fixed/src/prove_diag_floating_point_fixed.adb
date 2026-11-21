package body Prove_Diag_Floating_Point_Fixed
  with SPARK_Mode => On
is

   procedure Grow (X : Float; Y : out Float) is
   begin
      Y := X;
   end Grow;
end Prove_Diag_Floating_Point_Fixed;
