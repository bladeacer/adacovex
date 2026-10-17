# Adacovex.Renderers.Man

Man-page renderer and installer.
Generates a roff (man 1) page for adacovex and installs it into a local
man root, so ``man adacovex`` works without root. The page embeds the
bundled binary version (in the .TH header and a VERSION section).
``adacovex man --check`` can detect that a newer man page is available than
the one on disk. A shell prompt hook can also detect this.

The installer follows the host's man reader. GNU/Linux distributions use
man-db (https://man-db.gitlab.io/man-db/), and macOS and the BSDs use
mandoc (https://mandoc.bsd.lv/); both readers also run on WSL and on
Cygwin, MSYS2, and Git Bash. A user-level man root is only searched when
it is on the reader's man path, so the installer prefers a writable
``MANPATH`` entry, otherwise the platform data root, and reports when that
root is not on the man path.

The install root is ``$MANPATH``'s first home-owned entry when one exists,
otherwise ``<data home>/man``: ``$XDG_DATA_HOME/man`` (or
``~/.local/share/man``) on Linux and the BSDs, ``~/Library/Application
Support/man`` on macOS, and ``%APPDATA%\man`` on Windows. The man database
refreshes with ``mandb`` (man-db) and falls back to ``makewhatis`` (mandoc).

> **Note:** All items in this package are public.

## Types

### type Database_Tool

```ada
type Database_Tool is (No_Tool, Man_DB, Makewhatis);
```

## Functions

### function Default_Dir return Standard.String

**Returns:** Default man root directory path.

### function Installed_Version (Man_Root : Standard.String) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `Man_Root` | Man root directory to inspect. |

**Returns:** Installed page version (for example "1.10.0") or "".

### function Manpath_Contains (Manpath_Text : Standard.String; Man_Root : Standard.String) return Standard.Boolean

| Parameter | Description |
|-----------|-------------|
| `Man_Root` | Man root to look for. |
| `Manpath_Text` | A man path list (from $MANPATH or `manpath`). |

**Returns:** True when the root is one of the entries.

### function Manpath_User_Entry (Manpath_Text : Standard.String; Home : Standard.String) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `Home` | User home directory. |
| `Manpath_Text` | A man path list (from $MANPATH or `manpath`). |

**Returns:** The entry (no trailing slash), or "" when none lies under Home.

### function Render_Page (Version : Standard.String) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `Version` | adacovex version (for example "1.10.0"). |

**Returns:** Complete man-page source (roff format).

### function Root_On_Manpath (Man_Root : Standard.String) return Standard.Boolean

| Parameter | Description |
|-----------|-------------|
| `Man_Root` | Man root to look for. |

**Returns:** True when the root is searched, or cannot be determined.

### function Update_Database (Man_Root : Standard.String) return Standard.Boolean

| Parameter | Description |
|-----------|-------------|
| `Man_Root` | Man root directory to index. |

**Returns:** True when the man database was refreshed.

### function Update_Database (Man_Root : Standard.String; Tool : Adacovex.Renderers.Man.Database_Tool) return Standard.Boolean

| Parameter | Description |
|-----------|-------------|
| `Man_Root` | Man root directory to index. |
| `Tool` | Indexer that refreshed the database (No_Tool on failure). |

**Returns:** True when the man database was refreshed.

## Procedures

### procedure Install (Man_Root : Standard.String; Version : Standard.String; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Man_Root` | Man root directory (contains man1/). |
| `Success` | True when the page was written. False on I/O failure. |
| `Version` | adacovex version embedded in the page. |
