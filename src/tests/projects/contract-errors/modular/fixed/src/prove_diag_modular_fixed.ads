--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Modular_Fixed
  with SPARK_Mode => On
is
   type Mod_256 is mod 256;
   type Mod_16 is mod 16;

   --  Narrow X into Y.
   --  @param X  Source value, already in the target range.
   --  @param Y  Narrowed value.
   procedure Narrow (X : Mod_256; Y : out Mod_16)
     with Pre => X <= Mod_256 (Mod_16'Last);
end Prove_Diag_Modular_Fixed;
