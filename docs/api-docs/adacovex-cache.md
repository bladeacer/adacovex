# Adacovex.Cache

Content-addressed result cache for adacovex.
Stores arbitrary small blobs keyed by the SHA-256 of their *input* (a source
file's contents, a gnatprove.out, a test-result file, ...).  Because the key
is derived from the inputs, an unchanged input always hits the same cache
entry, so re-running adacovex on unchanged code serves results straight
from disk -- no re-scan, no re-parse, and (for gnatprove) no re-proof.

The store is split per input: every analyzed unit is cached under its own
key, so a one-line change only invalidates that unit's entry and rewrites a
single tiny blob; every other unit is served from cache unchanged.

Storage is a two-level directory tree (<cache>/<aa>/<aabb...>) so a large
project never creates a single directory with millions of entries.  Entries
are evicted oldest-first once the count exceeds a soft cap, keeping disk
usage bounded without external dependencies (pure GNAT runtime only).
HLR-CACHE: Result caching

**See also:** [Architecture -- result caching](../architecture.md#result-caching)

> **Note:** All items in this package are public.

## Functions

### function Exists (Key : Standard.String) return Standard.Boolean

| Parameter | Description |
|-----------|-------------|
| `Key` | Cache key. |

**Returns:** True if the entry is present.

### function Hash_File (Path : Standard.String) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `Path` | File to hash. |

**Returns:** 64-character lowercase hex digest, or "" on error.

### function Hash_String (S : Standard.String) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `S` | String to hash. |

**Returns:** 64-character lowercase hex digest.

## Procedures

### procedure Cache_Dir (Dir : Standard.String; Len : Standard.Natural)

| Parameter | Description |
|-----------|-------------|
| `Dir` | Output buffer for the directory path. |
| `Len` | Length of the written path. |

### procedure Default_Cache_Dir (Dir : Standard.String; Len : Standard.Natural)

| Parameter | Description |
|-----------|-------------|
| `Dir` | Output buffer for the directory path. |
| `Len` | Length of the written path. |

### procedure Evict_If_Needed (Max_Entries : Standard.Positive)

| Parameter | Description |
|-----------|-------------|
| `Max_Entries` | Soft cap on retained entries. |

### procedure Get_Cached (Key : Standard.String; Data : Standard.String; Len : Standard.Natural; Found : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Data` | Output buffer for the blob. |
| `Found` | True when the entry existed and fit in Data. |
| `Key` | Cache key. |
| `Len` | Length of the loaded blob. |

### procedure Get_Probe (Tool : Standard.String; Value : Standard.String; Val_Len : Standard.Natural; Found : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Found` | True when a fresh probe existed. |
| `Tool` | Tool name (safe characters only). |
| `Val_Len` | Length of the version string. |
| `Value` | Output version string (may be empty). |

### procedure Load (Key : Standard.String; Data : Standard.String; Len : Standard.Natural; Found : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Data` | Output buffer for the blob (up to Max_Cache_Blob bytes). |
| `Found` | True when the entry existed and fit in Data. |
| `Key` | Cache key (64-char hex digest). |
| `Len` | Length of the loaded blob. |

### procedure Put_Cached (Key : Standard.String; Data : Standard.String; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Data` | Blob payload. |
| `Key` | Cache key. |
| `Success` | True if the blob was written. |

### procedure Put_Probe (Tool : Standard.String; Value : Standard.String)

| Parameter | Description |
|-----------|-------------|
| `Tool` | Tool name (safe characters only). |
| `Value` | Version string (may be empty). |

### procedure Set_Cache_Dir (Dir : Standard.String)

| Parameter | Description |
|-----------|-------------|
| `Dir` | New cache root directory (need not end in a separator). |

### procedure Set_Cache_Policy (Max_Entries : Standard.Positive)

| Parameter | Description |
|-----------|-------------|
| `Max_Entries` | Soft cap on retained cache entries. |

### procedure Store (Key : Standard.String; Data : Standard.String; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Data` | Blob payload. |
| `Key` | Cache key (64-char hex digest). |
| `Success` | True if the blob was written. |
