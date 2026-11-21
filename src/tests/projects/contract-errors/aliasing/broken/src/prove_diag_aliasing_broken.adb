package body Prove_Diag_Aliasing_Broken
  with SPARK_Mode => On
is

   procedure Swap (X, Y : in out Integer) is
      T : constant Integer := X;
   begin
      X := Y;
      Y := T;
   end Swap;

   procedure Both (V : in out Integer) is
   begin
      Swap (V, V);
   end Both;
end Prove_Diag_Aliasing_Broken;
