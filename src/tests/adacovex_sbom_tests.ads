with Adacovex.Test_Support;

--  Unit tests for the proof-aware SBOM feature: property-value mapping,
--  Alire manifest / .gpr dependency-graph resolution, and CycloneDX 1.5 /
--  SPDX 2.3 JSON generation.

package Adacovex_SBOM_Tests is

   --  Run the SBOM test suite.
   --  @param R  Test runner to record results on.
   procedure Run (R : in out Adacovex.Test_Support.Runner'Class);

end Adacovex_SBOM_Tests;
