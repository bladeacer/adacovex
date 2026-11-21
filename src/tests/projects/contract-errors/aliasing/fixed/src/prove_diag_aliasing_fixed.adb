package body Prove_Diag_Aliasing_Fixed
  with SPARK_Mode => On
is

   procedure Swap (X, Y : in out Integer) is
      T : constant Integer := X;
   begin
      X := Y;
      Y := T;
   end Swap;

   procedure Both (V : in out Integer) is
      W : Integer := 0;
   begin
      pragma Assert (V /= 0);
      Swap (V, W);
      V := W;
   end Both;
end Prove_Diag_Aliasing_Fixed;
