with Adacovex.Test_Support;

--  Unit tests for the result-cache layer (Adacovex.Cache): SHA-256 hashing
--  and the in-memory stamp fast path (Adacovex.Cache.Stamp_Hits /
--  Stamp_Misses), blob store/load/exists round trips, oldest-first
--  eviction under a bounded cap, and the system-tool probe and
--  registry-metadata stores.

package Adacovex_Cache_Tests is

   --  Run the cache test suite.
   --  @param R  Test runner to record results on.
   procedure Run (R : in out Adacovex.Test_Support.Runner'Class);

end Adacovex_Cache_Tests;
