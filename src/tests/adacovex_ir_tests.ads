with Adacovex.Test_Support;

--  Unit tests for the IR synthesis layer: bounded target scalar types
--  (Adacovex.Target_Profiles), host/target word-size configuration, foreign
--  type-name lowering (Adacovex.IR_Synthesiser), and the bounds-checked
--  arithmetic fixture (Adacovex.IR_Bounds).

package Adacovex_IR_Tests is

   --  Run the IR test suite.
   --  @param R  Test runner to record results on.
   procedure Run (R : in out Adacovex.Test_Support.Runner'Class);

end Adacovex_IR_Tests;
