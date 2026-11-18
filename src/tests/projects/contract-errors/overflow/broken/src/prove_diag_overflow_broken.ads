--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Overflow_Broken
  with SPARK_Mode => On
is
   --  Quadruple a bounded value.
   --  @param X  Value to quadruple.
   --  @return Four times X.
   function Quad (X : Integer) return Integer
     with Pre  => X in 0 .. 1_000_000_000,
          Post => Quad'Result = 4 * X;
end Prove_Diag_Overflow_Broken;
