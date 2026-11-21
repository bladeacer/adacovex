--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Floating_Point_Broken
  with SPARK_Mode => On
is

   --  Double X into Y.
   --  @param X  Input value.
   --  @param Y  Doubled value.
   procedure Grow (X : Float; Y : out Float);
end Prove_Diag_Floating_Point_Broken;
