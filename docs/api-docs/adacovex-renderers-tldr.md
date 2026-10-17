# Adacovex.Renderers.Tldr

tldr page installer.
Installs the bundled tldr page (``docs/tldr/adacovex.md``, embedded at
build time by tools/gen-tldr.py) into the local tldr client, so
``tldr adacovex`` works offline. The installer is client agnostic: it
detects the installed client first, then writes to that client's own
page location.

tealdeer reads a flat custom-pages directory (``adacovex.page.md``), which
sits outside its cache, so ``tldr --update`` cannot remove the page. A
client that follows CLIENT-SPECIFICATION.md reads its extracted cache
pages tree instead (``pages/common/adacovex.md`` plus the platform
directory), and the page survives a cache update because the update
overlays the archive without deleting extra files.

``adacovex tldr`` installs or refreshes the page. ``adacovex tldr --check``
exits 0 when the installed page matches the bundled one, and 1 when it
is missing or stale, so a shell prompt hook can keep it fresh after a
``tldr --update``.

HLR-TLDR: Client-agnostic tldr page installation

> **Note:** All items in this package are public.

## Types

### type Client_Kind

```ada
type Client_Kind is (No_Client, Base_Client, Tealdeer, Unsupported_Client);
```

## Functions

### function Cache_Home return Standard.String

**Returns:** Cache home path.

### function Classify (Version_Output : Standard.String) return Adacovex.Renderers.Tldr.Client_Kind

| Parameter | Description |
|-----------|-------------|
| `Version_Output` | Captured stdout of `tldr --version`. |

**Returns:** The detected client family.

### function Client_Name (Kind : Adacovex.Renderers.Tldr.Client_Kind) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `Kind` | Client family. |

**Returns:** Display name (for example "tealdeer").

### function Custom_Pages_Dir (Show_Paths_Output : Standard.String) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `Show_Paths_Output` | Captured stdout of `tldr --show-paths`. |

**Returns:** The directory (no trailing slash), or "" when absent.

### function Data_Home return Standard.String

**Returns:** Data home path.

### function Default_Pages_Dir (Kind : Adacovex.Renderers.Tldr.Client_Kind; Data_Home : Standard.String; Cache_Home : Standard.String) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `Cache_Home` | XDG cache home (for example ~/.cache). |
| `Data_Home` | XDG data home (for example ~/.local/share). |
| `Kind` | Client family. |

**Returns:** Page directory, or "" for a family with no page directory.

### function Installed (Kind : Adacovex.Renderers.Tldr.Client_Kind; Pages_Dir : Standard.String) return Standard.Boolean

| Parameter | Description |
|-----------|-------------|
| `Kind` | Client family. |
| `Pages_Dir` | Page directory (see Default_Pages_Dir). |

**Returns:** True when the primary page file equals Page.

### function Page return Standard.String

**Returns:** The page text.

### function Page_File (Kind : Adacovex.Renderers.Tldr.Client_Kind; Pages_Dir : Standard.String) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `Kind` | Client family. |
| `Pages_Dir` | Page directory (see Default_Pages_Dir). |

**Returns:** Page file path, or "" for a family with no page file.

### function Platform_From_System (System_Name : Standard.String) return Standard.String

| Parameter | Description |
|-----------|-------------|
| `System_Name` | Output of `uname -s` (for example "Linux"). |

**Returns:** Page directory name, or "" when the system is not known.

### function Platform_Page_Dir return Standard.String

**Returns:** Directory name, or "" when the system is not known.

## Procedures

### procedure Detect (Kind : Adacovex.Renderers.Tldr.Client_Kind; Pages_Dir : Standard.String; Pages_Len : Standard.Natural) `[Pre]`

| Parameter | Description |
|-----------|-------------|
| `Kind` | Detected client family. |
| `Pages_Dir` | Buffer that receives the page directory. |
| `Pages_Len` | Length of the page directory in Pages_Dir. |

### procedure Install (Kind : Adacovex.Renderers.Tldr.Client_Kind; Pages_Dir : Standard.String; Success : Standard.Boolean)

| Parameter | Description |
|-----------|-------------|
| `Kind` | Client family. |
| `Pages_Dir` | Page directory (see Default_Pages_Dir). |
| `Success` | True when every page file was written. |
