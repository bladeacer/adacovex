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
# `make book` / `book-links-check` targets, and Read the Docs.
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
