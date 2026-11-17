# Adacovex.Paths

The host platform family, as far as directory conventions go. Linux
stands for every POSIX host that follows the XDG base directory
specification (Linux, the BSDs, and other Unix systems).

> **Note:** All items in this package are public.

## Types

### type Platform_Kind

```ada
type Platform_Kind is (Platform_Linux, Platform_MacOS, Platform_Windows);
```

> The host platform family, as far as directory conventions go. Linux stands for every POSIX host that follows the XDG base directory specification (Linux, the BSDs, and other Unix systems).

## Functions

### function Cache_Base (P : Adacovex.Paths.Platform_Kind; Home : Standard.String; Xdg_Cache : Standard.String; Local_App_Data : Standard.String) return Standard.String `[Global]`

> The platform cache base directory for a third-party application: $XDG_CACHE_HOME (or ~/.cache) on Linux and the BSDs, ~/Library/Caches on macOS, and %LOCALAPPDATA% on Windows. Every input is a parameter, so the tests exercise all three platform rules on any host.

| Parameter | Description |
|-----------|-------------|
| `Home` | User home directory. |
| `Local_App_Data` | %LOCALAPPDATA% ("" when unset). |
| `P` | Platform family. |
| `Xdg_Cache` | $XDG_CACHE_HOME ("" when unset). |

**Returns:** The cache base directory.

### function Cache_Directory (P : Adacovex.Paths.Platform_Kind; Home : Standard.String; Xdg_Cache : Standard.String; Local_App_Data : Standard.String) return Standard.String `[Global]`

> The adacovex cache directory for a platform: the result cache, the persistent stat-stamp store, and the system-tool probe store.

| Parameter | Description |
|-----------|-------------|
| `Home` | User home directory. |
| `Local_App_Data` | %LOCALAPPDATA% ("" when unset). |
| `P` | Platform family. |
| `Xdg_Cache` | $XDG_CACHE_HOME ("" when unset). |

**Returns:** The cache directory.

### function Cache_Home return Standard.String

> Cache_Base for the host, read from the environment.

**Returns:** The host's cache base directory.

### function Cache_Root return Standard.String

> The cache directory for the host, read from the environment: $ADACOVEX_STATE_HOME/cache when it is set, otherwise Cache_Directory for the detected platform.

**Returns:** The cache directory in use.

### function Config_Directory (P : Adacovex.Paths.Platform_Kind; Home : Standard.String; Xdg_Config : Standard.String; App_Data : Standard.String) return Standard.String `[Global]`

> The adacovex configuration directory for a platform: where adacovex.toml lives. Every input is a parameter, so the tests exercise all three platform rules on any host.

| Parameter | Description |
|-----------|-------------|
| `App_Data` | %APPDATA% ("" when unset). |
| `Home` | User home directory. |
| `P` | Platform family. |
| `Xdg_Config` | $XDG_CONFIG_HOME ("" when unset). |

**Returns:** The configuration directory.

### function Config_Root return Standard.String

> The configuration directory for the host, read from the environment: $ADACOVEX_STATE_HOME when it is set (the documented override for tests and CI; it is distinct from the installer's ADACOVEX_HOME, which names a binary prefix), otherwise Config_Directory for the detected platform.

**Returns:** The configuration directory in use.

### function Data_Base (P : Adacovex.Paths.Platform_Kind; Home : Standard.String; Xdg_Data : Standard.String; App_Data : Standard.String; Local_App_Data : Standard.String) return Standard.String `[Global]`

> The platform data base directory for a third-party application: the directory under which that tool keeps its data. Linux and the BSDs use $XDG_DATA_HOME (or ~/.local/share), macOS uses ~/Library/Application Support, and Windows uses %APPDATA% (then %LOCALAPPDATA%). Every input is a parameter, so the tests exercise all three platform rules on any host.

| Parameter | Description |
|-----------|-------------|
| `App_Data` | %APPDATA% ("" when unset). |
| `Home` | User home directory. |
| `Local_App_Data` | %LOCALAPPDATA% ("" when unset). |
| `P` | Platform family. |
| `Xdg_Data` | $XDG_DATA_HOME ("" when unset). |

**Returns:** The data base directory.

### function Data_Directory (P : Adacovex.Paths.Platform_Kind; Home : Standard.String; Xdg_Data : Standard.String; Local_App_Data : Standard.String) return Standard.String `[Global]`

> The adacovex data directory for a platform: the toolchain cache and the machine-local registry-metadata store.

| Parameter | Description |
|-----------|-------------|
| `Home` | User home directory. |
| `Local_App_Data` | %LOCALAPPDATA% ("" when unset). |
| `P` | Platform family. |
| `Xdg_Data` | $XDG_DATA_HOME ("" when unset). |

**Returns:** The data directory.

### function Data_Home return Standard.String

> Data_Base for the host, read from the environment. A tool that keeps its own state directory (tealdeer, or the man page installer) builds on this, so every such path follows one platform rule.

**Returns:** The host's data base directory.

### function Data_Root return Standard.String

> The data directory for the host, read from the environment: $ADACOVEX_STATE_HOME/data when it is set, otherwise Data_Directory for the detected platform.

**Returns:** The data directory in use.

### function Detect_Platform return Adacovex.Paths.Platform_Kind `[Global]`

> Detect the host platform at run time. Windows is recognised by the directory-separator convention (the one compile-time fact that distinguishes it), macOS by the existence of /System/Library/CoreServices (a macOS-only directory), and everything else is treated as XDG.

**Returns:** The host platform family.

### function Display (Path : Standard.String) return Standard.String `[Post]` `[Global]`

> Present Path for printed output. On a host whose native separator is '\' every '\' becomes '/'; on a POSIX host both characters stay as they are, because '\' is then an ordinary file-name character. The result keeps Path's length, so a display row never shifts a column. CLI output (status rows, complexity tables, parser diagnostics) runs every printed path through it, so one report never mixes separators.

| Parameter | Description |
|-----------|-------------|
| `Path` | Path to present. |

**Returns:** Path in the host's display separator style. @post Result'Length = Path'Length.

### function Executable_Name (Name : Standard.String) return Standard.String `[Global]`

> Name with the host executable suffix appended when it is missing ("gnatprove" becomes "gnatprove.exe" on Windows, and is unchanged on POSIX). A name that already carries the suffix is returned unchanged.

| Parameter | Description |
|-----------|-------------|
| `Name` | Executable name or path. |

**Returns:** Name with the host executable suffix.

### function Executable_Suffix return Standard.String

> The host executable suffix, ".exe" on Windows and "" elsewhere. Ada.Directories never guesses an extension, so a unit that tests or spawns a binary by name must append this suffix itself.

**Returns:** The host executable suffix.

### function Expand_User (Path : Standard.String) return Standard.String `[Global]`

> Expand a leading '~' to Home_Directory. The accepted forms are "~" and "~/rest" (also "~\rest" on Windows); a "~user" form is returned unchanged, because only the shell can resolve another user's home. A tilde not in leading position is returned unchanged. Home_Directory already falls back to the temp directory, so the result is always usable instead of a literal "~".

| Parameter | Description |
|-----------|-------------|
| `Path` | Candidate path. |

**Returns:** Path with a leading '~' expanded.

### function Home_Directory return Standard.String `[Global]` `[SPARK]`

> Home directory of the current user. It reads HOME first (POSIX and most Windows shells), then USERPROFILE (the native Windows variable a bare cmd.exe sets), and falls back to the system temp directory. The runtime Ada.Environment_Variables subprograms carry no Global contracts, so gnatprove 16 emits [assumed-global-null] warnings at each call; the body scopes a Warnings pragma over exactly those calls (the Adacovex.CPUs idiom).

**Returns:** The user's home directory (the temp directory as a last resort).

### function Is_Absolute (Path : Standard.String) return Standard.Boolean `[Global]`

> Whether Path is absolute. True for a leading '/' or '\' (a POSIX root or a Windows root-relative path), a Windows drive-letter prefix such as "C:" or "C:\", and a Windows UNC prefix ("\\server" or "//server"). False for an empty path and for any other relative path.

| Parameter | Description |
|-----------|-------------|
| `Path` | Candidate path. |

**Returns:** True when Path is absolute.

### function Is_Separator (C : Standard.Character) return Standard.Boolean `[Post]` `[Global]`

> Whether C separates path components on any supported host. Both '/' (POSIX and Windows) and '\' (Windows only) are separators.

| Parameter | Description |
|-----------|-------------|
| `C` | Candidate character. |

**Returns:** True when C is a path separator. @post Result is True exactly when C is '/' or '\'.

### function Join (Dir : Standard.String; Name : Standard.String) return Standard.String `[Post]` `[Global]`

> Join Dir and Name with exactly one separator between them. Dir's trailing separators are trimmed first, so "/a/" and "/a" both join to "/a/Name". Returns Name when Dir is empty and Dir when Name is empty. '/' is used as the joining separator, which Windows accepts as well.

| Parameter | Description |
|-----------|-------------|
| `Dir` | Directory part. |
| `Name` | Entry name part. |

**Returns:** The joined path.

### function Strip_Trailing_Separators (Path : Standard.String) return Standard.String `[Post]` `[Global]`

> Strip every trailing path separator from Path. A lone root ("/" or "\") is kept intact, and an empty Path is returned unchanged.

| Parameter | Description |
|-----------|-------------|
| `Path` | Candidate path. |

**Returns:** Path without trailing separators. @post Result'Length <= Path'Length.
