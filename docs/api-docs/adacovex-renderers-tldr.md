# Adacovex.Renderers.Tldr

tldr page installer.
Installs the bundled tldr page (``docs/tldr/adacovex.md``, embedded at
build time by tools/gen-tldr.py) into the local tldr client, so
``tldr adacovex`` works offline. The installer is client agnostic: it
detects the installed client first, then writes to that client's own
page location.

tealdeer reads a flat custom-pages directory (``adacovex.page.md``). The
directory follows the host's OS conventions, and ``tldr --show-paths``
reports it. The directory sits outside the cache, so ``tldr --update``
cannot remove the page. Upstream: https://docs.tealdeer.org/stable/usage_custom_pages.html

A client that follows CLIENT-SPECIFICATION.md reads its extracted cache
pages tree instead (``pages/common/adacovex.md`` plus the platform
directory). Upstream: https://github.com/tldr-pages/tldr/blob/main/CLIENT-SPECIFICATION.md

``adacovex tldr`` installs or refreshes the page. ``adacovex tldr --check``
exits 0 when the installed page matches the bundled one, and 1 when it
is missing or stale. The platform directories follow the tldr-pages
platform set: linux, osx, windows, android, sunos, freebsd, netbsd, and
openbsd, plus the cross-platform ``common``.

HLR-TLDR: Client-agnostic tldr page installation

> **Note:** All items in this package are public.

## Types

### type Client_Kind

```ada
type Client_Kind is (No_Client, Base_Client, Tealdeer, Unsupported_Client);
```

> A detected tldr client family. Base_Client is the family that follows CLIENT-SPECIFICATION.md (the C, Node, and Python clients). Tealdeer keeps custom pages outside its cache. Unsupported_Client means a `tldr` binary answered, but its family is not known.

## Functions

### function Classify (Version_Output : Standard.String) return Adacovex.Renderers.Tldr.Client_Kind

> Classify the output of `tldr --version`. The result is Tealdeer when the text names tealdeer, Base_Client when it names a tldr client, and Unsupported_Client otherwise.

| Parameter | Description |
|-----------|-------------|
| `Version_Output` | Captured stdout of `tldr --version`. |

**Returns:** The detected client family.

### function Client_Name (Kind : Adacovex.Renderers.Tldr.Client_Kind) return Standard.String

> A short display name for a client family.

| Parameter | Description |
|-----------|-------------|
| `Kind` | Client family. |

**Returns:** Display name (for example "tealdeer").

### function Custom_Pages_Dir (Show_Paths_Output : Standard.String) return Standard.String

> The custom pages directory in `tldr --show-paths` output. tealdeer prints one `Custom pages dir: <path>` line, with an optional trailing annotation such as " (OS convention)". A client that does not support the option prints no such line.

| Parameter | Description |
|-----------|-------------|
| `Show_Paths_Output` | Captured stdout of `tldr --show-paths`. |

**Returns:** The directory (no trailing slash, annotation removed), or "" when absent.

### function Default_Pages_Dir (Kind : Adacovex.Renderers.Tldr.Client_Kind; Home : Standard.String; Data_Home : Standard.String; Cache_Home : Standard.String) return Standard.String

> The default page directory for a client family. tealdeer reads Data_Home/tealdeer/pages. A base client reads Cache_Home/tldr/pages and falls back to the Node client's Home/.tldr cache when that tree is the one that exists.

| Parameter | Description |
|-----------|-------------|
| `Cache_Home` | Host cache base directory. |
| `Data_Home` | Host data base directory. |
| `Home` | User home directory. |
| `Kind` | Client family. |

**Returns:** Page directory, or "" for a family with no page directory.

### function Installed (Kind : Adacovex.Renderers.Tldr.Client_Kind; Pages_Dir : Standard.String) return Standard.Boolean

> Whether the installed page matches the bundled page. A missing page, an unreadable page, or a page with different content all report False.

| Parameter | Description |
|-----------|-------------|
| `Kind` | Client family. |
| `Pages_Dir` | Page directory (see Default_Pages_Dir). |

**Returns:** True when the primary page file equals Page.

### function Page return Standard.String

> The bundled tldr page text, byte for byte. The text comes from docs/tldr/adacovex.md through the generated Adacovex.Tldr_Template unit.

**Returns:** The page text.

### function Page_File (Kind : Adacovex.Renderers.Tldr.Client_Kind; Pages_Dir : Standard.String) return Standard.String

> The page file for a client under Pages_Dir. tealdeer uses Pages_Dir/adacovex.page.md. A base client uses Pages_Dir/common/adacovex.md.

| Parameter | Description |
|-----------|-------------|
| `Kind` | Client family. |
| `Pages_Dir` | Page directory (see Default_Pages_Dir). |

**Returns:** Page file path, or "" for a family with no page file.

### function Platform_From_System (System_Name : Standard.String) return Standard.String

> Map a `uname -s` system name to its tldr page directory. The accepted names cover the tldr-pages platform set: Linux, Darwin (osx), the BSDs, SunOS, Android, and the Windows shells.

| Parameter | Description |
|-----------|-------------|
| `System_Name` | Output of `uname -s` (for example "Linux"). |

**Returns:** Page directory name, or "" when the system is not known.

### function Platform_Page_Dir return Standard.String

> The platform page directory a base client also reads. The program runs `uname -s` and maps the system name to the tldr page directory. A Windows host without `uname` reports windows.

**Returns:** Directory name, or "" when the system is not known.

## Procedures

### procedure Detect (Kind : Adacovex.Renderers.Tldr.Client_Kind; Pages_Dir : Standard.String; Pages_Len : Standard.Natural) `[Pre]`

> Detect the local tldr client and its page directory. The program tries `tldr --show-paths` first, then classifies `tldr --version`. It never raises. Kind is No_Client when no tldr binary is on PATH.

| Parameter | Description |
|-----------|-------------|
| `Kind` | Detected client family. |
| `Pages_Dir` | Buffer that receives the page directory. |
| `Pages_Len` | Length of the page directory in Pages_Dir. |

### procedure Install (Kind : Adacovex.Renderers.Tldr.Client_Kind; Pages_Dir : Standard.String; Success : Standard.Boolean)

> Install (or refresh) the page for a client. A base client gets both the common page and the platform page, so the two never disagree. Every write creates the parent directory first. Never raises. Failures are reported through Success.

| Parameter | Description |
|-----------|-------------|
| `Kind` | Client family. |
| `Pages_Dir` | Page directory (see Default_Pages_Dir). |
| `Success` | True when every page file was written. |
