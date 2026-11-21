--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Aliasing_Broken
  with SPARK_Mode => On
is

   --  Exchange two values.
   --  @param X  First value.
   --  @param Y  Second value.
   procedure Swap (X, Y : in out Integer) with Pre => X /= Y;

   --  Exchange a value with itself.
   --  @param V  Value to exchange.
   procedure Both (V : in out Integer);
end Prove_Diag_Aliasing_Broken;
