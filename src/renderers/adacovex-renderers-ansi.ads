with Adacovex.Types;

--  Terminal ANSI renderer.
--  Produces a coloured, human-readable report on standard output using
--  ANSI escape sequences for highlighting. Supports NO_COLOR and
--  non-interactive terminal detection.
--  HLR-RENDER-ANSI: ANSI rendering

package Adacovex.Renderers.ANSI is

   --  Print a formatted report to standard output.
   --  Displays a colour-coded summary of docstring coverage, proof results,
   --  test results, and DO-178C DAL compliance using ANSI escape sequences.
   --  Set Use_Color to False to suppress ANSI codes (e.g., redirected output
   --  or NO_COLOR environment variable).
   --  @param Doc_Metrics  Docstring coverage metrics.
   --  @param Proof  GNATprove proof summary.
   --  @param Tests  Test result summary.
   --  @param DAL_Assess  DAL compliance assessment.
   --  @param Packages  Scanned package vector.
   --  @param Use_Color  Enable ANSI color output (default False).
   --  @param Cache_Hits  Number of analysis results served from the cache.
   --  @param Cache_Misses  Number of results recomputed and re-cached.
   --  @param Cache_Evictions  Number of stale entries evicted from the cache.
   procedure Render_Summary
     (Doc_Metrics     : Types.Docstring_Metrics;
      Proof           : Types.Proof_Summary;
      Tests           : Types.Implementation.Test_Summary;
      DAL_Assess      : Types.Implementation.DAL_Assessment;
      Packages        : Types.Implementation.Package_Vectors.Vector;
      Use_Color       : Boolean := False;
      Cache_Hits      : Natural := 0;
      Cache_Misses    : Natural := 0;
      Cache_Evictions : Natural := 0);

end Adacovex.Renderers.ANSI;
