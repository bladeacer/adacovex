--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Flow_Broken
  with SPARK_Mode => On
is
   --  Add an offset to a value.
   --  @param X  Value to offset.
   --  @return X plus the offset.
   function Offset_Of (X : Integer) return Integer
     with Pre => X in 0 .. 1_000;
end Prove_Diag_Flow_Broken;
