# Adacovex.Dir_Cache

Shared per-process directory-snapshot memo.

Every adacovex assessment walks the target tree several times: the
source scanner, the SBOM tools-key hash, the graph-key language probe,
the vendored discovery and hash walks, the GPR collection walk, and the
complexity checker.  Each walk re-enumerated the same directories and
re-stat'ed every entry (Ada.Directories' Kind on an entry costs one
stat), so a warm run paid the enumeration cost five times over --
measured at 11 stats per source file on the self-audit tree.

This package is the single shared snapshot those walkers consult.  The
first walker to touch a directory enumerates it once, records every
entry's (name, kind), and stamps the record with the directory's mtime;
every later walker in the same process serves the snapshot after one
mtime stat validates it.  This is the same shape a language server's
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

> **Note:** All items in this package are public.

## Types

### type Dir_Entry_List

```ada
type Dir_Entry_List is array (1 .. Max_Dir_Entries) of Dir_Entry_Rec;
```

### type Dir_Entry_Rec

```ada
type Dir_Entry_Rec is record
Name_Len : Natural := 0;
Name     : String (1 .. Max_Name_Len) := (others => ' ');
Kind     : Entry_Kind := K_Other;
end record;
```

### type Entry_Kind

```ada
type Entry_Kind is (K_File, K_Dir, K_Other);
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
| `Count` |  |
| `Dir` |  |
| `Entries` |  |
| `OK` |  |
| `Truncated` |  |
