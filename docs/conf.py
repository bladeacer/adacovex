# Sphinx configuration for the adacovex manual.
#
# The manual source is the Markdown project at `docs/` (Read the Docs builds
# it -- see .readthedocs.yaml `sphinx.configuration: docs/conf.py`).  The
# same docs compile into the bundled offline manual that the --serve server
# exposes at /docs (tools/gen-docs.py runs this very sphinx-build and embeds
# the output).  The pages stay Markdown: the MyST parser reads `docs/*.md`
# unchanged, so no page is ever converted to reStructuredText.
#
# Only the Toolchain requires Python.  The adacovex binary itself has no
# Python or docs dependency; sphinx + myst-parser + furo are dev/toolchain
# dependencies (docs/../requirements.txt) used by `tools/gen-docs.py`, the
# `just book` / `book-links-check` targets, and Read the Docs.
#
# The Furo theme is used (https://github.com/pradyunsg/furo): a clean,
# modern Sphinx theme.  Furo pulls no web fonts and no images, so the
# offline manual builds and bundles with nothing beyond the three packages.

import os

# -- Project -----------------------------------------------------------------

project = "adacovex"
author = "bladeacer"
copyright = "bladeacer"
release = "latest"

# -- General -----------------------------------------------------------------

# The manual index lives at docs/index.md (the landing page).  `root_doc`
# names the master document that hosts the toctree.
root_doc = "index"
source_suffix = {".md": "markdown"}

# MyST turns the .md pages into Sphinx documents without reStructuredText.
extensions = ["myst_parser"]

# Every heading gets a stable "#slug" anchor at depth 3 (matching the
# maximum heading depth the pages use), so section links stay permanent.
myst_heading_anchors = 3

# Build products and generated (per-release) sub-trees are never sources.
# SUMMARY.md and book.toml are the retired mdBook TOC/config; they are kept
# as historical artifacts but must not build.
exclude_patterns = [
    "SUMMARY.md",
    "book.toml",
    "_build",
    "**/*.orig.md",
]

# The api-docs/, changelogs/, proof/, compliance/ and badges/ pages are
# reached through their section index pages (and search), not the top-level
# sidebar.  Sphinx warns for every page not named in a toctree; those are
# expected here, so the warning is silenced -- every such page still builds,
# is reachable via its index and the built-in search, and is bundled into
# the offline manual.
suppress_warnings = ["toc.not_included"]

# -- HTML output (Furo theme) ------------------------------------------------

# The Furo theme (https://github.com/pradyunsg/furo).  It is declared in
# requirements.txt alongside sphinx and myst-parser.
html_theme = "furo"

# Canonical URL for Read the Docs (no effect on the local/offline build).
html_baseurl = os.environ.get("READTHEDOCS_CANONICAL_URL", "/")

# The offline manual must build purely from source with no network: Furo
# pulls no fonts or images, so nothing else needs bundling.

# ---------------------------------------------------------------------------
# Match the Read the Docs link previews to the active theme
# ---------------------------------------------------------------------------
#
# Read the Docs injects its "link previews" hover popup into document.body and
# paints it with hard-coded light colours.  Furo's dark palette is defined on
# body[data-theme], which the popup inherits, so in dark mode the popup shows
# dark-theme text on a white box and the excerpt cannot be read.
#
# rtd-linkpreviews.css re-points the popup at Furo's own variables, so it
# follows the light/dark/auto toggle.  html_static_path is required because
# Sphinx resolves html_css_files against the output _static directory but only
# copies the files listed in html_static_path.  The same stylesheet ships in
# the bundled offline manual, where no addon runs, so it has no effect there.

html_static_path = ["_static"]
html_css_files = ["rtd-linkpreviews.css"]

# ---------------------------------------------------------------------------
# Sidebar drawer reveals the open entry
# ---------------------------------------------------------------------------
#
# The manual is a page per section, so the global toctree is far taller than
# the drawer. A reader who clicks a late entry lands on a page whose own
# entry sits below the drawer's fold, and the drawer stays where it was, so
# the sidebar click looks like it went nowhere. Furo reveals its right-hand
# table of contents only, so nothing else moves the drawer.
#
# sidebar-reveal.js scrolls the open entry into the drawer. The drawer
# (.sidebar-scroll) is the only element it moves: the page itself stays at its
# own top, the script never scrolls the window, and an entry already in view
# leaves the drawer where it is. The bundled offline manual shares the file
# (tools/gen-docs.py bundles every _static asset), so the online and offline
# manuals behave the same; on an offline page the sidebar is injected after
# this script has run, so the script finds no tree and the injector's own
# reveal owns that case.

html_js_files = ["sidebar-reveal.js"]

# ---------------------------------------------------------------------------
# Search
# ---------------------------------------------------------------------------
#
# Sphinx builds search into the HTML builder, so there is no extension to list
# and no extra dependency.  The sidebar search box is a deliberate part of the
# online manual, so html_search_language pins the stemmer to English instead
# of letting it follow `language`.  A future change to `language` therefore
# cannot quietly break the matching of English words.
#
# The search index is a static file that the build writes and the browser
# searches, so a search word never reaches a server.  The reader-facing
# statement is on the site transparency page (docs/site-transparency.md).

html_search_language = "en"

# ---------------------------------------------------------------------------
# No tracking script in the build
# ---------------------------------------------------------------------------
#
# This configuration adds no analytics tag, no tracker, and no consent banner
# to the generated HTML, and it must stay that way.  The only traffic
# measurement on the online manual is the hosting provider's own cookieless
# aggregate page-view counting, which the provider injects and the project
# cannot switch off.  The bundled offline manual that `--serve` exposes at
# /docs carries no analytics at all, because the same HTML is embedded in the
# binary.
#
# The reader-facing statement of all this lives in
# docs/site-transparency.md.  If you add a tag to this file, update that page
# in the same change, or the manual stops matching what it promises.

# ---------------------------------------------------------------------------
# Show the manual index in the sidebar
# ---------------------------------------------------------------------------
#
# Furo's global navigation tree comes from the root document's toctrees, so the
# root document itself (the manual index) is never listed -- only the brand link
# in the sidebar header points back to it.  Sphinx forbids a toctree referencing
# its own master document, so the canonical index entry is injected here with a
# tiny, contained html-page-context hook that prepends a clearly-labelled
# "Documentation index" link to the top of the navigation tree on every page.
# The entry reuses the caption/`toctree-l1` markup Sphinx emits, so it needs no
# custom CSS and matches the theme's indentation.  The hook runs after Furo
# computes furo_navigation_tree (priority 800 > Furo's 500) and works identically
# for the Read the Docs build and the bundled offline manual.


def _prepend_index_to_sidebar(
    app, pagename, templatename, context, doctree
):
    tree = context.get("furo_navigation_tree")
    if tree is None:
        return
    root = app.config.root_doc or "index"
    href = context["pathto"](root)
    index_entry = (
        '<p class="caption" role="heading">'
        '<span class="caption-text">adacovex Documentation</span></p>'
        "<ul><li class=\"toctree-l1\">"
        f'<a class="reference internal" href="{href}">'
        "Documentation index</a></li></ul>"
    )
    context["furo_navigation_tree"] = index_entry + tree


def setup(app):
    app.connect("html-page-context", _prepend_index_to_sidebar, 800)
