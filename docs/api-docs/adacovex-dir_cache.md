# Adacovex.Dir_Cache

Shared per-process directory-snapshot memo.

Every adacovex assessment walks the target tree several times: the
source scanner, the SBOM tools-key hash, the graph-key language probe,
the vendored discovery and hash walks, the GPR collection walk, and the
complexity checker. Each walk re-enumerated the same directories and
re-stat'ed every entry (Ada.Directories' Kind on an entry costs one
stat), so a warm run paid the enumeration cost five times over --
measured at 11 stats per source file on the self-audit tree.

This package is the single shared snapshot those walkers consult. The
first walker to touch a directory enumerates it once, records every
entry's (name, kind), and stamps the record with the directory's mtime;
every later walker in the same process serves the snapshot after one
mtime stat validates it. This is the same shape a language server's
indexed file set takes: one authoritative view of the workspace that
every subsystem reads, invalidated from cheap stat probes rather than
re-enumerated from scratch.

Correctness rules:
- a snapshot is served only when the directory's mtime is unchanged
since it was taken (entries added or removed change the mtime);
- a directory with more than Max_Dir_Entries entries is never memoised
-- the caller falls back to direct enumeration, so large vendor
trees behave exactly as before;
- the memo lives for one process only (an adacovex run, a test, a
serve session) and is never written to disk.

The memo is bounded: at most Memo_Slots directories are remembered;
beyond that, lookups miss and the caller enumerates directly.

Cache-friendliness: a slot's metadata (path, mtime, count) sits in its
first cache lines and the entry array follows, so a hit touches the
metadata first. An entry is packed to 66 bytes (a 64-byte name, a
one-byte length, and a one-byte kind) rather than the 128 bytes the
v1.61.0 profile recorded, and the memo key is capped at 128 bytes
instead of 256. Max_Dir_Entries is 128 because the self-audit tree's
two densest scanned directories hold 84 and 78 entries: a cap of 64
rejected both and made every walker re-enumerate them.

> **Note:** All items in this package are public.

## Types

### type Dir_Entry_List

```ada
type Dir_Entry_List is array (1 .. Max_Dir_Entries) of Dir_Entry_Rec;
```

### type Dir_Entry_Rec

```ada
type Dir_Entry_Rec is record
Name     : String (1 .. Max_Name_Len) := (others => ' ');
Name_Len : Name_Length := 0;
Kind     : Entry_Kind := K_Other;
end record;
```

### type Entry_Kind

```ada
type Entry_Kind is (K_File, K_Dir, K_Other);
```

### type Name_Length

```ada
subtype Name_Length is Natural range 0 .. Max_Name_Len;
```

## Functions

### function Is_Directory (K : Adacovex.Dir_Cache.Entry_Kind) return Standard.Boolean

| Parameter | Description |
|-----------|-------------|
| `K` | Entry classification. |

**Returns:** True when K is K_Dir.

## Procedures

### procedure Reset

### procedure Snapshot (Dir : Standard.String; Entries : Adacovex.Dir_Cache.Dir_Entry_List; Count : Standard.Natural; Truncated : Standard.Boolean; OK : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Count` | Number of valid entries written to Entries. |
| `Dir` | Directory to enumerate (absolute or relative). |
| `Entries` | Output array of remembered entries. |
| `OK` | False when the directory could not be read. |
| `Truncated` | True when the caller must re-enumerate directly. |
