# Adacovex.VCS

Version-control-system abstraction for differential modes.
--compare-base and --coverage-delta need a snapshot of a base revision
without disturbing the working tree.  Legacy codebases may live in
Mercurial, Subversion, Fossil, or jj rather than git, so the snapshot
operations are dispatched per VCS here:

  git    - ``git worktree add --detach`` in a linked worktree
hg     - ``hg archive -r REF DIR`` (pure export, no working-copy change)
svn    - ``svn info --show-item url`` + ``svn export -r REF URL DIR``
fossil - copy the repo DB and ``fossil open`` it at REF in a scratch dir
jj     - ``jj git export`` into the internal git store, then a git
worktree add against .jj/repo/store/git (jj commits ARE git
commits, so any change/commit id resolves)

Detection is marker-file based (.git / .jj / .hg / .svn / .fslckout /
- FOSSIL*), with a command probe fallback when no marker is present.
Runs only on Linux/WSL (uses sh -c for CWD-dependent tools like fossil).
HLR-DIFF: VCS abstraction for differential assessment

**See also:** [VCS support](../vcs.md)

> **Note:** All items in this package are public.

## Types

### type VCS_Kind

```ada
type VCS_Kind is (Unknown, Git, Mercurial, Subversion, Fossil, Jujutsu);
```

## Functions

### function Detect (Target_Dir : Standard.String) return Adacovex.VCS.VCS_Kind

| Parameter | Description |
|-----------|-------------|
| `Target_Dir` | Directory to inspect. |

**Returns:** Detected VCS kind (Unknown when none is found).

### function Is_Managed (Target_Dir : Standard.String) return Standard.Boolean

| Parameter | Description |
|-----------|-------------|
| `Target_Dir` | Directory to inspect. |

**Returns:** True when a supported VCS is detected.

### function To_String (Kind : Adacovex.VCS.VCS_Kind) return Standard.String `[Post]` `[Global]` `[SPARK]`

| Parameter | Description |
|-----------|-------------|
| `Kind` | VCS kind. |

**Returns:** Lowercase display name ("" for Unknown).

### function Tool_Name (Kind : Adacovex.VCS.VCS_Kind) return Standard.String `[Post]` `[Global]` `[SPARK]`

| Parameter | Description |
|-----------|-------------|
| `Kind` | VCS kind. |

**Returns:** Tool binary name ("" for Unknown).

### function UX_Note (Kind : Adacovex.VCS.VCS_Kind) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `Kind` | VCS kind. |

**Returns:** Recommendation text ("" when no note is needed).

## Procedures

### procedure Make_Snapshot (Target_Dir : Standard.String; Kind : Adacovex.VCS.VCS_Kind; Base_Ref : Standard.String; Tmp_Path : Standard.String; Tmp_Len : Standard.Natural; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Base_Ref` | Revision to snapshot (branch/commit/rev/tag). |
| `Kind` | Detected VCS kind (from Detect). |
| `Success` | True when the snapshot was created. |
| `Target_Dir` | Root of the target repository. |
| `Tmp_Len` | Length of the snapshot path on success. |
| `Tmp_Path` | Output buffer receiving the snapshot path. |

### procedure Remove_Snapshot (Target_Dir : Standard.String; Kind : Adacovex.VCS.VCS_Kind; Tmp_Path : Standard.String)

| Parameter | Description |
|-----------|-------------|
| `Kind` | VCS kind the snapshot was created with. |
| `Target_Dir` | Root of the target repository. |
| `Tmp_Path` | Snapshot directory to remove. |
