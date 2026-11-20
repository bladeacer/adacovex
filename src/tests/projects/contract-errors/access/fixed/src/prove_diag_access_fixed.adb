package body Prove_Diag_Access_Fixed
  with SPARK_Mode => On
is

   procedure Set (P : Int_Access; V : Integer) is
   begin
      P.all := V;
   end Set;
end Prove_Diag_Access_Fixed;
