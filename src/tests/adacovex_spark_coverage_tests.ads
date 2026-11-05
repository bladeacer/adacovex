with Adacovex.Test_Support;

package Adacovex_Spark_Coverage_Tests is

   --  Run the SPARK coverage report tests through R.
   --  @param R  Native test runner the cases register on.
   procedure Run (R : in out Adacovex.Test_Support.Runner'Class);

end Adacovex_Spark_Coverage_Tests;
