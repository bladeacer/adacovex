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

> The command shell a differential mode drives on the running host. POSIX_Shell is `sh` (Linux, the BSDs, macOS, WSL, Cygwin, MSYS2, and Git Bash). CMD_Shell is `cmd.exe`, so native Windows runs the same differential modes with no POSIX layer installed. The choice follows the host path separator, the same compile-time fact the executable suffix and the temp-directory rules use.

### type VCS_Kind

```ada
type VCS_Kind is (Unknown, Git, Mercurial, Subversion, Fossil, Jujutsu);
```

> The version-control system that owns the target directory. Unknown means no marker file and no command probe identified one.

## Functions

### function Change_Dir_Prefix (S : Adacovex.VCS.Shell_Family; Dir : Standard.String) return Standard.String `[Global]`

> The prefix that runs a command in Dir without changing the process directory. Both shells accept a trailing `&& `, so the caller appends its command to the result. CMD_Shell carries `/d`, so a drive change works as well as a directory change.

| Parameter | Description |
|-----------|-------------|
| `Dir` | Directory the command should run in. |
| `S` | Shell family that will read the command line. |

**Returns:** The prefix ending in " && ".

### function Detect (Target_Dir : Standard.String) return Adacovex.VCS.VCS_Kind

> Detect the VCS managing Target_Dir. Marker files take priority (deterministic, no subprocesses). When no marker is present, the VCS command-line tools are probed. Git wins over jj for colocated repos (git interop is exact there).

| Parameter | Description |
|-----------|-------------|
| `Target_Dir` | Directory to inspect. |

**Returns:** Detected VCS kind (Unknown when none is found).

### function Host_Shell return Adacovex.VCS.Shell_Family `[Global]`

> The shell family of the running host.

**Returns:** CMD_Shell on Windows, POSIX_Shell everywhere else.

### function Is_Managed (Target_Dir : Standard.String) return Standard.Boolean

> Whether Target_Dir is managed by any supported VCS.

| Parameter | Description |
|-----------|-------------|
| `Target_Dir` | Directory to inspect. |

**Returns:** True when a supported VCS is detected.

### function Null_Device (S : Adacovex.VCS.Shell_Family) return Standard.String `[Global]`

> The device a shell sends discarded output to: /dev/null on POSIX hosts and NUL on Windows. The caller passes it as the output file of a spawned command.

| Parameter | Description |
|-----------|-------------|
| `S` | Shell family of the host. |

**Returns:** The discard device path.

### function Quote_Path (S : Adacovex.VCS.Shell_Family; Path : Standard.String) return Standard.String `[Global]`

> Quote a path so the given shell reads it as one argument. POSIX_Shell quotes with single quotes; CMD_Shell quotes with double quotes (a single quote is a plain character for cmd.exe).

| Parameter | Description |
|-----------|-------------|
| `Path` | Path to quote. |
| `S` | Shell family that will read the command line. |

**Returns:** The quoted path.

### function To_String (Kind : Adacovex.VCS.VCS_Kind) return Standard.String `[Post]` `[Global]` `[SPARK]`

> Human-readable name of a VCS kind ("git", "mercurial", and more).

| Parameter | Description |
|-----------|-------------|
| `Kind` | VCS kind. |

**Returns:** Lowercase display name ("" for Unknown).

### function Tool_Name (Kind : Adacovex.VCS.VCS_Kind) return Standard.String `[Post]` `[Global]` `[SPARK]`

> Command-line tool binary that drives a VCS kind ("git", "hg", "svn", "fossil", "jj"), or "" for Unknown. `adacovex status` uses it to report which VCS tools are available on PATH for the differential modes.

| Parameter | Description |
|-----------|-------------|
| `Kind` | VCS kind. |

**Returns:** Tool binary name ("" for Unknown).

### function UX_Note (Kind : Adacovex.VCS.VCS_Kind) return Standard.String `[Post]` `[Global]` `[SPARK]`

> UX guidance for a VCS kind. "" means a fully supported VCS. For legacy VCS whose snapshot UX is poor, the note recommends that the developers convert the repository to git (or a git-compatible VCS). Subversion has no local history and is network-dependent. Fossil has niche tooling.

| Parameter | Description |
|-----------|-------------|
| `Kind` | VCS kind. |

**Returns:** Recommendation text ("" when no note is needed).

## Procedures

### procedure Make_Snapshot (Target_Dir : Standard.String; Kind : Adacovex.VCS.VCS_Kind; Base_Ref : Standard.String; Tmp_Path : Standard.String; Tmp_Len : Standard.Natural; Success : Standard.Boolean)

> Snapshot Base_Ref of the Target_Dir repository into a temporary directory (Tmp_Path), without touching the working tree. The temp path is /tmp/adacovex-diff-<pid> (Linux/WSL). On failure Tmp_Len is 0. A stale snapshot at the same path is removed first.

| Parameter | Description |
|-----------|-------------|
| `Base_Ref` | Revision to snapshot (branch/commit/rev/tag). |
| `Kind` | Detected VCS kind (from Detect). |
| `Success` | True when the snapshot was created. |
| `Target_Dir` | Root of the target repository. |
| `Tmp_Len` | Length of the snapshot path on success. |
| `Tmp_Path` | Output buffer receiving the snapshot path. |

### procedure Remove_Snapshot (Target_Dir : Standard.String; Kind : Adacovex.VCS.VCS_Kind; Tmp_Path : Standard.String)

> Remove a snapshot created by Make_Snapshot. Deregisters VCS worktrees (git/jj) and deletes the directory. Best effort. Failures are ignored.

| Parameter | Description |
|-----------|-------------|
| `Kind` | VCS kind the snapshot was created with. |
| `Target_Dir` | Root of the target repository. |
| `Tmp_Path` | Snapshot directory to remove. |
