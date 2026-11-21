--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Modular_Broken
  with SPARK_Mode => On
is
   type Mod_256 is mod 256;
   type Mod_16 is mod 16;

   --  Narrow X into Y.
   --  @param X  Source value.
   --  @param Y  Narrowed value.
   procedure Narrow (X : Mod_256; Y : out Mod_16);
end Prove_Diag_Modular_Broken;
