--  Prove diagnostics end-to-end fixture.
package Prove_Diag_Index_Fixed
  with SPARK_Mode => On
is
   type Table is array (Positive range <>) of Integer;

   --  Read one element of a table.
   --  @param T  Table to read.
   --  @param I  Index to read.
   --  @return The element at I.
   function Element (T : Table; I : Positive) return Integer
     with Pre => I in T'Range;
end Prove_Diag_Index_Fixed;
