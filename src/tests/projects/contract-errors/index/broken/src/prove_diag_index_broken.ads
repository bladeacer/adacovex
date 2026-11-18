--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Index_Broken
  with SPARK_Mode => On
is
   type Table is array (Positive range <>) of Integer;

   --  Read one element of a table.
   --  @param T  Table to read.
   --  @param I  Index to read.
   --  @return The element at I.
   function Element (T : Table; I : Positive) return Integer
     with Pre => I <= T'Length;
end Prove_Diag_Index_Broken;
