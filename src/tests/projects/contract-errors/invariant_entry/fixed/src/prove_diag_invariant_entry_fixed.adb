package body Prove_Diag_Invariant_Entry_Fixed
  with SPARK_Mode => On
is

   function Count_Down (N : Natural) return Natural is
      Left : Natural := N;
   begin
      while Left > 0 loop
         pragma Loop_Invariant (Left <= N);
         pragma Loop_Variant (Decreases => Left);
         Left := Left - 1;
      end loop;
      return Left;
   end Count_Down;
end Prove_Diag_Invariant_Entry_Fixed;
