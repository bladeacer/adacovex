--  Content-addressed result cache for adacovex.
--  Stores arbitrary small blobs keyed by the SHA-256 of their *input* (a source
--  file's contents, a gnatprove.out, a test-result file, ...).  Because the key
--  is derived from the inputs, an unchanged input always hits the same cache
--  entry, so re-running adacovex on unchanged code serves results straight
--  from disk -- no re-scan, no re-parse, and (for gnatprove) no re-proof.
--
--  The store is split per input: every analyzed unit is cached under its own
--  key, so a one-line change only invalidates that unit's entry and rewrites a
--  single tiny blob; every other unit is served from cache unchanged.
--
--  Storage is a two-level directory tree (<cache>/<aa>/<aabb...>) so a large
--  project never creates a single directory with millions of entries.  Entries
--  are evicted oldest-first once the count exceeds a soft cap, keeping disk
--  usage bounded without external dependencies (pure GNAT runtime only).
--  HLR-CACHE: Result caching

package Adacovex.Cache is

   --  Maximum size of a single cached blob (1 MiB).  Source files larger than
   --  Max_Line are already rejected by the scanner, so a serialized per-file
   --  scan result always fits; larger blobs are simply not cached.
   Max_Cache_Blob : constant := 1_048_576;

   --  Cache-schema namespace.  Bump when the serialized layout of cached
   --  records (Package_Info / Proof_Summary / Test_Summary) or the scanner /
   --  parser semantics change, so blobs written by an incompatible build are
   --  never served.  Appended to the default cache directory below.
   Cache_Schema : constant String := "s5";

   --  Soft cap on the number of cache entries kept on disk.  Once exceeded,
   --  the oldest entries are evicted first.
   Default_Max_Entries : constant := 4096;

   --  Compute the default cache directory:
   --    <HOME>/.adacovex/cache/<adacovex-version>/
   --  Falls back to /tmp when HOME is unset.
   --  @param Dir  Output buffer for the directory path.
   --  @param Len  Length of the written path.
   procedure Default_Cache_Dir (Dir : out String; Len : out Natural);

   --  Override the cache root used by Store/Load/Exists/Evict.  Defaults to
   --  Default_Cache_Dir at elaboration; call this to honor --cache-dir.
   --  @param Dir  New cache root directory (need not end in a separator).
   procedure Set_Cache_Dir (Dir : String);

   --  The currently configured cache root directory.
   --  @param Dir  Output buffer for the directory path.
   --  @param Len  Length of the written path.
   procedure Cache_Dir (Dir : out String; Len : out Natural);

   --  SHA-256 (hex, 64 chars) of a file's contents.  The file is read in
   --  binary chunks and each chunk is fed to the hasher, so the digest is
   --  stable across runs for identical content.  Returns the empty string
   --  when the file cannot be read.
   --  @param Path  File to hash.
   --  @return 64-character lowercase hex digest, or "" on error.
   function Hash_File (Path : String) return String;

   --  SHA-256 (hex, 64 chars) of an in-memory string.
   --  @param S  String to hash.
   --  @return 64-character lowercase hex digest.
   function Hash_String (S : String) return String;

   --  Store a blob under Key (the 64-char hex digest).  Parent directories are
   --  created as needed under the configured cache root.  Overwrites any
   --  existing entry for the same key.
   --  @param Key  Cache key (64-char hex digest).
   --  @param Data  Blob payload.
   --  @param Success  True if the blob was written.
   procedure Store (Key : String; Data : String; Success : out Boolean);

   --  Load a blob previously stored under Key.
   --  @param Key  Cache key (64-char hex digest).
   --  @param Data  Output buffer for the blob (up to Max_Cache_Blob bytes).
   --  @param Len  Length of the loaded blob.
   --  @param Found  True when the entry existed and fit in Data.
   procedure Load
     (Key : String; Data : out String; Len : out Natural; Found : out Boolean);

   --  True when an entry exists for Key (without loading its payload).
   --  @param Key  Cache key.
   --  @return True if the entry is present.
   function Exists (Key : String) return Boolean;

   --  Configure the eviction cap used by Put_Cached.  Defaults to 4096.
   --  @param Max_Entries  Soft cap on retained cache entries.
   procedure Set_Cache_Policy (Max_Entries : Positive);

   --  Load a cached blob, returning whether it was present and fit in the
   --  output buffer.  Convenience wrapper over Load.
   --  @param Key  Cache key.
   --  @param Data  Output buffer for the blob.
   --  @param Len  Length of the loaded blob.
   --  @param Found  True when the entry existed and fit in Data.
   procedure Get_Cached
     (Key : String; Data : out String; Len : out Natural; Found : out Boolean);

   --  Store a blob under Key, then evict oldest entries until the configured
   --  cap is satisfied.  Convenience wrapper over Store + Evict_If_Needed.
   --  @param Key  Cache key.
   --  @param Data  Blob payload.
   --  @param Success  True if the blob was written.
   procedure Put_Cached (Key : String; Data : String; Success : out Boolean);

   --  Evict oldest-first until at most Max_Entries entries remain under the
   --  configured cache root.  No-op (and harmless) when the count is already
   --  within the cap.
   --  @param Max_Entries  Soft cap on retained entries.
   procedure Evict_If_Needed (Max_Entries : Positive);

   --  Running count of entries evicted because the cache reached its size
   --  cap.  Read by the CLI to report cache effectiveness.
   Eviction_Count : Natural := 0;

   --  Probe freshness: how long a cached system-tool version probe stays
   --  valid.  Tool versions change rarely; re-probing every run costs a
   --  subprocess spawn per referenced tool (tens of ms each on the SBOM /
   --  serve paths).  A week-old probe is still a fine answer.
   Probe_TTL_Days : constant := 7;

   --  Load a cached version-probe result for a system tool ("tool=version"
   --  files stored under <cache>/probes/).  A probe younger than
   --  Probe_TTL_Days is served from disk; older or missing probes are
   --  reported as not found so the caller re-probes.
   --  @param Tool  Tool name (safe characters only).
   --  @param Value  Output version string (may be empty).
   --  @param Val_Len  Length of the version string.
   --  @param Found  True when a fresh probe existed.
   procedure Get_Probe
     (Tool    : String;
      Value   : out String;
      Val_Len : out Natural;
      Found   : out Boolean);

   --  Store a system-tool version probe result on disk (overwrites any
   --  existing entry for the tool).
   --  @param Tool  Tool name (safe characters only).
   --  @param Value  Version string (may be empty).
   procedure Put_Probe (Tool : String; Value : String);

   --  Serialize an arbitrary streamable value to/from a cache-blob String
   --  using an in-memory stream.  Supports any type whose components are
   --  streamable (bounded strings, scalars, enums, Ada.Containers.Vectors of
   --  streamable elements) -- e.g. Package_Info, Proof_Summary, Test_Summary.
   --  @param T  The streamable type to (de)serialize.
   generic
      type T is private;
   package Serialization is
      --  Encode X into a blob string suitable for Store.
      --  @param X  Value to encode.
      --  @return Blob string.
      function Serialize (X : T) return String;

      --  Decode a blob string previously produced by Serialize.
      --  @param S  Blob string.
      --  @param X  Decoded value.
      --  @return True on success; False on malformed input.
      function Deserialize (S : String; X : out T) return Boolean;
   end Serialization;

end Adacovex.Cache;
