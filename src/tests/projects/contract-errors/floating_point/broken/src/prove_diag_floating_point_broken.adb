package body Prove_Diag_Floating_Point_Broken
  with SPARK_Mode => On
is

   procedure Grow (X : Float; Y : out Float) is
   begin
      Y := X * 2.0;
   end Grow;
end Prove_Diag_Floating_Point_Broken;
