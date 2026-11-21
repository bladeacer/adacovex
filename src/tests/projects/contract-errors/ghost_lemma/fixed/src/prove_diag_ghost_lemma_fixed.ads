--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Ghost_Lemma_Fixed
  with SPARK_Mode => On
is

   --  State a fact about X.
   --  @param X  Value the lemma reasons about.
   procedure Lemma (X : Integer)
     with Ghost,
          Pre  => X > 0,
          Post => X > 0;
end Prove_Diag_Ghost_Lemma_Fixed;
