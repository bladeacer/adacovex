with Adacovex.Types;

package Adacovex.Parsers.Tests is

   procedure Parse_Test_Result
     (File_Path : String;
      Summary   : out Types.Test_Summary;
      Success   : out Boolean);

   procedure Parse_Test_Stdout
     (Summary : out Types.Test_Summary);

end Adacovex.Parsers.Tests;
