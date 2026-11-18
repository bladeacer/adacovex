--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Invariant_Entry_Fixed
  with SPARK_Mode => On
is
   --  Count down to zero.
   --  @param N  Start value.
   --  @return The final value.
   function Count_Down (N : Natural) return Natural
     with Pre  => N <= 100,
          Post => Count_Down'Result = 0;
end Prove_Diag_Invariant_Entry_Fixed;
