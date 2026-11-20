--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Assertion_Fixed
  with SPARK_Mode => On
is
   --  Halve X.
   --  @param X  Value to halve.
   --  @return Half of X.
   function Half (X : Integer) return Integer with Pre => X in 0 .. 100;
end Prove_Diag_Assertion_Fixed;
