with Adacovex.Types;

--  Ada source-file scanner.
--  Walks a project directory tree, reads every .ads file, extracts
--  subprogram declarations, HLR tags, and docstring annotations.
--  HLR-SCAN: Source scanning
--
--  Supported docstring annotations (placed immediately before a
--  subprogram declaration, no intervening blank lines):
--    @param Name  Description.       -- Document a formal parameter
--    @return Description.            -- Document a function return value
--    @field Description.             -- Document a record component
--    @formal Name  Description.      -- Document a generic formal
--
--  Standard tag aliases are accepted (`@parameter` == `@param`,
--  `@returns` == `@return`), and the summary tags `@brief` / `@summary`
--  mark a subprogram as documented.
--
--  Conventions (following Ada_CRDT style):
--    Prefix:  --   (two dashes + two spaces)
--    Summary: Capitalized sentence ending with a period.
--    Alignment: Two spaces between tag name and description text.
--    Placement: Summary lines first, then tag lines, then declaration.
--
--  Other standard comment styles are also recognised as docstrings:
--    --  one-line summary (single space, `-- `)
--    --  one-line summary (two spaces, `--  `)
--    --  one-line summary (tab separator)
--  A bare `--` or `---` divider is not a docstring.  Docstrings can
--  appear before or after the declaration.
--
--  Google style (Doxygen-free Python convention):
--    --  Args:
--    --      X (int):  First operand.
--    --  Returns:
--    --      The sum.
--  An "Args:" header opens a parameter block: deeper-indented comment lines
--  inside it count as parameter entries.  "Returns:" marks a documented
--  return value.
--
--  Sphinx style (reStructuredText field lists):
--    --  :param X:  First operand.
--    --  :returns: The sum.
--  ":param"/":parameter" count as parameters, ":return"/":returns" mark a
--  documented return value, and ":type"/":rtype" mark the subprogram as
--  documented.

package Adacovex.Parsers.Source is

   --  Scan a single .ads file, extracting subprogram info and HLR tags.
   --  File_Path must name a readable .ads file. On success, Pkg is populated
   --  with subprogram declarations, docstring annotations, and HLR tag entries.
   --  @param File_Path  Path to .ads file.
   --  @param Pkg  Output package info.
   --  @param Success  True if file was successfully parsed.
   procedure Scan_Ads_File
     (File_Path : String;
      Pkg       : out Types.Implementation.Package_Info;
      Success   : out Boolean)
   with
     Pre  => File_Path'Length > 0,
     Post => (if Success then Pkg.Name_Len > 0);

   --  Recursively scan all .ads files under Target_Dir.
   --  Walk the directory tree rooted at Target_Dir.  Parse every .ads file
   --  found.  Skip directories whose simple name appears in Skip_List
   --  (comma-separated).  Append found packages to the vector.  Files whose
   --  physical lines exceed Types.Max_Line, or whose paths exceed
   --  Types.Max_Path, are reported to standard error.  They are counted in
   --  Skipped_Ct.  They do not produce partial results.
   --  @param Target_Dir  Root directory to scan recursively.
   --  @param Skip_List  Comma-separated directory names to skip (e.g. ".git,obj").
   --  @param Packages  Output vector of parsed packages (appended to).
   --  @param Skipped_Ct  Number of .ads files skipped (line/path overflow).
   procedure Scan_Project
     (Target_Dir : String;
      Skip_List  : String;
      Packages   : in out Types.Implementation.Package_Vectors.Vector;
      Skipped_Ct : out Natural);

   --  Like Scan_Project, but each .ads file is keyed in the on-disk result
   --  cache by its content hash (SHA-256).  Unchanged files are served from
   --  the cache without re-scanning.  Changed files are rescanned and the
   --  cache entry is refreshed.  Hits/Misses report how many files were
   --  served from or written to the cache.
   --  @param Target_Dir  Root directory to scan recursively.
   --  @param Skip_List  Comma-separated directory names to skip.
   --  @param Packages  Output vector of parsed packages (appended to).
   --  @param Skipped_Ct  Number of .ads files skipped (line/path overflow).
   --  @param Hits  Number of files served from the cache.
   --  @param Misses  Number of files rescanned and re-cached.
   --  @param Use_Cache  When False the cache is bypassed and every file is
   --  rescanned (reported as a miss); caller controls this from --no-cache.
   procedure Scan_Project_Cached
     (Target_Dir : String;
      Skip_List  : String;
      Packages   : in out Types.Implementation.Package_Vectors.Vector;
      Skipped_Ct : out Natural;
      Hits       : out Natural;
      Misses     : out Natural;
      Use_Cache  : Boolean := True);

   --  Apply docstring patches to scanned packages.
   --  For each package, checks for a patch file at
   --  <Target_Dir>/.adacovex/patches/<relative-path> and merges its
   --  docstring info into the original package's subprograms.
   --  @param Target_Dir  Root directory used for patch path resolution.
   --  @param Packages  In/out vector of scanned packages to patch.
   procedure Apply_Patches
     (Target_Dir : String;
      Packages   : in out Types.Implementation.Package_Vectors.Vector);

   --  Compute aggregate docstring-coverage metrics from scanned packages.
   --  Tallies documented vs. undocumented subprograms, parameters, and return
   --  values across all scanned packages.
   --  @param Packages  Vector of scanned packages.
   --  @return Aggregate docstring-coverage metrics.
   function Compute_Docstring_Metrics
     (Packages : Types.Implementation.Package_Vectors.Vector)
      return Types.Docstring_Metrics
   with Global => null;

end Adacovex.Parsers.Source;
