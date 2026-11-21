--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Aliasing_Fixed
  with SPARK_Mode => On
is

   --  Exchange two values.
   --  @param X  First value.
   --  @param Y  Second value.
   procedure Swap (X, Y : in out Integer);

   --  Exchange a value with a distinct local value.
   --  @param V  Value to exchange, which must be non-zero.
   procedure Both (V : in out Integer) with Pre => V /= 0;
end Prove_Diag_Aliasing_Fixed;
