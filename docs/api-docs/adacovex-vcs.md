# Adacovex.VCS

Version-control-system abstraction for differential modes.
--compare-base and --coverage-delta need a snapshot of a base revision
without disturbing the working tree. Legacy codebases can live in
Mercurial, Subversion, Fossil, or jj rather than git. The snapshot
operations are dispatched per VCS here:

  git    - ``git worktree add --detach`` in a linked worktree
hg     - ``hg archive -r REF DIR`` (pure export, no working-copy change)
svn    - ``svn info --show-item url`` + ``svn export -r REF URL DIR``
fossil - copy the repo DB and ``fossil open`` it at REF in a scratch dir
jj     - ``jj git export`` into the internal git store, then a git
worktree add against .jj/repo/store/git (jj commits ARE git
commits, and any change or commit id resolves)

Detection is marker-file based (.git / .jj / .hg / .svn / .fslckout /
- FOSSIL*), with a command probe fallback when no marker is present.
The command lines run through the host shell: ``sh -c`` on POSIX hosts
and ``cmd /c`` on native Windows, so a CWD-dependent tool (fossil open,
svn export) can be driven with a change-directory prefix without
changing the process directory.
HLR-DIFF: VCS abstraction for differential assessment

**See also:** [VCS support](../usage/vcs.md)

> **Note:** All items in this package are public.

## Types

### type Shell_Family

```ada
type Shell_Family is (POSIX_Shell, CMD_Shell);
```

### type VCS_Kind

```ada
type VCS_Kind is (Unknown, Git, Mercurial, Subversion, Fossil, Jujutsu);
```

## Functions

### function Change_Dir_Prefix (S : Adacovex.VCS.Shell_Family; Dir : Standard.String) return Standard.String `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Dir` | Directory the command should run in. |
| `S` | Shell family that will read the command line. |

**Returns:** The prefix ending in " && ".

### function Detect (Target_Dir : Standard.String) return Adacovex.VCS.VCS_Kind

| Parameter | Description |
|-----------|-------------|
| `Target_Dir` | Directory to inspect. |

**Returns:** Detected VCS kind (Unknown when none is found).

### function Host_Shell return Adacovex.VCS.Shell_Family `[Global]`

**Returns:** CMD_Shell on Windows, POSIX_Shell everywhere else.

### function Is_Managed (Target_Dir : Standard.String) return Standard.Boolean

| Parameter | Description |
|-----------|-------------|
| `Target_Dir` | Directory to inspect. |

**Returns:** True when a supported VCS is detected.

### function Null_Device (S : Adacovex.VCS.Shell_Family) return Standard.String `[Global]`

| Parameter | Description |
|-----------|-------------|
| `S` | Shell family of the host. |

**Returns:** The discard device path.

### function Quote_Path (S : Adacovex.VCS.Shell_Family; Path : Standard.String) return Standard.String `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Path` | Path to quote. |
| `S` | Shell family that will read the command line. |

**Returns:** The quoted path.

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

### function UX_Note (Kind : Adacovex.VCS.VCS_Kind) return Standard.String `[Post]` `[Global]` `[SPARK]`

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
