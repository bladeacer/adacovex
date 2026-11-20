# Adacovex.Cache

Content-addressed result cache for adacovex.
The cache stores arbitrary small blobs keyed by the SHA-256 of their input
(a source file's contents, a gnatprove.out, a test-result file, and more).
The key is derived from the inputs. An unchanged input always hits the
same cache entry. Re-running adacovex on unchanged code serves results
straight from disk. There is no re-scan, no re-parse, and (for gnatprove)
no re-proof.

The store is split per input. Every analysed unit is cached under its own
key. A one-line change only invalidates that unit's entry and rewrites a
single tiny blob. Every other unit is served from cache unchanged.

Storage is a two-level directory tree (``<cache>/<aa>/<aabb...>``). A large
project never creates a single directory with millions of entries. Entries
are evicted oldest-first once the count exceeds a soft cap. Disk usage
stays bounded without external dependencies (pure GNAT runtime only).

A namespaced key spells its namespace with ``:`` (``scan:``, ``tests:``,
``prove:``, ``proveout:``, ``provesarif:``, ``hlr:``, ``llr:``, ``tools-``,
``graph-``). The entry path replaces every ``:`` with ``-``, because
Windows rejects ``:`` in a file name (a blob written under such a name
lands in an alternate data stream and is never found again). The mapping
is documented on ``Entry_Path`` in the body.
HLR-CACHE: Result caching

**See also:** [Architecture -- result caching](../contributing/architecture.md#result-caching)

> **Note:** All items in this package are public.

## Functions

### function Cache_Expiry return Standard.Natural

> The entry lifetime in days currently in force.

**Returns:** The configured lifetime (0 = never expire).

### function Exists (Key : Standard.String) return Standard.Boolean

> True when an entry exists for Key (without loading its payload).

| Parameter | Description |
|-----------|-------------|
| `Key` | Cache key. |

**Returns:** True if the entry is present.

### function Hash_File (Path : Standard.String) return Standard.String

> SHA-256 (hex, 64 chars) of a file's contents. The file is read in binary chunks. Each chunk is fed to the hasher. The digest is stable across runs for identical content. The function returns the empty string when the file cannot be read. Two fast paths avoid the read entirely: * the in-process stamp map (same path, same size, this run); * the persistent stat-stamp store (same path, same size AND mtime, any run) -- two stats replace the open/read/close/hash cycle. A freshly hashed file is recorded in both stores.

| Parameter | Description |
|-----------|-------------|
| `Path` | File to hash. |

**Returns:** 64-character lowercase hex digest, or "" on error.

### function Hash_String (S : Standard.String) return Standard.String

> SHA-256 (hex, 64 chars) of an in-memory string.

| Parameter | Description |
|-----------|-------------|
| `S` | String to hash. |

**Returns:** 64-character lowercase hex digest.

### function Tool_Fingerprint (Exe_Path : Standard.String) return Standard.String

> Identity of a tool's installed binary: the PATH-resolved executable path, its size, and its mtime, joined with '|'. The probe cache stores this image next to the version it probed; Get_Probe serves the stored answer only while the live binary's fingerprint matches.

| Parameter | Description |
|-----------|-------------|
| `Exe_Path` | Absolute path of the tool executable (as returned by Locate_Exec_On_Path). |

**Returns:** The fingerprint image; the path alone when stat fails; "" when Exe_Path is empty.

## Procedures

### procedure Cache_Dir (Dir : Standard.String; Len : Standard.Natural)

> The currently configured cache root directory.

| Parameter | Description |
|-----------|-------------|
| `Dir` | Output buffer for the directory path. |
| `Len` | Length of the written path. |

### procedure Clear (Entries : Standard.Natural; Success : Standard.Boolean)

> Remove every entry under the configured cache root. The count is taken before removal. The procedure refuses an empty root, a file-system root ("/" or a drive root), and the user's home directory, so a bad --cache-dir can never empty an unrelated tree. Only the entries inside the configured root are removed; the root itself stays.

| Parameter | Description |
|-----------|-------------|
| `Entries` | Number of files removed (0 when the clear was refused or the root held nothing). |
| `Success` | True when the root was cleared (an empty or absent root counts as success). |

### procedure Default_Cache_Dir (Dir : Standard.String; Len : Standard.Natural)

> Compute the default cache directory. The directory is the platform cache directory from Adacovex.Paths (XDG_CACHE_HOME on Linux, ~/Library/Caches on macOS, %LOCALAPPDATA% on Windows, or $ADACOVEX_STATE_HOME/cache when that override is set), then /<adacovex-version>/<cache-schema>.

| Parameter | Description |
|-----------|-------------|
| `Dir` | Output buffer for the directory path. |
| `Len` | Length of the written path. |

### procedure Delete (Key : Standard.String; Success : Standard.Boolean)

> Remove the entry stored under Key, when one exists. Used by the prove runner's cache-poison guard: a stored proof summary that itself reports unproved VCs must be dropped instead of served, so the next run re-proves and overwrites the store with a healthy one.

| Parameter | Description |
|-----------|-------------|
| `Key` | Cache key. |
| `Success` | True when the entry was found and removed (or was already absent). |

### procedure Evict_If_Needed (Max_Entries : Standard.Positive)

> Evict oldest-first until at most Max_Entries entries remain under the configured cache root. The procedure is a no-op (and harmless) when the count is already within the cap.

| Parameter | Description |
|-----------|-------------|
| `Max_Entries` | Soft cap on retained entries. |

### procedure Get_Cached (Key : Standard.String; Data : Standard.String; Len : Standard.Natural; Found : Standard.Boolean)

> Load a cached blob. The procedure returns whether it was present and fit in the output buffer. Convenience wrapper over Load.

| Parameter | Description |
|-----------|-------------|
| `Data` | Output buffer for the blob. |
| `Found` | True when the entry existed and fit in Data. |
| `Key` | Cache key. |
| `Len` | Length of the loaded blob. |

### procedure Get_Meta (Target : Standard.String; Ecosystem : Standard.String; Name : Standard.String; License : Standard.String; Lic_Len : Standard.Natural; Version : Standard.String; Ver_Len : Standard.Natural; Website : Standard.String; Web_Len : Standard.Natural; Found : Standard.Boolean)

> Registry-metadata cache for vendored packages. The graph builder resolves a package's licence, version, and website from its ecosystem registry CLI (npm/pnpm/cargo/...). Those calls boot a subprocess (node for npm/pnpm) and are not covered by the content-addressed result cache, so a "warm" run still paid for them -- that was the main residual slowness on `just prove`. This cache mirrors the system-tool probe cache: the answers live in the machine-local data directory (`<data>/meta`), outside the result cache, with the same 7-day TTL, so a warm run serves them from disk with zero subprocess spawns and a wiped or redirected result cache never re-resolves. A re-resolution (and re-cache) happens only when the entry is missing or older than the TTL.

| Parameter | Description |
|-----------|-------------|
| `Ecosystem` | PURL type (npm, pypi, cargo, ...). |
| `Found` | True when a fresh entry existed. |
| `Lic_Len` | Length of the licence string. |
| `License` | Output licence string (may be empty). |
| `Name` | Package name. |
| `Target` | Project directory the package belongs to. |
| `Ver_Len` | Length of the version string. |
| `Version` | Output version string (may be empty). |
| `Web_Len` | Length of the website string. |
| `Website` | Output website string (may be empty). |

### procedure Get_Probe (Tool : Standard.String; Fingerprint : Standard.String; Value : Standard.String; Val_Len : Standard.Natural; Found : Standard.Boolean)

> Load a cached version-probe result for a system tool ("tool=version" files stored under <cache>/probes/). A probe younger than Probe_TTL_Days is served from disk. Older or missing probes are reported as not found. The caller then re-probes. The cached answer is validated against the fingerprint of the tool's installed binary (its PATH location plus size and mtime) before it is served: Fingerprint must be the image Locate_Exec_On_Path returned for the tool in THIS run. An upgraded or replaced binary changes the fingerprint, the stored answer is discarded, and the caller re-probes -- a probe cache keyed only on the tool name and a time TTL served stale versions for up to a week after an upgrade.

| Parameter | Description |
|-----------|-------------|
| `Fingerprint` | Binary identity image ("<exe>|<size>|<mtime>"; the caller obtains it with Cache.Tool_Fingerprint). |
| `Found` | True when a fresh probe existed for THIS binary. |
| `Tool` | Tool name (safe characters only). |
| `Val_Len` | Length of the version string. |
| `Value` | Output version string (may be empty). |

### procedure Load (Key : Standard.String; Data : Standard.String; Len : Standard.Natural; Found : Standard.Boolean)

> Load a blob previously stored under Key.

| Parameter | Description |
|-----------|-------------|
| `Data` | Output buffer for the blob (up to Max_Cache_Blob bytes). |
| `Found` | True when the entry existed and fit in Data. |
| `Key` | Cache key (64-char hex digest). |
| `Len` | Length of the loaded blob. |

### procedure Put_Cached (Key : Standard.String; Data : Standard.String; Success : Standard.Boolean)

> Store a blob under Key. The procedure then evicts oldest entries until the configured cap is satisfied. Convenience wrapper over Store + Evict_If_Needed.

| Parameter | Description |
|-----------|-------------|
| `Data` | Blob payload. |
| `Key` | Cache key. |
| `Success` | True if the blob was written. |

### procedure Put_Meta (Target : Standard.String; Ecosystem : Standard.String; Name : Standard.String; License : Standard.String; Version : Standard.String; Website : Standard.String)

> Store a registry-metadata result on disk (overwrites any existing entry for the ecosystem/package pair).

| Parameter | Description |
|-----------|-------------|
| `Ecosystem` | PURL type. |
| `License` | Licence string (may be empty). |
| `Name` | Package name. |
| `Target` | Project directory the package belongs to. |
| `Version` | Version string (may be empty). |
| `Website` | Website string (may be empty). |

### procedure Put_Probe (Tool : Standard.String; Fingerprint : Standard.String; Value : Standard.String)

> Store a system-tool version probe result on disk (overwrites any existing entry for the tool). Fingerprint is the identity of the binary the version was probed from; Get_Probe serves the answer only while the fingerprint matches.

| Parameter | Description |
|-----------|-------------|
| `Fingerprint` | Binary identity image. |
| `Tool` | Tool name (safe characters only). |
| `Value` | Version string (may be empty). |

### procedure Reset_Process_Stamps

> Forget every in-process stamp (the path -> digest map that dies with the run anyway). The next Hash_File re-validates each file against the persistent stat-stamp store or re-hashes it. Meant for tests and diagnostics -- and for long-lived processes (the --serve dashboard) that want a later assessment in the same process to re-walk files as a fresh run would.

### procedure Set_Cache_Dir (Dir : Standard.String)

> Override the cache root used by Store/Load/Exists/Evict. The default is Default_Cache_Dir at elaboration. Call this to honour --cache-dir.

| Parameter | Description |
|-----------|-------------|
| `Dir` | New cache root directory (need not end in a separator). |

### procedure Set_Cache_Expiry (Days : Standard.Natural)

> Set the entry lifetime in days. Default_Expiry_Days applies until this is called; zero means entries never expire. A load older than the lifetime is a miss and removes the entry.

| Parameter | Description |
|-----------|-------------|
| `Days` | Entry lifetime in days (0 = never expire). |

### procedure Set_Cache_Policy (Max_Entries : Standard.Positive)

> Configure the eviction cap used by Put_Cached. Defaults to 4096.

| Parameter | Description |
|-----------|-------------|
| `Max_Entries` | Soft cap on retained cache entries. |

### procedure Store (Key : Standard.String; Data : Standard.String; Success : Standard.Boolean)

> Store a blob under Key (the 64-char hex digest). Parent directories are created as needed under the configured cache root. Overwrites any existing entry for the same key.

| Parameter | Description |
|-----------|-------------|
| `Data` | Blob payload. |
| `Key` | Cache key (64-char hex digest). |
| `Success` | True if the blob was written. |
