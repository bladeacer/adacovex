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

## Functions

### function Cache_Directory (P : Adacovex.Paths.Platform_Kind; Home : Standard.String; Xdg_Cache : Standard.String; Local_App_Data : Standard.String) return Standard.String `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Home` | User home directory. |
| `Local_App_Data` | %LOCALAPPDATA% ("" when unset). |
| `P` | Platform family. |
| `Xdg_Cache` | $XDG_CACHE_HOME ("" when unset). |

**Returns:** The cache directory.

### function Cache_Root return Standard.String

**Returns:** The cache directory in use.

### function Config_Directory (P : Adacovex.Paths.Platform_Kind; Home : Standard.String; Xdg_Config : Standard.String; App_Data : Standard.String) return Standard.String `[Global]`

| Parameter | Description |
|-----------|-------------|
| `App_Data` | %APPDATA% ("" when unset). |
| `Home` | User home directory. |
| `P` | Platform family. |
| `Xdg_Config` | $XDG_CONFIG_HOME ("" when unset). |

**Returns:** The configuration directory.

### function Config_Root return Standard.String

**Returns:** The configuration directory in use.

### function Data_Directory (P : Adacovex.Paths.Platform_Kind; Home : Standard.String; Xdg_Data : Standard.String; Local_App_Data : Standard.String) return Standard.String `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Home` | User home directory. |
| `Local_App_Data` | %LOCALAPPDATA% ("" when unset). |
| `P` | Platform family. |
| `Xdg_Data` | $XDG_DATA_HOME ("" when unset). |

**Returns:** The data directory.

### function Data_Root return Standard.String

**Returns:** The data directory in use.

### function Detect_Platform return Adacovex.Paths.Platform_Kind `[Global]`

**Returns:** The host platform family.

### function Display (Path : Standard.String) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Path` | Path to present. |

**Returns:** Path in the host's display separator style.

### function Executable_Name (Name : Standard.String) return Standard.String `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Name` | Executable name or path. |

**Returns:** Name with the host executable suffix.

### function Executable_Suffix return Standard.String

**Returns:** The host executable suffix.

### function Expand_User (Path : Standard.String) return Standard.String `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Path` | Candidate path. |

**Returns:** Path with a leading '~' expanded.

### function Home_Directory return Standard.String `[Global]` `[SPARK]`

**Returns:** The user's home directory (the temp directory as a last

### function Is_Absolute (Path : Standard.String) return Standard.Boolean `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Path` | Candidate path. |

**Returns:** True when Path is absolute.

### function Is_Separator (C : Standard.Character) return Standard.Boolean `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `C` | Candidate character. |

**Returns:** True when C is a path separator.

### function Join (Dir : Standard.String; Name : Standard.String) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Dir` | Directory part. |
| `Name` | Entry name part. |

**Returns:** The joined path.

### function Strip_Trailing_Separators (Path : Standard.String) return Standard.String `[Post]` `[Global]`

| Parameter | Description |
|-----------|-------------|
| `Path` | Candidate path. |

**Returns:** Path without trailing separators.
