--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Assertion_Broken
  with SPARK_Mode => On
is
   --  Halve X.
   --  @param X  Value to halve.
   --  @return Half of X.
   function Half (X : Integer) return Integer with Pre => X >= 0;
end Prove_Diag_Assertion_Broken;
