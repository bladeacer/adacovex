--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Invariant_Fixed
  with SPARK_Mode => On
is
   --  Sum the values from 1 to N.
   --  @param N  Upper bound.
   --  @return The sum.
   function Sum_To (N : Natural) return Natural
     with Pre  => N <= 1_000,
          Post => Sum_To'Result = N * (N + 1) / 2;
end Prove_Diag_Invariant_Fixed;
