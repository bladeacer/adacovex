# Adacovex_Cache_Tests

Unit tests for the result-cache layer (Adacovex.Cache): SHA-256 hashing
and the in-memory stamp fast path (Adacovex.Cache.Stamp_Hits /
Stamp_Misses), blob store/load/exists round trips, oldest-first
eviction under a bounded cap, and the system-tool probe and
registry-metadata stores.

> **Note:** All items in this package are public.

## Procedures

### procedure Run (R : Adacovex.Test_Support.Runner'Class)

| Parameter | Description |
|-----------|-------------|
| `R` |  |
