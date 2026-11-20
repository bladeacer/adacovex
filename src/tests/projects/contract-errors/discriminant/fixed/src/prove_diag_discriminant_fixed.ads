--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Discriminant_Fixed
  with SPARK_Mode => On
is
   type Kind is (A, B);

   type Rec (K : Kind := A) is record
      case K is
         when A => X : Integer;
         when B => Y : Integer;
      end case;
   end record;

   --  Read the X component.
   --  @param R  Record with discriminant A.
   --  @return The X component.
   function Get_X (R : Rec) return Integer with Pre => R.K = A;
end Prove_Diag_Discriminant_Fixed;
