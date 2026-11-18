--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Division_Fixed
  with SPARK_Mode => On
is
   --  Divide X by Y.
   --  @param X  Dividend.
   --  @param Y  Divisor.
   --  @return X divided by Y.
   function Ratio (X : Integer; Y : Integer) return Integer
     with Pre  => X in -100 .. 100 and Y /= 0,
          Post => Ratio'Result = X / Y;
end Prove_Diag_Division_Fixed;
