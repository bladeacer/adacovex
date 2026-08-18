# Adacovex.Renderers.Man

Man-page renderer and installer.
Generates a roff (man 1) page for adacovex and installs it into the
local man database so ``man adacovex`` works without root.  The page
embeds the bundled binary version (in the .TH header and a VERSION
section) so ``adacovex man --check`` -- and a shell prompt hook -- can
detect that a newer man page is available than the one on disk.
Targets Linux and WSL: the default install root is
$XDG_DATA_HOME/man or ~/.local/share/man, and the database is updated
with ``mandb`` when it is present.

> **Note:** All items in this package are public.

## Functions

### function Default_Dir return Standard.String

**Returns:** Default man root directory path.

### function Installed_Version (Man_Root : Standard.String) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `Man_Root` | Man root directory to inspect. |

**Returns:** Installed page version (e.g. "1.10.0") or "".

### function Render_Page (Version : Standard.String) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `Version` | adacovex version (e.g. "1.10.0"). |

**Returns:** Complete man-page source (roff format).

### function Update_Database (Man_Root : Standard.String) return Standard.Boolean

| Parameter | Description |
|-----------|-------------|
| `Man_Root` | Man root directory to index. |

**Returns:** True when the man database was refreshed; False when mandb

## Procedures

### procedure Install (Man_Root : Standard.String; Version : Standard.String; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Man_Root` | Man root directory (contains man1/). |
| `Success` | True when the page was written; False on I/O failure. |
| `Version` | adacovex version embedded in the page. |
