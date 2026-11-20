--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Access_Fixed
  with SPARK_Mode => On
is
   type Int_Access is access Integer;

   --  Store V through P.
   --  @param P  Destination, which must not be null.
   --  @param V  Value to store.
   procedure Set (P : Int_Access; V : Integer) with Pre => P /= null;
end Prove_Diag_Access_Fixed;
